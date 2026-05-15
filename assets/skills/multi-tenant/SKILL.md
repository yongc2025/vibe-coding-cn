---
name: multi-tenant
description: 多租户架构设计与实现。覆盖数据隔离策略（共享数据库/独立Schema/独立数据库）、租户识别与上下文传播、中间件设计、数据迁移、安全隔离。适用于 SaaS 平台的多租户系统构建。支持 Java/Python/Go。
---

# Multi-Tenant Architecture Skill

## When to Use This Skill

- 设计或重构 SaaS 应用的多租户数据隔离方案
- 实现租户识别中间件（Header / Subdomain / JWT Claim）
- 租户上下文在请求链路中的传播（ThreadLocal / Context / Goroutine）
- 租户间数据迁移（Schema 升级、租户数据导出导入）
- 评估多租户架构模式选型（共享 DB vs 独立 Schema vs 独立 DB）
- 多租户环境下的性能优化与安全隔离

## Not For / Boundaries

- **不适用于**：单租户应用、纯静态站点、无数据库的服务
- **不负责**：用户认证本身（见 oauth-sso skill）、计费逻辑（见 billing-sub skill）
- **不覆盖**：Kubernetes 多集群隔离、物理网络隔离等基础设施层面的隔离
- **注意**：本 skill 侧重应用层多租户，不替代数据库管理员的运维操作

---

## Quick Reference

### 三种多租户数据隔离模式对比

| 模式 | 隔离级别 | 成本 | 复杂度 | 适用场景 |
|------|---------|------|--------|---------|
| 共享数据库 + 共享表 | 行级 (tenant_id) | 低 | 低 | 中小 SaaS，租户数多 |
| 独立 Schema | Schema 级 | 中 | 中 | 中型 SaaS，需逻辑隔离 |
| 独立数据库 | 数据库级 | 高 | 高 | 企业级，强合规要求 |

### 模式一：共享数据库 + tenant_id 列（最常用）

**核心思路**：所有租户数据在同一张表中，通过 `tenant_id` 列区分。

#### Python (SQLAlchemy + FastAPI)

```python
# models.py - 带租户过滤的基础模型
from sqlalchemy import Column, String, Integer, DateTime, event
from sqlalchemy.orm import Session, declarative_base
from datetime import datetime
import uuid

Base = declarative_base()

class TenantBaseMixin:
    """所有租户表的公共字段"""
    tenant_id = Column(String(36), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class User(TenantBaseMixin, Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    email = Column(String(255), nullable=False)
    name = Column(String(100))

# tenant_context.py - 租户上下文管理
from contextvars import ContextVar

_tenant_id: ContextVar[str] = ContextVar("tenant_id", default=None)

def set_tenant(tenant_id: str):
    _tenant_id.set(tenant_id)

def get_tenant() -> str:
    tid = _tenant_id.get()
    if tid is None:
        raise RuntimeError("Tenant context not set")
    return tid

# middleware.py - 租户识别中间件
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

class TenantMiddleware(BaseHTTPMiddleware):
    """
    租户识别策略（按优先级）：
    1. JWT claim 中的 tenant_id
    2. HTTP Header X-Tenant-ID
    3. 子域名解析
    """
    async def dispatch(self, request: Request, call_next):
        tenant_id = None

        # 策略1: JWT claim
        if hasattr(request.state, "user") and request.state.user:
            tenant_id = getattr(request.state.user, "tenant_id", None)

        # 策略2: Header
        if not tenant_id:
            tenant_id = request.headers.get("X-Tenant-ID")

        # 策略3: 子域名
        if not tenant_id:
            host = request.headers.get("host", "")
            parts = host.split(".")
            if len(parts) >= 3:
                tenant_id = parts[0]

        if not tenant_id:
            from starlette.responses import JSONResponse
            return JSONResponse({"error": "Missing tenant identifier"}, status_code=400)

        set_tenant(tenant_id)
        request.state.tenant_id = tenant_id
        response = await call_next(request)
        return response

# query_filter.py - 自动注入租户过滤
from sqlalchemy import event

def apply_tenant_filter(session: Session):
    """为查询自动添加 tenant_id 过滤"""
    @event.listens_for(Session, "do_orm_execute")
    def _inject_tenant(execute_state):
        if execute_state.is_select:
            for desc in execute_state.statement.column_descriptions:
                if desc.get("entity") and hasattr(desc["entity"], "tenant_id"):
                    entity = desc["entity"]
                    stmt = execute_state.statement.where(
                        entity.tenant_id == get_tenant()
                    )
                    execute_state.statement = stmt

# usage_example.py
from fastapi import FastAPI, Depends
app = FastAPI()
app.add_middleware(TenantMiddleware)

@app.get("/users")
async def list_users(db: Session = Depends(get_db)):
    # 自动过滤当前租户数据，无需手动加 where 条件
    users = db.query(User).all()
    return [{"id": u.id, "email": u.email} for u in users]

@app.post("/users")
async def create_user(data: dict, db: Session = Depends(get_db)):
    user = User(
        tenant_id=get_tenant(),  # 自动注入当前租户
        email=data["email"],
        name=data["name"]
    )
    db.add(user)
    db.commit()
    return {"id": user.id}
```

#### Go (Gin + GORM)

```go
// context.go - 租户上下文
package tenant

import (
    "context"
    "fmt"
)

type tenantKey struct{}

func WithTenantID(ctx context.Context, tenantID string) context.Context {
    return context.WithValue(ctx, tenantKey{}, tenantID)
}

func GetTenantID(ctx context.Context) string {
    if v, ok := ctx.Value(tenantKey{}).(string); ok {
        return v
    }
    panic("tenant context not set")
}

// middleware.go - 租户识别中间件
package tenant

import (
    "net/http"
    "strings"
    "github.com/gin-gonic/gin"
)

func Middleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        var tenantID string

        // 策略1: Header
        tenantID = c.GetHeader("X-Tenant-ID")

        // 策略2: 子域名
        if tenantID == "" {
            host := c.Request.Host
            parts := strings.Split(host, ".")
            if len(parts) >= 3 {
                tenantID = parts[0]
            }
        }

        if tenantID == "" {
            c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": "Missing tenant identifier"})
            return
        }

        ctx := WithTenantID(c.Request.Context(), tenantID)
        c.Request = c.Request.WithContext(ctx)
        c.Set("tenant_id", tenantID)
        c.Next()
    }
}

// gorm_plugin.go - GORM 租户自动过滤插件
package tenant

import (
    "gorm.io/gorm"
    "gorm.io/gorm/clause"
)

type TenantPlugin struct{}

func (p *TenantPlugin) Name() string { return "tenant_plugin" }

func (p *TenantPlugin) Initialize(db *gorm.DB) error {
    // 查询时自动注入 WHERE tenant_id = ?
    db.Callback().Query().Before("gorm:query").Register("tenant:before_query", func(db *gorm.DB) {
        if db.Statement.Schema != nil {
            if field := db.Statement.Schema.LookUpField("TenantID"); field != nil {
                tenantID := GetTenantID(db.Statement.Context)
                db.Statement.AddClause(clause.Where{
                    Exprs: []clause.Expression{
                        clause.Eq{Column: clause.Column{Name: "tenant_id"}, Value: tenantID},
                    },
                })
            }
        }
    })

    // 创建时自动设置 tenant_id
    db.Callback().Create().Before("gorm:create").Register("tenant:before_create", func(db *gorm.DB) {
        if db.Statement.Schema != nil {
            if field := db.Statement.Schema.LookUpField("TenantID"); field != nil {
                tenantID := GetTenantID(db.Statement.Context)
                _ = db.Statement.SetColumn("TenantID", tenantID)
            }
        }
    })

    return nil
}

// models.go
package models

import "time"

type BaseModel struct {
    ID        uint      `gorm:"primaryKey" json:"id"`
    TenantID  string    `gorm:"index;not null" json:"tenant_id"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type User struct {
    BaseModel
    Email string `gorm:"uniqueIndex:idx_tenant_email;size:255" json:"email"`
    Name  string `gorm:"size:100" json:"name"`
}
```

#### Java (Spring Boot)

```java
// TenantContext.java - 线程级租户上下文
public class TenantContext {
    private static final ThreadLocal<String> CURRENT_TENANT = new ThreadLocal<>();

    public static void setTenant(String tenantId) {
        CURRENT_TENANT.set(tenantId);
    }

    public static String getTenant() {
        String tenantId = CURRENT_TENANT.get();
        if (tenantId == null) {
            throw new IllegalStateException("Tenant context not set");
        }
        return tenantId;
    }

    public static void clear() {
        CURRENT_TENANT.remove();
    }
}

// TenantFilter.java - Servlet Filter
@Component
@Order(1)
public class TenantFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain chain) throws ServletException, IOException {
        String tenantId = resolveTenantId(request);
        if (tenantId == null) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            response.getWriter().write("{\"error\":\"Missing tenant identifier\"}");
            return;
        }
        TenantContext.setTenant(tenantId);
        try {
            chain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }

    private String resolveTenantId(HttpServletRequest request) {
        // 1. JWT claim
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth instanceof JwtAuthenticationToken jwt) {
            Object tid = jwt.getToken().getClaim("tenant_id");
            if (tid != null) return tid.toString();
        }
        // 2. Header
        String header = request.getHeader("X-Tenant-ID");
        if (header != null) return header;
        // 3. 子域名
        String host = request.getServerName();
        String[] parts = host.split("\\.");
        return parts.length >= 3 ? parts[0] : null;
    }
}

// Hibernate TenantInterceptor.java - Hibernate 自动注入
@Component
public class TenantInterceptor extends EmptyInterceptor {
    @Override
    public boolean onSave(Object entity, Object id, Object[] state,
                          String[] propertyNames, Type[] types) {
        for (int i = 0; i < propertyNames.length; i++) {
            if ("tenantId".equals(propertyNames[i]) && state[i] == null) {
                state[i] = TenantContext.getTenant();
            }
        }
        return true;
    }

    @Override
    public String onPrepareStatement(String sql) {
        // 自动在 SELECT 中注入 WHERE tenant_id = ?
        if (sql.contains("users") && !sql.contains("tenant_id")) {
            String tenantId = TenantContext.getTenant();
            sql = sql.replace(" where ", " where tenant_id='" + tenantId + "' and ");
            if (!sql.contains(" where ")) {
                sql = sql + " where tenant_id='" + tenantId + "'";
            }
        }
        return sql;
    }
}
```

### 模式二：独立 Schema（PostgreSQL）

```sql
-- 每个租户一个 schema，共享同一个数据库连接池
-- 基础结构
CREATE SCHEMA tenant_acme;
CREATE SCHEMA tenant_globex;

-- 租户表结构（在每个 schema 中相同）
CREATE TABLE tenant_acme.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(100)
);

-- 查询当前 schema
SELECT current_schema();

-- 切换 schema（PostgreSQL）
SET search_path TO tenant_acme;
```

```python
# schema_manager.py - Schema 级隔离管理器
from sqlalchemy import text
from contextvars import ContextVar

_current_schema: ContextVar[str] = ContextVar("current_schema")

class SchemaManager:
    def __init__(self, engine):
        self.engine = engine

    def create_tenant_schema(self, tenant_id: str):
        """为新租户创建 schema 并初始化表结构"""
        schema_name = f"tenant_{tenant_id}"
        with self.engine.connect() as conn:
            conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema_name}"))
            # 复制公共模板表结构到新 schema
            conn.execute(text(f"""
                CREATE TABLE {schema_name}.users (LIKE public.users_template INCLUDING ALL)
            """))
            conn.commit()

    def set_schema(self, connection, schema_name: str):
        """在连接级别切换 schema"""
        connection.execute(text(f"SET search_path TO {schema_name}, public"))

    def drop_tenant_schema(self, tenant_id: str):
        """删除租户 schema（慎用！）"""
        schema_name = f"tenant_{tenant_id}"
        with self.engine.connect() as conn:
            conn.execute(text(f"DROP SCHEMA IF EXISTS {schema_name} CASCADE"))
            conn.commit()

    def list_schemas(self) -> list[str]:
        """列出所有租户 schema"""
        with self.engine.connect() as conn:
            result = conn.execute(text(
                "SELECT schema_name FROM information_schema.schemata "
                "WHERE schema_name LIKE 'tenant_%'"
            ))
            return [row[0] for row in result]
```

### 模式三：独立数据库

```python
# db_router.py - 多数据库路由
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import json

class TenantDatabaseRouter:
    """每个租户一个独立数据库"""

    def __init__(self, config_path: str):
        with open(config_path) as f:
            self.config = json.load(f)
        self._engines = {}

    def get_engine(self, tenant_id: str):
        if tenant_id not in self._engines:
            db_config = self.config["tenants"].get(tenant_id)
            if not db_config:
                raise ValueError(f"Unknown tenant: {tenant_id}")
            url = (
                f"postgresql://{db_config['user']}:{db_config['password']}"
                f"@{db_config['host']}:{db_config['port']}/{db_config['database']}"
            )
            self._engines[tenant_id] = create_engine(url, pool_size=5, max_overflow=10)
        return self._engines[tenant_id]

    def get_session(self, tenant_id: str):
        engine = self.get_engine(tenant_id)
        Session = sessionmaker(bind=engine)
        return Session()

# config.json 示例:
# {
#   "tenants": {
#     "acme": {"host": "db-acme.example.com", "port": 5432, "user": "app", "password": "xxx", "database": "acme_prod"},
#     "globex": {"host": "db-globex.example.com", "port": 5432, "user": "app", "password": "xxx", "database": "globex_prod"}
#   }
# }
```

---

## Common Patterns

### 1. 租户上下文传播模式

请求进入时设置租户上下文，整条链路自动携带，请求结束时清理。

```
HTTP Request
  → TenantMiddleware (识别租户)
    → ContextVar/ThreadLocal (设置上下文)
      → Service Layer (读取上下文)
        → Repository Layer (自动过滤 tenant_id)
          → Database (执行带租户条件的 SQL)
```

**关键原则**：
- **请求边界设置**：在中间件/Filter 层一次性设置
- **自动清理**：在 finally 块中清除，防止内存泄漏
- **异步传播**：Python 用 `ContextVar`（自动协程传播），Go 用 `context.Context`，Java 用 `ThreadLocal` + `InheritableThreadLocal`

### 2. 租户数据迁移模式

```python
# migration_runner.py - 逐租户执行 Schema 迁移
class TenantMigrationRunner:
    def __init__(self, router: TenantDatabaseRouter):
        self.router = router

    def migrate_all(self, migration_func, batch_size: int = 10):
        """分批迁移所有租户"""
        tenants = self.router.list_tenants()
        for i in range(0, len(tenants), batch_size):
            batch = tenants[i:i + batch_size]
            for tenant_id in batch:
                try:
                    session = self.router.get_session(tenant_id)
                    migration_func(session)
                    session.commit()
                    print(f"[OK] {tenant_id}")
                except Exception as e:
                    print(f"[FAIL] {tenant_id}: {e}")
                    # 记录失败但继续，不要一个租户失败导致全部中断
```

### 3. 租户限流与资源配额

```python
# rate_limiter.py
import redis
import time

class TenantRateLimiter:
    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client

    def check_rate_limit(self, tenant_id: str, limit: int = 100, window: int = 60) -> bool:
        """滑动窗口限流，基于租户"""
        key = f"ratelimit:{tenant_id}:{int(time.time() // window)}"
        current = self.redis.incr(key)
        if current == 1:
            self.redis.expire(key, window)
        return current <= limit

# middleware 中使用
async def check_tenant_quota(request: Request):
    tenant_id = get_tenant()
    plan = get_tenant_plan(tenant_id)  # 从租户配置获取套餐
    limiter = TenantRateLimiter(redis_client)
    if not limiter.check_rate_limit(tenant_id, limit=plan.api_limit):
        return JSONResponse({"error": "Rate limit exceeded"}, status_code=429)
```

### 4. 租户配置管理

```python
# tenant_config.py - 每个租户的独立配置
from dataclasses import dataclass, field
from typing import Dict, Any

@dataclass
class TenantConfig:
    tenant_id: str
    display_name: str
    plan: str = "free"                       # free / pro / enterprise
    max_users: int = 10
    max_storage_gb: int = 5
    features: list[str] = field(default_factory=list)
    custom_domain: str | None = None
    sso_enabled: bool = False
    metadata: Dict[str, Any] = field(default_factory=dict)

class TenantConfigStore:
    """租户配置存储（可从 DB / Redis / 配置文件加载）"""
    def __init__(self):
        self._configs: Dict[str, TenantConfig] = {}

    def load_from_db(self, db_session):
        rows = db_session.execute("SELECT * FROM tenant_configs").fetchall()
        for row in rows:
            self._configs[row["tenant_id"]] = TenantConfig(**row)

    def get(self, tenant_id: str) -> TenantConfig:
        if tenant_id not in self._configs:
            raise ValueError(f"Tenant {tenant_id} not found")
        return self._configs[tenant_id]

    def has_feature(self, tenant_id: str, feature: str) -> bool:
        config = self.get(tenant_id)
        return feature in config.features
```

### 5. 租户安全隔离清单

```
✅ 数据层隔离
  - 所有查询自动注入 tenant_id 条件
  - 写入时自动设置 tenant_id
  - 唯一约束包含 tenant_id（如 tenant_id + email）

✅ 应用层隔离
  - 中间件强制识别租户
  - 上下文传播不可绕过
  - 跨租户 API 调用需要显式授权

✅ 缓存隔离
  - Redis key 前缀包含 tenant_id（如 "tenant:acme:user:123"）
  - 缓存过期策略按租户套餐差异化

✅ 日志隔离
  - 所有日志包含 tenant_id 字段
  - 日志查询支持按租户过滤

✅ 文件存储隔离
  - S3/GCS 路径按租户分桶或前缀
  - 上传/下载 URL 签名时绑定租户
```

---

## References

- [PostgreSQL Row-Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) — 数据库原生 RLS 策略
- [AWS SaaS Tenant Isolation Strategies](https://docs.aws.amazon.com/wellarchitected/latest/saas-lens/tenant-isolation.html) — AWS 多租户隔离白皮书
- [Microsoft Multi-tenant SaaS](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview) — Azure 多租户架构指南
- [Hibernate Multi-tenancy](https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#multitenacy) — Hibernate 官方多租户支持
- [GORM Multi-tenancy](https://gorm.io/docs/many_to_many.html) — GORM 插件式多租户
- [SQLAlchemy Events](https://docs.sqlalchemy.org/20/orm/events.html) — SQLAlchemy ORM 事件钩子
