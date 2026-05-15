# Skills 全自动编程能力规划

> 基于 vibe-coding-cn 仓库，按业务线规划所需 Skills

## 仓库位置

```
/root/.openclaw/workspace/vibe-coding-cn/
```

---

## 一、可用 Skills 清单（仓库自带 20 个 + Claude 官方 16 个）

### 仓库自带 Skills（20 个）

| # | Skill | 路径 | 核心能力 |
|---|-------|------|---------|
| 1 | skills-skills | assets/skills/skills-skills/ | ⭐ 元技能：从文档/代码/API 生成新 Skill |
| 2 | sop-generator | assets/skills/sop-generator/ | 将需求/流程规范化为可执行 SOP |
| 3 | canvas-dev | assets/skills/canvas-dev/ | Canvas 白板驱动开发，AI 架构总师 |
| 4 | ddd-doc-steward | assets/skills/ddd-doc-steward/ | 文档驱动开发，文档管家 |
| 5 | headless-cli | assets/skills/headless-cli/ | 无头 AI CLI 批量调用（Gemini/Claude/Codex） |
| 6 | claude-code-guide | assets/skills/claude-code-guide/ | Claude Code CLI 使用指南 |
| 7 | claude-cookbooks | assets/skills/claude-cookbooks/ | Claude API 最佳实践 |
| 8 | tmux-autopilot | assets/skills/tmux-autopilot/ | tmux 自动化操控（AI 蜂群协作） |
| 9 | postgresql | assets/skills/postgresql/ | PostgreSQL 完整专家 |
| 10 | timescaledb | assets/skills/timescaledb/ | PostgreSQL 时序扩展 |
| 11 | ccxt | assets/skills/ccxt/ | 加密货币交易所统一 API（150+ 交易所） |
| 12 | coingecko | assets/skills/coingecko/ | CoinGecko 行情/基本面 API |
| 13 | cryptofeed | assets/skills/cryptofeed/ | 加密货币实时 WebSocket 数据流 |
| 14 | hummingbot | assets/skills/hummingbot/ | 量化交易机器人框架（做市/套利） |
| 15 | polymarket | assets/skills/polymarket/ | 预测市场 API |
| 16 | telegram-dev | assets/skills/telegram-dev/ | Telegram Bot 开发 |
| 17 | twscrape | assets/skills/twscrape/ | Twitter/X 数据抓取 |
| 18 | snapdom | assets/skills/snapdom/ | DOM 快照与 UI 测试 |
| 19 | proxychains | assets/skills/proxychains/ | 代理链配置 |
| 20 | markdown-to-epub | assets/skills/markdown-to-epub/ | Markdown 转 EPUB |

### Claude 官方 Skills（submodule，16 个）

| # | Skill | 核心能力 |
|---|-------|---------|
| 1 | algorithmic-art | 算法艺术生成 |
| 2 | brand-guidelines | 品牌规范 |
| 3 | canvas-design | Canvas 设计 |
| 4 | doc-coauthoring | 文档协作 |
| 5 | docx | Word 文档生成 |
| 6 | frontend-design | 前端设计 |
| 7 | internal-comms | 内部沟通 |
| 8 | mcp-builder | MCP 服务构建 |
| 9 | pdf | PDF 生成 |
| 10 | pptx | PPT 生成 |
| 11 | skill-creator | 技能创建 |
| 12 | slack-gif-creator | Slack GIF 创建 |
| 13 | theme-factory | 主题工厂 |
| 14 | webapp-testing | Web 应用测试 |
| 15 | web-artifacts-builder | Web 构件构建 |
| 16 | xlsx | Excel 生成 |

### 全自动开发闭环工作流

```
assets/workflow/auto-dev-loop/
├── step1_需求输入.jsonl     # 规格锁定 Agent
├── step2_执行计划.jsonl     # 计划编排 Agent
├── step3_实施变更.jsonl     # 实施变更 Agent
├── step4_验证发布.jsonl     # 验证发布 Agent
└── step5_总控与循环.jsonl   # 总控循环 Agent（失败回跳）
```

---

## 二、按业务线 Skills 矩阵

### 🔴 量化工具/系统 — 加密货币

| 优先级 | Skill | 用途 | 状态 |
|--------|-------|------|------|
| 🔴 必装 | ccxt | 统一接入 Binance/OKX/Bybit 等 150+ 交易所 | ✅ 仓库自带 |
| 🔴 必装 | cryptofeed | 实时 WebSocket tick 级行情推送 | ✅ 仓库自带 |
| 🔴 必装 | hummingbot | 做市/套利策略框架 | ✅ 仓库自带 |
| 🔴 必装 | postgresql | 订单库、账户库、策略配置 | ✅ 仓库自带 |
| 🔴 必装 | timescaledb | K线/tick 时序数据存储 | ✅ 仓库自带 |
| 🟡 推荐 | coingecko | 基本面数据（市值、流通量） | ✅ 仓库自带 |
| 🟡 推荐 | polymarket | 预测市场套利 | ✅ 仓库自带 |
| 🟡 推荐 | proxychains | 交易所 API 代理 | ✅ 仓库自带 |
| ⚪ 待生成 | backtesting | 回测引擎（backtrader/vnpy） | ❌ 需用元技能生成 |
| ⚪ 待生成 | risk-management | 风控模块（仓位/止损/熔断） | ❌ 需用元技能生成 |

### 🔴 量化工具/系统 — A 股

| 优先级 | Skill | 用途 | 状态 |
|--------|-------|------|------|
| 🔴 必装 | postgresql | 股票池、因子库、回测结果 | ✅ 仓库自带 |
| 🔴 必装 | timescaledb | 分钟线/日线时序存储 | ✅ 仓库自带 |
| 🟡 推荐 | canvas-dev | 策略架构图、因子关联图 | ✅ 仓库自带 |
| 🟡 推荐 | sop-generator | 回测→实盘标准化 SOP | ✅ 仓库自带 |
| ⚪ 待生成 | tushare-akshare | A 股数据源（tushare/akshare） | ❌ 需用元技能生成 |
| ⚪ 待生成 | quant-factor | 因子挖掘/IC 分析/多因子组合 | ❌ 需用元技能生成 |
| ⚪ 待生成 | backtesting | 回测引擎 | ❌ 需用元技能生成 |

### 🔴 量化工具/系统 — 美股

| 优先级 | Skill | 用途 | 状态 |
|--------|-------|------|------|
| 🔴 必装 | postgresql | 数据存储 | ✅ 仓库自带 |
| 🔴 必装 | timescaledb | 时序存储 | ✅ 仓库自带 |
| 🟡 推荐 | twscrape | Twitter 情绪因子 | ✅ 仓库自带 |
| 🟡 推荐 | proxychains | API 代理 | ✅ 仓库自带 |
| ⚪ 待生成 | alpaca-polygon | 美股数据源（Alpaca/Polygon.io） | ❌ 需用元技能生成 |
| ⚪ 待生成 | quant-factor | 因子分析 | ❌ 需用元技能生成 |

### 🟡 APP / 小程序

| 优先级 | Skill | 用途 | 状态 |
|--------|-------|------|------|
| 🔴 必装 | canvas-dev | UI 架构图、页面流程图 | ✅ 仓库自带 |
| 🔴 必装 | ddd-doc-steward | 需求→技术→API 文档全链路 | ✅ 仓库自带 |
| 🔴 必装 | frontend-design | 前端 UI 设计 | ✅ Claude 官方 |
| 🟡 推荐 | snapdom | UI 自动化测试 | ✅ 仓库自带 |
| 🟡 推荐 | webapp-testing | Web 应用测试 | ✅ Claude 官方 |
| ⚪ 待生成 | flutter | Flutter 跨平台开发 | ❌ 需用元技能生成 |
| ⚪ 待生成 | react-native | React Native 开发 | ❌ 需用元技能生成 |
| ⚪ 待生成 | uniapp | UniApp 小程序开发 | ❌ 需用元技能生成 |
| ⚪ 待生成 | wechat-miniprogram | 微信小程序 API | ❌ 需用元技能生成 |

### 🟡 企业级应用

| 优先级 | Skill | 用途 | 状态 |
|--------|-------|------|------|
| 🔴 必装 | ddd-doc-steward | 文档驱动开发 | ✅ 仓库自带 |
| 🔴 必装 | canvas-dev | 系统架构图、微服务拓扑 | ✅ 仓库自带 |
| 🔴 必装 | sop-generator | 部署/运维/上线 SOP | ✅ 仓库自带 |
| 🔴 必装 | postgresql | 企业级数据存储 | ✅ 仓库自带 |
| 🔴 必装 | skills-skills | 生成企业领域技能 | ✅ 仓库自带 |
| 🟡 推荐 | claude-cookbooks | API 集成最佳实践 | ✅ 仓库自带 |
| 🟡 推荐 | mcp-builder | MCP 服务构建 | ✅ Claude 官方 |
| ⚪ 待生成 | rbac | RBAC 权限管理 | ❌ 需用元技能生成 |
| ⚪ 待生成 | workflow-engine | 工作流引擎（Activiti/Flowable） | ❌ 需用元技能生成 |
| ⚪ 待生成 | message-queue | 消息队列（RabbitMQ/Kafka） | ❌ 需用元技能生成 |
| ⚪ 待生成 | microservice | 微服务架构（Spring Cloud/gRPC） | ❌ 需用元技能生成 |

### 🟡 互联网 SaaS 应用

| 优先级 | Skill | 用途 | 状态 |
|--------|-------|------|------|
| 🔴 必装 | canvas-dev | 多租户架构设计 | ✅ 仓库自带 |
| 🔴 必装 | ddd-doc-steward | API/SDK/开发者文档 | ✅ 仓库自带 |
| 🔴 必装 | postgresql | 多租户数据隔离 | ✅ 仓库自带 |
| 🔴 必装 | sop-generator | CI/CD/灰度/故障 SOP | ✅ 仓库自带 |
| 🟡 推荐 | telegram-dev | Bot 通知集成 | ✅ 仓库自带 |
| 🟡 推荐 | snapdom | 前端 E2E 测试 | ✅ 仓库自带 |
| 🟡 推荐 | web-artifacts-builder | Web 构件快速搭建 | ✅ Claude 官方 |
| ⚪ 待生成 | multi-tenant | 多租户架构 | ❌ 需用元技能生成 |
| ⚪ 待生成 | billing-subscription | 计费/订阅系统（Stripe） | ❌ 需用元技能生成 |
| ⚪ 待生成 | oauth-sso | OAuth2/SSO 认证 | ❌ 需用元技能生成 |
| ⚪ 待生成 | event-driven | 事件驱动架构 | ❌ 需用元技能生成 |

---

## 三、通用基础层（所有业务线共享）

这些是"地基"，不管做什么项目都要先有：

| 优先级 | Skill | 为什么必装 |
|--------|-------|-----------|
| 🔴 | skills-skills | 元技能，用来生成上面所有"待生成"的 Skill |
| 🔴 | canvas-dev | 任何项目都需要架构设计 |
| 🔴 | sop-generator | 标准化流程，自动化前提 |
| 🔴 | ddd-doc-steward | 文档即上下文，AI 编程的燃料 |
| 🔴 | headless-cli | 无头调用 AI，全自动编程的核心 |
| 🔴 | tmux-autopilot | 蜂群协作，多 AI 并行开发 |
| 🔴 | postgresql | 几乎所有项目都需要数据库 |

---

## 四、执行计划

### Phase 1：安装通用基础（立即）
1. 确认仓库已 clone ✅
2. 确认 submodule 已初始化 ✅
3. 将 Skills 注册到 OpenClaw 可用技能列表
4. 验证元技能可用

### Phase 2：安装加密货币量化 Skills（优先级最高）
1. 直接使用：ccxt, cryptofeed, hummingbot, timescaledb, coingecko, polymarket
2. 生成缺失：backtesting, risk-management

### Phase 3：安装其他量化 Skills
1. 生成：tushare-akshare, alpaca-polygon, quant-factor

### Phase 4：安装 APP/企业/SaaS Skills
1. 生成：flutter, react-native, uniapp, rbac, multi-tenant 等

### Phase 5：接入全自动开发闭环
1. 配置 auto-dev-loop 工作流
2. 接入 headless-cli + tmux-autopilot 实现蜂群协作
