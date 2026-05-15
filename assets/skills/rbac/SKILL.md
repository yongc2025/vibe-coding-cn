---
name: rbac
description: "RBAC/ABAC 权限管理系统设计与实现。覆盖 RBAC、ABAC、Spring Security、Casbin、JWT、OAuth2，支持 Java/Python。适用于企业级权限模型设计、API 鉴权、数据权限控制。"
---

# RBAC/ABAC 权限管理

## When to Use This Skill

- 设计或实现用户-角色-权限模型（RBAC0/RBAC1/RBAC2/RBAC3）
- 需要基于属性的动态权限控制（ABAC）
- 集成 Spring Security / Casbin 等权限框架
- JWT Token 签发、校验、刷新
- OAuth2 / OIDC 第三方登录集成
- 数据权限（行级、列级）控制
- API 接口鉴权与授权

## Not For / Boundaries

- ❌ 不适用于简单的硬编码权限判断
- ❌ 不处理业务逻辑层的数据校验（如参数校验）
- ❌ 不涉及网络层安全（WAF、DDoS 防护）
- ❌ 不替代加密/哈希等密码学操作
- ❌ ABAC 策略引擎不适合极高性能要求的实时路径（<1ms）

---

## Quick Reference

### 1. RBAC 权限模型设计（数据库 Schema）

```sql
-- 用户表
CREATE TABLE sys_user (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    username    VARCHAR(64) NOT NULL UNIQUE,
    password    VARCHAR(256) NOT NULL,
    status      TINYINT DEFAULT 1 COMMENT '1-启用 0-禁用',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 角色表
CREATE TABLE sys_role (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_key    VARCHAR(64) NOT NULL UNIQUE COMMENT '角色标识',
    role_name   VARCHAR(128) NOT NULL,
    status      TINYINT DEFAULT 1,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 权限表
CREATE TABLE sys_permission (
    id              BIGINT PRIMARY KEY AUTO_INCREMENT,
    perm_key        VARCHAR(128) NOT NULL UNIQUE COMMENT '权限标识如 user:read',
    perm_name       VARCHAR(256) NOT NULL,
    resource_type   VARCHAR(32) DEFAULT 'api' COMMENT 'api/menu/button/data',
    parent_id       BIGINT DEFAULT 0,
    sort_order      INT DEFAULT 0
);

-- 用户-角色关联
CREATE TABLE sys_user_role (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id)
);

-- 角色-权限关联
CREATE TABLE sys_role_permission (
    role_id BIGINT NOT NULL,
    perm_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, perm_id)
);

-- 数据权限规则（行级）
CREATE TABLE sys_data_scope (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_id     BIGINT NOT NULL,
    table_name  VARCHAR(64) NOT NULL,
    scope_type  VARCHAR(32) NOT NULL COMMENT 'all/dept/dept_and_child/custom',
    scope_value VARCHAR(512) COMMENT '自定义SQL片段或部门ID列表'
);
```

### 2. Spring Security + JWT 鉴权（Java）

```java
// JWT 工具类
@Component
public class JwtTokenProvider {
    @Value("${jwt.secret}")
    private String secret;
    @Value("${jwt.expiration:7200}")
    private long expiration;

    public String generateToken(UserDetails userDetails) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("roles", userDetails.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority).collect(Collectors.toList()));
        return Jwts.builder()
            .setClaims(claims)
            .setSubject(userDetails.getUsername())
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + expiration * 1000))
            .signWith(SignatureAlgorithm.HS256, secret)
            .compact();
    }

    public String getUsernameFromToken(String token) {
        return Jwts.parser().setSigningKey(secret)
            .parseClaimsJws(token).getBody().getSubject();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser().setSigningKey(secret).parseClaimsJws(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }
}

// JWT 认证过滤器
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    @Autowired
    private JwtTokenProvider tokenProvider;
    @Autowired
    private UserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        String token = resolveToken(req);
        if (token != null && tokenProvider.validateToken(token)) {
            String username = tokenProvider.getUsernameFromToken(token);
            UserDetails userDetails = userDetailsService.loadUserByUsername(username);
            UsernamePasswordAuthenticationToken auth =
                new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
            auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(req));
            SecurityContextHolder.getContext().setAuthentication(auth);
        }
        chain.doFilter(req, res);
    }

    private String resolveToken(HttpServletRequest req) {
        String bearer = req.getHeader("Authorization");
        if (bearer != null && bearer.startsWith("Bearer ")) {
            return bearer.substring(7);
        }
        return null;
    }
}

// Security 配置
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {
    @Autowired
    private JwtAuthenticationFilter jwtFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}

// 方法级权限控制
@Service
public class UserService {
    @PreAuthorize("hasAuthority('user:read')")
    public UserDTO getUser(Long id) { /* ... */ }

    @PreAuthorize("hasAuthority('user:write')")
    public void createUser(CreateUserRequest req) { /* ... */ }

    @PreAuthorize("hasRole('ADMIN') and hasAuthority('user:delete')")
    public void deleteUser(Long id) { /* ... */ }
}
```

### 3. Casbin 权限控制（Python）

```python
# pip install casbin casbin-sqlalchemy-adapter

import casbin
from casbin_sqlalchemy_adapter import Adapter
from sqlalchemy import create_engine

# 初始化 Casbin（RBAC 模型）
adapter = Adapter("sqlite:///casbin.db")
e = casbin.Enforcer("rbac_model.conf", adapter)

# --- 模型定义 (rbac_model.conf) ---
# [request_definition]
# r = sub, obj, act
#
# [policy_definition]
# p = sub, obj, act
#
# [role_definition]
# g = _, _
#
# [policy_effect]
# e = some(where (p.eft == allow))
#
# [matchers]
# m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act

# 添加策略
e.add_policy("admin", "user", "read")
e.add_policy("admin", "user", "write")
e.add_policy("admin", "user", "delete")
e.add_policy("editor", "article", "read")
e.add_policy("editor", "article", "write")

# 添加角色继承
e.add_grouping_policy("alice", "admin")
e.add_grouping_policy("bob", "editor")

# 权限检查
print(e.enforce("alice", "user", "read"))    # True
print(e.enforce("bob", "user", "delete"))     # False
print(e.enforce("bob", "article", "write"))   # True

# --- FastAPI 集成示例 ---
from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import HTTPBearer

app = FastAPI()
security = HTTPBearer()

def check_permission(user: str, resource: str, action: str):
    if not e.enforce(user, resource, action):
        raise HTTPException(status_code=403, detail="Permission denied")

@app.get("/api/users")
def list_users(token = Depends(security)):
    user = decode_token(token.credentials)  # 自定义token解析
    check_permission(user, "user", "read")
    return {"users": get_users()}
```

### 4. ABAC 属性权限控制（Java）

```java
// ABAC 策略评估器
public class AbacEvaluator {

    public boolean evaluate(Subject subject, Resource resource, Action action, Environment env) {
        // 读取策略规则（可从配置中心/数据库加载）
        List<Policy> policies = loadPolicies(resource.getType());

        for (Policy policy : policies) {
            if (matchConditions(policy, subject, resource, action, env)) {
                return policy.getEffect() == PolicyEffect.ALLOW;
            }
        }
        return false; // 默认拒绝
    }

    private boolean matchConditions(Policy policy, Subject subject,
                                     Resource resource, Action action, Environment env) {
        return policy.getConditions().stream().allMatch(condition -> {
            Object attrValue = resolveAttribute(condition.getAttribute(),
                                                 subject, resource, action, env);
            return condition.getOperator().evaluate(attrValue, condition.getValue());
        });
    }

    private Object resolveAttribute(String attr, Subject s, Resource r,
                                     Action a, Environment e) {
        return switch (attr.split("\\.")[0]) {
            case "subject" -> s.getAttribute(attr.substring(8));
            case "resource" -> r.getAttribute(attr.substring(9));
            case "action" -> a.getType();
            case "environment" -> e.getAttribute(attr.substring(12));
            default -> null;
        };
    }
}

// 使用示例
// 策略：工作日 9:00-18:00，部门为财务的用户可以访问财务报表
AbacEvaluator evaluator = new AbacEvaluator();
boolean allowed = evaluator.evaluate(
    new Subject("user1", Map.of("department", "finance", "level", 3)),
    new Resource("report", "financial_report", Map.of("owner_dept", "finance")),
    Action.READ,
    new Environment(Map.of("time", LocalTime.now(), "ip", "192.168.1.100"))
);
```

### 5. 数据权限（行级过滤）

```java
// MyBatis 拦截器实现数据权限
@Intercepts({
    @Signature(type = StatementHandler.class, method = "prepare", args = {Connection.class, Integer.class})
})
public class DataPermissionInterceptor implements Interceptor {
    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        StatementHandler handler = (StatementHandler) invocation.getTarget();
        MetaObject metaObject = SystemMetaObject.forObject(handler);

        MappedStatement ms = (MappedStatement) metaObject.getValue("delegate.mappedStatement");
        // 检查是否有数据权限注解
        DataScope scope = getDataScopeAnnotation(ms);
        if (scope == null) return invocation.proceed();

        // 获取当前用户的数据权限范围
        LoginUser user = SecurityUtils.getLoginUser();
        String originalSql = (String) metaObject.getValue("delegate.boundSql.sql");
        String scopeSql = buildScopeSql(originalSql, scope, user);
        metaObject.setValue("delegate.boundSql.sql", scopeSql);

        return invocation.proceed();
    }

    private String buildScopeSql(String sql, DataScope scope, LoginUser user) {
        if (user.isAdmin()) return sql; // 管理员不过滤

        String alias = scope.alias();
        String scopeColumn = scope.column();
        return switch (user.getDataScopeType()) {
            case "all" -> sql;
            case "dept" -> String.format(
                "SELECT _dsp.* FROM (%s) _dsp WHERE _dsp.%s IN (SELECT id FROM sys_dept WHERE id = %d)",
                sql, scopeColumn, user.getDeptId());
            case "self" -> String.format(
                "SELECT _dsp.* FROM (%s) _dsp WHERE _dsp.%s = %d",
                sql, scopeColumn, user.getUserId());
            default -> sql + " AND 1=0"; // 无权限返回空
        };
    }
}

// 使用注解
@Mapper
public interface OrderMapper {
    @DataScope(alias = "o", column = "dept_id")
    @Select("SELECT * FROM orders o WHERE o.status = #{status}")
    List<Order> selectOrders(@Param("status") Integer status);
}
```

### 6. OAuth2 授权码模式集成

```java
// Spring Authorization Server 配置
@Configuration
public class AuthServerConfig {

    @Bean
    public RegisteredClientRepository registeredClientRepository() {
        RegisteredClient webClient = RegisteredClient.withId(UUID.randomUUID().toString())
            .clientId("web-app")
            .clientSecret("{bcrypt}$2a$10$...")
            .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
            .authorizationGrantType(AuthorizationGrantType.REFRESH_TOKEN)
            .redirectUri("http://localhost:3000/callback")
            .scope(OidcScopes.OPENID)
            .scope("read")
            .scope("write")
            .tokenSettings(TokenSettings.builder()
                .accessTokenTimeToLive(Duration.ofHours(2))
                .refreshTokenTimeToLive(Duration.ofDays(7))
                .build())
            .build();
        return new InMemoryRegisteredClientRepository(webClient);
    }

    @Bean
    public SecurityFilterChain authServerSecurityFilterChain(HttpSecurity http) throws Exception {
        OAuth2AuthorizationServerConfiguration.applyDefaultSecurity(http);
        return http.build();
    }
}
```

---

## Common Patterns

### 模式 1：RBAC 分级模型

| 级别 | 说明 | 典型场景 |
|------|------|----------|
| RBAC0 | 用户-角色-权限 基础映射 | 小型系统 |
| RBAC1 | 角色继承（上级角色包含下级权限） | 企业组织架构 |
| RBAC2 | 互斥角色、角色数量限制 | 金融合规系统 |
| RBAC3 | RBAC1 + RBAC2 | 大型企业级系统 |

### 模式 2：权限标识命名规范

```
{模块}:{资源}:{操作}

示例：
  user:profile:read      # 读取用户资料
  order:*:write          # 写入所有订单资源
  report:financial:export # 导出财务报表
  system:config:update    # 更新系统配置
```

### 模式 3：JWT Token 设计

```
Access Token  → 短期（15min-2h），携带权限信息，用于 API 鉴权
Refresh Token → 长期（7-30天），仅用于刷新 Access Token
ID Token      → OIDC 场景，携带用户身份信息
```

### 模式 4：权限缓存策略

```
权限变更 → 清除 Redis 缓存 → 发布 MQ 事件 → 各服务刷新本地缓存

Redis Key 设计：
  perm:user:{userId}  → 用户权限集合（Set）
  perm:role:{roleId}  → 角色权限集合（Set）
  TTL: 30min（兜底过期）
```

### 模式 5：多租户权限隔离

```java
// 租户上下文 + 权限联合过滤
@Component
public class TenantPermissionFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest req, ...) {
        String tenantId = resolveTenant(req); // 从 header/domain/token 解析
        TenantContext.set(tenantId);
        try {
            // 权限查询自动加租户条件
            chain.doFilter(req, res);
        } finally {
            TenantContext.clear();
        }
    }
}
```

---

## References

- [Spring Security 官方文档](https://docs.spring.io/spring-security/reference/)
- [Spring Authorization Server](https://docs.spring.io/spring-authorization-server/reference/)
- [Casbin 官方文档](https://casbin.org/docs/overview)
- [Casbin GitHub](https://github.com/casbin/casbin)
- [RBAC 论文 - NIST](https://csrc.nist.gov/publications/detail/conference-paper/2000/04/12/role-based-access-controls)
- [JWT RFC 7519](https://tools.ietf.org/html/rfc7519)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
