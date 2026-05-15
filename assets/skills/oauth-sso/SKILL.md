---
name: oauth-sso
description: OAuth2.0/OpenID Connect/SAML/JWT 认证与单点登录(SSO)实现。覆盖授权码流程、PKCE、Token 管理、社交登录集成（微信/Google/GitHub）、单点登录、安全最佳实践。支持 Java/Python/Node.js。
---

# OAuth2 / SSO / JWT Authentication Skill

## When to Use This Skill

- 实现 OAuth2.0 授权服务器或资源服务器
- 集成社交登录（微信、Google、GitHub、Apple 等）
- 设计 JWT Token 签发、刷新、撤销机制
- 实现企业级 SSO（SAML 2.0 / OIDC）
- 构建多应用单点登录体系
- API 认证与授权（Bearer Token、API Key）

## Not For / Boundaries

- **不适用于**：无状态的纯 API Key 认证（简单场景不需要 OAuth）
- **不负责**：用户注册流程 UI、密码找回逻辑的具体实现
- **不覆盖**：硬件安全模块 (HSM)、密钥管理系统 (KMS) 的运维
- **注意**：认证涉及安全核心，代码上线前必须进行安全审计

---

## Quick Reference

### OAuth2.0 四种授权模式

| 模式 | 适用场景 | 安全性 |
|------|---------|--------|
| Authorization Code + PKCE | Web/SPA/Mobile（推荐） | 最高 |
| Client Credentials | 服务间通信 (M2M) | 高 |
| Device Code | IoT、智能电视 | 中 |
| ~~Implicit~~ | ~~SPA~~（已废弃） | ~~低~~ |

### 1. Authorization Code + PKCE 流程（Python FastAPI）

```python
# oauth_server.py - 轻量级 OAuth2 授权服务器
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from jose import jwt, JWTError
from datetime import datetime, timedelta
import hashlib
import secrets
import base64
import urllib.parse

app = FastAPI()

# 配置
SECRET_KEY = "your-secret-key-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

# 内存存储（生产环境用 Redis/DB）
authorization_codes = {}  # code -> {client_id, user_id, redirect_uri, code_challenge, expires_at}
refresh_tokens = {}       # token -> {user_id, client_id, scopes, expires_at}

# ==================== Token 管理 ====================

def create_access_token(data: dict, expires_delta: timedelta = None) -> str:
    """创建 JWT Access Token"""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({
        "exp": expire,
        "iat": datetime.utcnow(),
        "jti": secrets.token_hex(16),  # 唯一标识，用于撤销
    })
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(user_id: str, client_id: str, scopes: list) -> str:
    """创建 Refresh Token"""
    token = secrets.token_urlsafe(64)
    refresh_tokens[token] = {
        "user_id": user_id,
        "client_id": client_id,
        "scopes": scopes,
        "expires_at": datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
    }
    return token

def verify_token(token: str) -> dict:
    """验证并解码 JWT"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

# ==================== PKCE 工具 ====================

def verify_pkce(code_verifier: str, code_challenge: str, method: str = "S256") -> bool:
    """验证 PKCE code_verifier"""
    if method == "S256":
        digest = hashlib.sha256(code_verifier.encode("ascii")).digest()
        challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
        return challenge == code_challenge
    elif method == "plain":
        return code_verifier == code_challenge
    return False

# ==================== 授权端点 ====================

@app.get("/oauth/authorize")
async def authorize(
    request: Request,
    response_type: str,
    client_id: str,
    redirect_uri: str,
    scope: str = "openid profile email",
    state: str = "",
    code_challenge: str = None,
    code_challenge_method: str = "S256",
):
    """授权端点 - 用户登录后重定向回客户端"""
    # 验证 client_id 和 redirect_uri（简化实现）
    if not validate_client(client_id, redirect_uri):
        raise HTTPException(status_code=400, detail="Invalid client_id or redirect_uri")

    # 实际应用中这里会显示登录页面，用户确认授权
    # 简化：假设用户已授权
    user_id = get_current_user(request)  # 从 session 获取

    # 生成授权码
    code = secrets.token_urlsafe(32)
    authorization_codes[code] = {
        "client_id": client_id,
        "user_id": user_id,
        "redirect_uri": redirect_uri,
        "scope": scope,
        "code_challenge": code_challenge,
        "code_challenge_method": code_challenge_method,
        "expires_at": datetime.utcnow() + timedelta(minutes=10),
    }

    # 重定向回客户端
    params = {"code": code, "state": state}
    redirect_url = f"{redirect_uri}?{urllib.parse.urlencode(params)}"
    return RedirectResponse(url=redirect_url)

@app.post("/oauth/token")
async def token(request: Request):
    """Token 端点 - 用授权码换取 Token"""
    body = await request.json()
    grant_type = body.get("grant_type")

    if grant_type == "authorization_code":
        return await handle_authorization_code_grant(body)
    elif grant_type == "refresh_token":
        return await handle_refresh_token_grant(body)
    else:
        raise HTTPException(status_code=400, detail="Unsupported grant_type")

async def handle_authorization_code_grant(body: dict) -> dict:
    """授权码模式换取 Token"""
    code = body.get("code")
    code_verifier = body.get("code_verifier")

    # 验证授权码
    code_data = authorization_codes.pop(code, None)
    if not code_data:
        raise HTTPException(status_code=400, detail="Invalid or expired authorization code")
    if code_data["expires_at"] < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Authorization code expired")

    # 验证 PKCE
    if code_data["code_challenge"]:
        if not code_verifier:
            raise HTTPException(status_code=400, detail="code_verifier required")
        if not verify_pkce(code_verifier, code_data["code_challenge"], code_data["code_challenge_method"]):
            raise HTTPException(status_code=400, detail="PKCE verification failed")

    # 验证 redirect_uri
    if body.get("redirect_uri") != code_data["redirect_uri"]:
        raise HTTPException(status_code=400, detail="redirect_uri mismatch")

    # 签发 Token
    scopes = code_data["scope"].split()
    access_token = create_access_token({
        "sub": code_data["user_id"],
        "client_id": code_data["client_id"],
        "scope": code_data["scope"],
        "tenant_id": get_user_tenant(code_data["user_id"]),
    })
    refresh_token = create_refresh_token(code_data["user_id"], code_data["client_id"], scopes)

    return {
        "access_token": access_token,
        "token_type": "Bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "refresh_token": refresh_token,
        "scope": code_data["scope"],
    }

async def handle_refresh_token_grant(body: dict) -> dict:
    """Refresh Token 换取新 Access Token"""
    token = body.get("refresh_token")
    token_data = refresh_tokens.get(token)

    if not token_data or token_data["expires_at"] < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invalid or expired refresh token")

    # 轮换 refresh token（安全最佳实践）
    refresh_tokens.pop(token)
    new_refresh = create_refresh_token(
        token_data["user_id"], token_data["client_id"], token_data["scopes"]
    )

    access_token = create_access_token({
        "sub": token_data["user_id"],
        "client_id": token_data["client_id"],
        "scope": " ".join(token_data["scopes"]),
    })

    return {
        "access_token": access_token,
        "token_type": "Bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "refresh_token": new_refresh,
    }

# ==================== 资源保护 ====================

from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def get_current_user_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """从 Bearer Token 中提取用户信息"""
    payload = verify_token(credentials.credentials)
    return {
        "user_id": payload["sub"],
        "client_id": payload.get("client_id"),
        "scopes": payload.get("scope", "").split(),
        "tenant_id": payload.get("tenant_id"),
    }

@app.get("/api/me")
async def get_me(user=Depends(get_current_user_token)):
    """受保护的资源端点"""
    return {"user_id": user["user_id"], "scopes": user["scopes"]}

def require_scope(required_scope: str):
    """权限检查装饰器"""
    def dependency(user=Depends(get_current_user_token)):
        if required_scope not in user["scopes"]:
            raise HTTPException(status_code=403, detail=f"Missing scope: {required_scope}")
        return user
    return Depends(dependency)

@app.get("/api/admin/users")
async def admin_users(user=Depends(require_scope("admin"))):
    """需要 admin scope 的端点"""
    return {"users": []}
```

### 2. 社交登录集成（Google / GitHub）

```python
# social_login.py
import httpx
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/auth/social")

# ==================== Google OAuth ====================

GOOGLE_CLIENT_ID = "xxx.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET = "xxx"
GOOGLE_REDIRECT_URI = "https://app.example.com/auth/social/google/callback"

@router.get("/google")
async def google_login():
    """重定向到 Google 授权页面"""
    params = {
        "client_id": GOOGLE_CLIENT_ID,
        "redirect_uri": GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": "openid email profile",
        "access_type": "offline",
        "prompt": "consent",
    }
    url = f"https://accounts.google.com/o/oauth2/v2/auth?{urllib.parse.urlencode(params)}"
    return RedirectResponse(url)

@router.get("/google/callback")
async def google_callback(code: str):
    """Google 回调处理"""
    async with httpx.AsyncClient() as client:
        # 1. 用 code 换 token
        token_resp = await client.post("https://oauth2.googleapis.com/token", data={
            "code": code,
            "client_id": GOOGLE_CLIENT_ID,
            "client_secret": GOOGLE_CLIENT_SECRET,
            "redirect_uri": GOOGLE_REDIRECT_URI,
            "grant_type": "authorization_code",
        })
        tokens = token_resp.json()

        # 2. 获取用户信息
        user_resp = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        google_user = user_resp.json()

    # 3. 查找或创建本地用户
    user = await find_or_create_user(
        provider="google",
        provider_id=google_user["id"],
        email=google_user["email"],
        name=google_user.get("name"),
        avatar=google_user.get("picture"),
    )

    # 4. 签发本地 JWT
    access_token = create_access_token({"sub": user.id, "email": user.email})
    return {"access_token": access_token, "user": {"id": user.id, "email": user.email}}

# ==================== GitHub OAuth ====================

GITHUB_CLIENT_ID = "xxx"
GITHUB_CLIENT_SECRET = "xxx"

@router.get("/github")
async def github_login():
    params = {
        "client_id": GITHUB_CLIENT_ID,
        "redirect_uri": "https://app.example.com/auth/social/github/callback",
        "scope": "user:email",
        "state": secrets.token_hex(16),
    }
    url = f"https://github.com/login/oauth/authorize?{urllib.parse.urlencode(params)}"
    return RedirectResponse(url)

@router.get("/github/callback")
async def github_callback(code: str):
    async with httpx.AsyncClient() as client:
        # 换取 token
        token_resp = await client.post(
            "https://github.com/login/oauth/access_token",
            json={"client_id": GITHUB_CLIENT_ID, "client_secret": GITHUB_CLIENT_SECRET, "code": code},
            headers={"Accept": "application/json"},
        )
        access_token = token_resp.json()["access_token"]

        # 获取用户信息
        user_resp = await client.get(
            "https://api.github.com/user",
            headers={"Authorization": f"token {access_token}", "Accept": "application/json"},
        )
        gh_user = user_resp.json()

        # 获取邮箱（GitHub 可能隐藏）
        email_resp = await client.get(
            "https://api.github.com/user/emails",
            headers={"Authorization": f"token {access_token}"},
        )
        emails = email_resp.json()
        primary_email = next((e["email"] for e in emails if e["primary"]), emails[0]["email"])

    user = await find_or_create_user(
        provider="github",
        provider_id=str(gh_user["id"]),
        email=primary_email,
        name=gh_user.get("login"),
        avatar=gh_user.get("avatar_url"),
    )

    token = create_access_token({"sub": user.id, "email": user.email})
    return {"access_token": token}
```

### 3. 微信登录集成

```python
# wechat_login.py
import httpx

WECHAT_APP_ID = "wx_xxx"
WECHAT_APP_SECRET = "xxx"

@router.get("/wechat")
async def wechat_login():
    """PC 端微信扫码登录"""
    params = {
        "appid": WECHAT_APP_ID,
        "redirect_uri": "https://app.example.com/auth/social/wechat/callback",
        "response_type": "code",
        "scope": "snsapi_login",
        "state": secrets.token_hex(16),
    }
    url = f"https://open.weixin.qq.com/connect/qrconnect?{urllib.parse.urlencode(params)}#wechat_redirect"
    return RedirectResponse(url)

@router.get("/wechat/callback")
async def wechat_callback(code: str):
    async with httpx.AsyncClient() as client:
        # 1. 用 code 换 access_token
        token_resp = await client.get("https://api.weixin.qq.com/sns/oauth2/access_token", params={
            "appid": WECHAT_APP_ID,
            "secret": WECHAT_APP_SECRET,
            "code": code,
            "grant_type": "authorization_code",
        })
        data = token_resp.json()
        if "errcode" in data:
            raise HTTPException(status_code=400, detail=data.get("errmsg", "WeChat auth failed"))

        access_token = data["access_token"]
        openid = data["openid"]
        unionid = data.get("unionid")

        # 2. 获取用户信息
        user_resp = await client.get("https://api.weixin.qq.com/sns/userinfo", params={
            "access_token": access_token,
            "openid": openid,
            "lang": "zh_CN",
        })
        wx_user = user_resp.json()

    user = await find_or_create_user(
        provider="wechat",
        provider_id=unionid or openid,
        email=None,  # 微信不提供邮箱
        name=wx_user.get("nickname"),
        avatar=wx_user.get("headimgurl"),
    )

    token = create_access_token({"sub": user.id})
    return {"access_token": token}
```

### 4. Node.js (Express + Passport)

```javascript
// auth.controller.ts
import express from 'express';
import passport from 'passport';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import { Strategy as GitHubStrategy } from 'passport-github2';
import jwt from 'jsonwebtoken';

const router = express.Router();

// Passport 序列化
passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

// Google Strategy
passport.use(new GoogleStrategy(
  {
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: '/auth/google/callback',
  },
  async (accessToken, refreshToken, profile, done) => {
    const user = await findOrCreateUser({
      provider: 'google',
      providerId: profile.id,
      email: profile.emails[0].value,
      name: profile.displayName,
      avatar: profile.photos?.[0]?.value,
    });
    done(null, user);
  }
));

// GitHub Strategy
passport.use(new GitHubStrategy(
  {
    clientID: process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
    callbackURL: '/auth/github/callback',
  },
  async (accessToken, refreshToken, profile, done) => {
    const user = await findOrCreateUser({
      provider: 'github',
      providerId: profile.id,
      email: profile.emails?.[0]?.value,
      name: profile.username,
      avatar: profile.photos?.[0]?.value,
    });
    done(null, user);
  }
));

// 路由
router.get('/auth/google', passport.authenticate('google', { scope: ['profile', 'email'] }));
router.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login' }),
  (req, res) => {
    const token = jwt.sign(
      { sub: req.user.id, email: req.user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?token=${token}`);
  }
);

router.get('/auth/github', passport.authenticate('github', { scope: ['user:email'] }));
router.get('/auth/github/callback',
  passport.authenticate('github', { failureRedirect: '/login' }),
  (req, res) => {
    const token = jwt.sign(
      { sub: req.user.id, email: req.user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?token=${token}`);
  }
);

// JWT 验证中间件
export function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing token' });
  }

  try {
    const token = authHeader.slice(7);
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = payload;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

export default router;
```

### 5. Java Spring Security OAuth2

```java
// SecurityConfig.java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasAuthority("SCOPE_admin")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthConverter())
                )
            )
            .cors(cors -> cors.configurationSource(corsConfigSource()));
        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthConverter() {
        JwtGrantedAuthoritiesConverter authoritiesConverter = new JwtGrantedAuthoritiesConverter();
        authoritiesConverter.setAuthorityPrefix("SCOPE_");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
        return converter;
    }
}

// application.yml 配置
// spring:
//   security:
//     oauth2:
//       resourceserver:
//         jwt:
//           issuer-uri: https://auth.example.com
//           jwk-set-uri: https://auth.example.com/.well-known/jwks.json
```

---

## Common Patterns

### 1. Token 刷新流程

```
客户端                         授权服务器                      资源服务器
  │                               │                              │
  │  1. Access Token 过期         │                              │
  │  ─────────────────────────►   │                              │
  │                               │                              │
  │  2. 发送 Refresh Token        │                              │
  │  ─────────────────────────►   │                              │
  │                               │                              │
  │  3. 验证 Refresh Token        │                              │
  │  4. 签发新 Access Token       │                              │
  │  5. 轮换 Refresh Token (可选) │                              │
  │  ◄─────────────────────────   │                              │
  │                               │                              │
  │  6. 使用新 Access Token       │                              │
  │  ─────────────────────────────────────────────────────────►  │
  │                               │                              │
  │  7. 返回资源                  │                              │
  │  ◄─────────────────────────────────────────────────────────  │
```

### 2. JWT 安全最佳实践

```python
# jwt_security.py - JWT 安全配置
class JWTSecurityConfig:
    # ✅ 使用 RS256 (非对称) 而非 HS256 (对称) - 授权服务器用私钥签，资源服务器用公钥验
    ALGORITHM = "RS256"

    # ✅ 设置合理的过期时间
    ACCESS_TOKEN_EXPIRE = timedelta(minutes=15)   # 短期
    REFRESH_TOKEN_EXPIRE = timedelta(days=7)       # 较长但可撤销

    # ✅ 包含必要声明
    REQUIRED_CLAIMS = ["sub", "iat", "exp", "jti", "iss"]

    # ✅ 使用 jti 实现 Token 黑名单（用于登出/撤销）
    # 生产环境用 Redis 存储黑名单，设置过期时间 = Token 剩余有效期
```

### 3. 多应用 SSO 架构

```
用户 ──► App A ──► 认证中心 ──► IdP (Google/企业AD)
               │                  │
               │◄── SSO Token ────│
               │                  │
用户 ──► App B ──► 认证中心       │
               │    │             │
               │    │ (已有会话)  │
               │◄───┘             │
               │                  │
           本地 JWT              │
           (含 SSO 会话 ID)
```

### 4. OAuth2 Scope 设计

```python
# scope_design.py
SCOPES = {
    # 基础信息
    "openid":    "Access your user ID",
    "profile":   "Access your name and avatar",
    "email":     "Access your email address",

    # 业务权限
    "read":      "Read access to your data",
    "write":     "Write access to your data",
    "admin":     "Administrative access",

    # 第三方集成
    "calendar:read":  "Read calendar events",
    "calendar:write": "Manage calendar events",
    "files:read":     "Read files",
    "files:write":    "Upload and modify files",
}
```

### 5. 安全检查清单

```
✅ Token 安全
  - Access Token 短期有效 (5-15 分钟)
  - Refresh Token 可撤销，存储在 HttpOnly Cookie
  - 使用 RS256 非对称签名
  - Token 中不存敏感信息（密码、信用卡号等）

✅ PKCE
  - 所有公共客户端 (SPA/Mobile) 必须使用 PKCE
  - code_verifier 至少 43 字符
  - 使用 S256 方法（不用 plain）

✅ CSRF 防护
  - OAuth state 参数必须随机且验证
  - 使用 SameSite Cookie 属性

✅ 重定向安全
  - redirect_uri 必须预注册且精确匹配
  - 不允许通配符 redirect_uri
  - 使用 HTTPS（localhost 除外）

✅ 密钥管理
  - 定期轮换签名密钥
  - 使用 JWKS 端点发布公钥
  - 敏感配置从环境变量读取

✅ 日志与审计
  - 记录所有登录/登出事件
  - 记录 Token 签发/撤销事件
  - 异常登录行为告警（频繁失败、异地登录）
```

---

## References

- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749) — OAuth 2.0 核心规范
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636) — Proof Key for Code Exchange
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html) — OIDC 规范
- [JWT RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519) — JSON Web Token 规范
- [SAML 2.0](https://docs.oasis-open.org/security/saml/v2.0/saml-core-2.0-os.pdf) — SAML 核心规范
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2) — Google OAuth 文档
- [GitHub OAuth](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps) — GitHub OAuth 文档
- [微信开放平台](https://open.weixin.qq.com/) — 微信登录文档
- [Auth0 文档](https://auth0.com/docs/) — 通用认证参考实现
- [Keycloak](https://www.keycloak.org/documentation) — 开源 IAM 方案
