# vibe-coding-cn 操作手册

> 从母盘拉取技能到实际开发的完整流程，覆盖手动开发与全自动开发两条路径

---

## 目录

- [一、整体架构](#一整体架构)
- [二、环境准备](#二环境准备)
- [三、一键拉取](#三一键拉取)
- [四、开发模式一：手动引用技能 + Copilot/Codex](#四开发模式一手动引用技能--copilotcodex)
- [五、开发模式二：全自动开发闭环](#五开发模式二全自动开发闭环)
- [六、开发模式三：白板驱动开发](#六开发模式三白板驱动开发)
- [七、开发模式四：蜂群协作（多 AI 并行）](#七开发模式四蜂群协作多-ai-并行)
- [八、各业务线开发指南](#八各业务线开发指南)
- [九、自动化能力速查表](#九自动化能力速查表)
- [十、常见问题](#十常见问题)

---

## 一、整体架构

vibe-coding-cn 提供的不只是技能文件，而是一套**从需求到部署的完整自动化开发体系**：

```
┌─────────────────────────────────────────────────────────────────┐
│                    vibe-coding-cn 母盘                           │
│                                                                 │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
│  │  Skills   │  │ Workflow  │  │  Scripts  │  │   Tools   │   │
│  │ 36个技能   │  │ 五步闭环   │  │ 拉取脚本   │  │ 工具配置   │   │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘   │
│        │              │              │              │           │
└────────┼──────────────┼──────────────┼──────────────┼───────────┘
         │              │              │              │
    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
    │ 模式一  │    │ 模式二  │    │ 模式三  │    │ 模式四  │
    │ 手动    │    │ 全自动  │    │ 白板    │    │ 蜂群    │
    │ 引用    │    │ 闭环    │    │ 驱动    │    │ 协作    │
    │         │    │         │    │         │    │         │
    │Copilot  │    │5步自动  │    │架构图   │    │多AI并行 │
    │Codex    │    │需求→部署 │    │驱动编码  │    │tmux编排 │
    └─────────┘    └─────────┘    └─────────┘    └─────────┘
```

### 四种开发模式

| 模式 | 适用场景 | 自动化程度 | 依赖工具 |
|------|---------|-----------|---------|
| **手动引用** | 日常开发、小功能 | ★★☆☆☆ | VS Code + Copilot/Codex |
| **全自动闭环** | 完整功能、新模块 | ★★★★★ | Claude Code / Codex CLI |
| **白板驱动** | 架构设计、重构、Code Review | ★★★☆☆ | Canvas 工具 + AI |
| **蜂群协作** | 大型项目、多模块并行 | ★★★★★ | tmux + 多 AI 终端 |

---

## 二、环境准备

### 必需

| 工具 | 用途 | 安装 |
|------|------|------|
| Git | 拉取母盘 | `apt install git` / `brew install git` |
| VS Code | 开发 IDE | [code.visualstudio.com](https://code.visualstudio.com) |
| Copilot 或 Codex | AI 编码助手 | VS Code 扩展商店安装 |

### 按开发模式选装

| 模式 | 额外依赖 |
|------|---------|
| 手动引用 | 无 |
| 全自动闭环 | Claude Code CLI 或 Codex CLI |
| 白板驱动 | Canvas 工具（VS Code 插件或 Web 版） |
| 蜂群协作 | tmux 3.0+（`apt install tmux`） |

### 母盘获取

```bash
# 克隆母盘
git clone https://github.com/<your-org>/vibe-coding-cn.git ~/vibe-coding-cn

# 验证
ls ~/vibe-coding-cn/assets/skills/ | wc -l   # 应该输出 36
```

---

## 三、一键拉取

### Windows 用户

```powershell
# 在新项目目录下执行
cd D:\projects\my-new-app

# 拉取 SaaS 技能（自动检测母盘位置 D:\workspace\vibe-coding-cn）
powershell -ExecutionPolicy Bypass -File D:\workspace\vibe-coding-cn\assets\scripts\bootstrap.ps1 -Profile saas

# 拉取技能 + 工作流
powershell -ExecutionPolicy Bypass -File D:\workspace\vibe-coding-cn\assets\scripts\bootstrap.ps1 -Profile saas -Workflow

# 预览（不实际复制）
powershell -ExecutionPolicy Bypass -File D:\workspace\vibe-coding-cn\assets\scripts\bootstrap.ps1 -Profile saas -DryRun

# 全量拉取
powershell -ExecutionPolicy Bypass -File D:\workspace\vibe-coding-cn\assets\scripts\bootstrap.ps1 -All -Workflow
```

### macOS / Linux 用户

```bash
# 进入你的新项目目录
cd ~/projects/my-new-app

# 拉取 SaaS 技能（自动检测母盘位置）
bash ~/vibe-coding-cn/assets/scripts/bootstrap.sh -p saas

# 拉取技能 + 工作流
bash ~/vibe-coding-cn/assets/scripts/bootstrap.sh -p saas -w

# 预览（不实际复制）
bash ~/vibe-coding-cn/assets/scripts/bootstrap.sh -p saas -d

# 全量拉取
bash ~/vibe-coding-cn/assets/scripts/bootstrap.sh -a -w
```

### 可用 Profile

| Profile | 业务线 | 技能数 | 关键技能 |
|---------|--------|--------|---------|
| `saas` | SaaS 应用 | 18 | 多租户、计费、认证、事件驱动 |
| `enterprise` | 企业级应用 | 17 | RBAC、工作流、消息队列、微服务 |
| `quant-crypto` | 加密货币量化 | 19 | ccxt、hummingbot、回测、风控 |
| `quant-astock` | A 股量化 | 14 | tushare-akshare、quant-factor |
| `quant-us` | 美股量化 | 16 | alpaca-polygon、quant-factor |
| `app-mini` | APP/小程序 | 15 | flutter、react-native、uniapp |
| `full-stack` | 全栈 | 35 | 全部业务技能 |
| `all` | 全部 | 36+ | 全部技能 + 工作流 |

> 所有 profile 自动包含 9 个通用基础技能（skills-skills、canvas-dev、ddd-doc-steward、sop-generator、headless-cli、tmux-autopilot、postgresql 等）

### 输出结构

```
新项目/
└── .vibe/
    ├── INDEX.md                    ← 自动生成的技能索引
    ├── skills/
    │   ├── multi-tenant/SKILL.md
    │   ├── billing-sub/SKILL.md
    │   └── ...
    └── workflow/auto-dev-loop/     ← -w 时拉取
        ├── step1_需求输入.jsonl
        ├── step2_执行计划.jsonl
        ├── step3_实施变更.jsonl
        ├── step4_验证发布.jsonl
        ├── step5_总控与循环.jsonl
        └── workflow_engine/
            ├── runner.py           ← 状态机调度器
            └── hook_runner.sh      ← 文件监听 Hook
```

---

## 四、开发模式一：手动引用技能 + Copilot/Codex

**适用**：日常开发、小功能迭代、快速原型

### 流程

```
① 拉取技能 → ② 选择相关 SKILL.md → ③ 引用到 AI 上下文 → ④ 描述需求 → ⑤ AI 生成代码
```

### VS Code + Copilot Chat

```
步骤：
1. 打开 Copilot Chat 面板
2. 输入 #file: 选择 .vibe/skills/xxx/SKILL.md
3. 描述你的需求

示例对话：

#file:.vibe/skills/multi-tenant/SKILL.md

按照这个技能的指导，帮我设计一个多租户的用户表，
使用 PostgreSQL，共享数据库 + tenant_id 列方式，
需要支持邮箱登录，邮箱在租户内唯一。
```

### VS Code + Codex

```
步骤：
1. 在项目根目录创建 .cursorrules 或 AGENTS.md
2. 声明技能路径：

   开发规范：
   - 多租户架构参考 .vibe/skills/multi-tenant/SKILL.md
   - 计费系统参考 .vibe/skills/billing-sub/SKILL.md
   - 认证模块参考 .vibe/skills/oauth-sso/SKILL.md

3. Codex 自动读取这些文件作为上下文
4. 直接描述需求即可
```

### Claude Code CLI

```bash
# 加载多个技能作为上下文
claude \
  --context .vibe/skills/multi-tenant/SKILL.md \
  --context .vibe/skills/billing-sub/SKILL.md \
  "帮我实现一个 SaaS 平台的多租户计费系统，使用 Python + FastAPI"
```

### 最佳实践

```
✅ 一次引用 1-3 个相关技能（上下文窗口有限）
✅ 先让 AI 读技能，再描述具体需求
✅ 技能 = 规范，你的需求 = 具体任务
✅ 遇到问题让 AI 回去重新读技能文件

❌ 不要一次加载所有技能
❌ 不要只引用技能不给具体需求
```

---

## 五、开发模式二：全自动开发闭环

**适用**：完整功能开发、新模块、从零搭建系统

这是 vibe-coding-cn 的核心自动化能力——**五步闭环工作流**，从需求到部署全自动：

### 工作流总览

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Step1  │───▶│  Step2  │───▶│  Step3  │───▶│  Step4  │───▶│  Step5  │
│ 需求输入 │    │ 执行计划 │    │ 实施变更 │    │ 验证发布 │    │ 总控循环 │
│         │    │         │    │         │    │         │    │         │
│规格锁定  │    │任务拆解  │    │AI编码   │    │测试验证  │    │失败回跳  │
│消除歧义  │    │DAG依赖  │    │自动提交  │    │质量门禁  │    │成功放行  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └────┬────┘
                    ▲                                            │
                    │              失败回跳（最多3次）             │
                    └────────────────────────────────────────────┘
```

### 五步详解

#### Step 1: 需求输入（规格锁定 Agent）

**做什么**：将模糊的业务需求转化为精确、无歧义的工程规格书

```
输入：用户的自然语言需求描述
输出：《锁定规格书》（JSON 格式）

包含：
- 功能需求（FR）：具体要做什么
- 非功能需求（NFR）：性能/安全/可用性
- 非目标（Non-Goals）：明确不做什么（防范围蔓延）
- 验收标准（AC）：怎么算做完
- 约束条件：技术栈、时间、资源
```

**使用方式**：
```bash
# 方式1：直接用 AI 加载 step1 提示词
claude --context .vibe/workflow/auto-dev-loop/step1_需求输入.jsonl \
  "我要开发一个 SaaS 多租户计费系统，支持 Stripe 支付"

# 方式2：用工作流引擎自动触发
cd .vibe/workflow/auto-dev-loop
python3 workflow_engine/runner.py start
```

#### Step 2: 执行计划（计划编排 Agent）

**做什么**：将规格书转化为可执行的工程蓝图

```
输入：《锁定规格书》
输出：《执行计划》

包含：
- 任务 DAG（有向无环图）：任务拆解 + 依赖关系
- 测试计划：每个任务对应的测试用例
- 回滚方案：出问题怎么恢复
- 监控计划：上线后监控什么
- 时间估算：每个任务的工时
```

#### Step 3: 实施变更（AI 编码 Agent）

**做什么**：按计划自动编写代码

```
输入：《执行计划》
输出：代码变更（Git commit）

能力：
- 按 DAG 顺序逐个完成任务
- 参考 .vibe/skills/ 中的 SKILL.md 作为编码规范
- 自动创建文件、编写代码、运行测试
- 每个任务完成后自动 git commit
```

**关键：这一步会自动读取 `.vibe/skills/` 中的技能文件作为编码参考！**

#### Step 4: 验证发布（质量门禁）

**做什么**：自动运行测试、检查代码质量

```
输入：代码变更
输出：验证报告

检查项：
- 单元测试通过率
- 集成测试通过率
- 代码覆盖率
- Lint 检查
- 安全扫描
- 性能基准
```

#### Step 5: 总控循环

**做什么**：根据验证结果决定下一步

```
验证通过 → 放行（完成）
验证失败 → 回跳到 Step 3（重新编码）
           最多重试 3 次
           超过 3 次 → 熔断，人工介入
```

### 启动方式

#### 方式1：工作流引擎（推荐）

```bash
cd .vibe/workflow/auto-dev-loop

# 启动工作流
python3 workflow_engine/runner.py start

# 查看当前状态
python3 workflow_engine/runner.py status

# 自动模式（文件监听 + 自动触发）
./workflow_engine/hook_runner.sh
```

#### 方式2：手动逐步执行

```bash
# Step 1: 让 AI 生成规格书
claude --context step1_需求输入.jsonl "我的需求是..."

# Step 2: 让 AI 生成执行计划
claude --context step2_执行计划.jsonl "规格书如下：..."

# Step 3: 让 AI 按计划编码
claude --context step3_实施变更.jsonl "执行计划如下：..."

# Step 4: 让 AI 验证
claude --context step4_验证发布.jsonl "请验证当前代码..."

# Step 5: 让 AI 决定是否循环
claude --context step5_总控与循环.jsonl "验证结果如下：..."
```

#### 方式3：Claude Code CLI 串联

```bash
# 一次性串联（高级用法）
claude \
  --context .vibe/workflow/auto-dev-loop/step1_需求输入.jsonl \
  --context .vibe/workflow/auto-dev-loop/step2_执行计划.jsonl \
  --context .vibe/workflow/auto-dev-loop/step3_实施变更.jsonl \
  --context .vibe/workflow/auto-dev-loop/step4_验证发布.jsonl \
  --context .vibe/workflow/auto-dev-loop/step5_总控与循环.jsonl \
  "请按五步闭环工作流，帮我开发一个用户认证模块"
```

### 与技能的配合

全自动闭环中，**Step 3（实施变更）会自动参考 `.vibe/skills/` 中的技能**：

```
Step 3 编码时：
  ├─ 检查 .vibe/skills/ 目录
  ├─ 加载相关的 SKILL.md 作为编码规范
  ├─ 按照技能中的代码示例和最佳实践来写代码
  └─ 生成的代码自动遵循技能定义的模式
```

**所以拉取技能 + 启动闭环 = 全自动高质量开发**

---

## 六、开发模式三：白板驱动开发

**适用**：架构设计、系统重构、Code Review、团队协作

### 核心理念

```
传统：代码 → 口头沟通 → 脑补架构 → 代码失控
Canvas：代码 ⇄ 白板 ⇄ AI ⇄ 人类（白板为单一真相源）
```

### 使用场景

| 场景 | 做什么 |
|------|--------|
| **新项目架构** | 让 AI 分析需求，生成架构白板，确认后驱动编码 |
| **接手遗留项目** | AI 读取代码，自动生成架构白板，5分钟看懂系统 |
| **代码重构** | 在白板上调整架构，AI 按新白板重构代码 |
| **Code Review** | 变更前后白板对比，一目了然看出影响范围 |
| **团队协作** | 新人指着白板讲，5分钟理解系统全貌 |

### 流程

```
① 输入项目/需求 → ② AI 生成架构白板 → ③ 人类审阅调整
                                                      ↓
⑥ 代码实现 ←───── ⑤ AI 按白板编码 ←────── ④ 确认白板
```

### 使用方式

```bash
# 让 AI 读取 canvas-dev 技能
claude --context .vibe/skills/canvas-dev/SKILL.md \
  "分析当前项目结构，生成架构白板"

# 从白板驱动编码
claude --context .vibe/skills/canvas-dev/SKILL.md \
  "根据这个白板 JSON，生成对应的代码实现"
```

### AI 架构总师角色

canvas-dev 技能让 AI 充当"架构总师"：
- **洞察力优先**：不是罗列文件，而是揭示设计哲学和数据流
- **认知负荷最小**：生成的架构图人类一看就懂
- **美学与功能并重**：好的架构图本身就是艺术品

---

## 七、开发模式四：蜂群协作（多 AI 并行）

**适用**：大型项目、多模块并行开发、需要高吞吐

### 核心理念

```
单 AI：需求 → AI → 代码（串行，慢）
蜂群：  需求 → 任务拆分 → 多个 AI 终端并行编码 → 汇总
                                        ↓
                              tmux 自动化编排
```

### 依赖

- tmux 3.0+（`apt install tmux`）
- 多个 AI CLI（Claude Code / Codex / Gemini）
- tmux-autopilot 技能（`.vibe/skills/tmux-autopilot/SKILL.md`）

### 流程

```
① 需求拆分 → 多个子任务
② 每个子任务分配一个 tmux pane
③ 每个 pane 启动一个 AI CLI 执行任务
④ tmux-autopilot 监控所有 pane 状态
⑤ 自动救援卡死的 AI（超时重启）
⑥ 汇总所有 pane 的输出
```

### 使用方式

```bash
# 1. 创建多 pane 布局
tmux new-session -s dev -n main
tmux split-window -h    # 左右分屏
tmux split-window -v    # 再分

# 2. 在每个 pane 中启动 AI 任务
# pane 0: 处理用户模块
tmux send-keys -t 0 "claude '实现用户注册登录模块'" Enter

# pane 1: 处理订单模块
tmux send-keys -t 1 "claude '实现订单管理模块'" Enter

# pane 2: 处理支付模块
tmux send-keys -t 2 "claude '实现 Stripe 支付集成'" Enter

# 3. 用 tmux-autopilot 监控
# AI 自动读取各 pane 输出，救援卡死任务
```

### headless-cli 批量调用

```bash
# 批量翻译文件
for f in src/*.ts; do
  claude --print "将以下代码翻译为 Python: $(cat $f)" > "${f%.ts}.py"
done

# 多模型交叉审查
claude --print "审查这段代码: $(cat main.py)" > review_claude.md
codex --print "审查这段代码: $(cat main.py)" > review_codex.md

# YOLO 模式（全权限，跳过确认）
codex --yolo "实现这个功能"
```

---

## 八、各业务线开发指南

### SaaS 应用

**典型项目**：B2B SaaS 平台、企业服务、在线工具

**拉取**：`bash bootstrap.sh -p saas -w`

**推荐开发模式**：全自动闭环（模式二）

**开发流程**：

```
Step 1 (规格锁定):
  需求："开发一个 SaaS 多租户计费平台"
  产出：锁定规格书（含多租户隔离方案、Stripe 计费、OAuth 登录）

Step 2 (执行计划):
  任务拆解：
  ├─ T1: 数据库设计（多租户表结构）
  ├─ T2: 租户中间件（tenant_id 自动注入）
  ├─ T3: OAuth 认证模块（Google/GitHub/微信）
  ├─ T4: Stripe 计费模块（订阅/用量/Webhook）
  ├─ T5: 事件驱动通信（Kafka 事件总线）
  └─ T6: RBAC 权限模块
  依赖：T1 → T2 → T3/T4 并行 → T5 → T6

Step 3 (AI 编码):
  AI 自动参考 .vibe/skills/ 中的 SKILL.md：
  ├─ multi-tenant/SKILL.md → 租户中间件代码
  ├─ billing-sub/SKILL.md  → Stripe 集成代码
  ├─ oauth-sso/SKILL.md    → OAuth 登录代码
  ├─ event-driven/SKILL.md → 事件总线代码
  └─ rbac/SKILL.md         → 权限校验代码

Step 4 (验证): 自动运行测试 + Lint
Step 5 (循环): 失败则回跳 Step 3 重试
```

### 企业级应用

**典型项目**：ERP、OA、CRM、内部管理系统

**拉取**：`bash bootstrap.sh -p enterprise -w`

**推荐开发模式**：白板驱动（模式三）+ 全自动闭环（模式二）

**开发流程**：

```
架构阶段（白板驱动）：
  ① canvas-dev 生成系统架构白板
  ② 确认微服务拆分方案
  ③ 确认审批流程 BPMN 设计

开发阶段（全自动闭环）：
  ④ 用 auto-dev-loop 逐步实现各模块
  ⑤ rbac + workflow-engine 驱动权限和审批流开发
```

### 加密货币量化

**典型项目**：自动交易机器人、做市策略、套利系统

**拉取**：`bash bootstrap.sh -p quant-crypto -w`

**推荐开发模式**：手动引用（模式一）+ 蜂群协作（模式四）

**开发流程**：

```
数据层（手动引用）：
  ① ccxt/SKILL.md → 接入交易所 API
  ② cryptofeed/SKILL.md → WebSocket 实时行情
  ③ timescaledb/SKILL.md → 时序数据存储

策略层（蜂群协作）：
  ④ 多个 tmux pane 并行开发不同策略
     pane 0: 做市策略（参考 hummingbot/SKILL.md）
     pane 1: 套利策略（参考 ccxt/SKILL.md）
     pane 2: 网格策略（参考 hummingbot/SKILL.md）

验证层：
  ⑤ backtesting/SKILL.md → 回测验证
  ⑥ risk-management/SKILL.md → 风控接入
```

### A 股量化

**拉取**：`bash bootstrap.sh -p quant-astock -w`

**推荐开发模式**：手动引用（模式一）

```
① tushare-akshare/SKILL.md → 数据源接入
② quant-factor/SKILL.md    → 因子挖掘 + IC 分析
③ backtesting/SKILL.md     → 策略回测
④ risk-management/SKILL.md → 风控上线
```

### 美股量化

**拉取**：`bash bootstrap.sh -p quant-us -w`

**推荐开发模式**：手动引用（模式一）

```
① alpaca-polygon/SKILL.md → Alpaca/Polygon 数据接入
② quant-factor/SKILL.md   → 因子分析
③ twscrape/SKILL.md       → Twitter 情绪因子（可选）
④ backtesting + risk-management → 回测 + 风控
```

### APP / 小程序

**拉取**：`bash bootstrap.sh -p app-mini -w`

**推荐开发模式**：手动引用（模式一）+ 白板驱动（模式三）

```
选型阶段：
  对比 flutter/react-native/uniapp/wechat-mp 的 SKILL.md

架构阶段（白板驱动）：
  canvas-dev 生成页面流程图 + 组件树

开发阶段：
  按对应技术栈的 SKILL.md 指导编码
```

---

## 九、自动化能力速查表

| 能力 | 技能/工具 | 触发方式 | 输出 |
|------|----------|---------|------|
| **需求规格化** | step1_需求输入.jsonl | `claude --context step1...` | 锁定规格书 |
| **任务拆解** | step2_执行计划.jsonl | `claude --context step2...` | DAG 任务图 |
| **自动编码** | step3_实施变更.jsonl | `claude --context step3...` | 代码 + commit |
| **自动验证** | step4_验证发布.jsonl | `claude --context step4...` | 验证报告 |
| **失败重试** | step5_总控与循环.jsonl | 自动触发 | 回跳/放行 |
| **架构白板** | canvas-dev/SKILL.md | `claude --context canvas...` | 架构图 JSON |
| **批量 AI 调用** | headless-cli/SKILL.md | `claude --print` | 批量结果 |
| **蜂群协作** | tmux-autopilot/SKILL.md | tmux 多 pane | 并行编码 |
| **SOP 生成** | sop-generator/SKILL.md | `claude --context sop...` | 标准化流程文档 |
| **文档驱动** | ddd-doc-steward/SKILL.md | `claude --context ddd...` | API/技术文档 |
| **一键拉取** | bootstrap.sh | `bash bootstrap.sh -p xxx` | .vibe/ 目录 |

---

## 十、常见问题

### Q: 母盘更新了，新项目怎么同步？

```bash
# 重新拉取（覆盖）
bash ~/vibe-coding-cn/assets/scripts/bootstrap.sh -p saas

# 或只更新某个技能
cp ~/vibe-coding-cn/assets/skills/multi-tenant/SKILL.md \
   .vibe/skills/multi-tenant/SKILL.md
```

### Q: 全自动闭环需要什么 CLI 工具？

闭环工作流的提示词是通用的，支持：
- **Claude Code CLI**（推荐，上下文最长）
- **Codex CLI**（YOLO 模式最强）
- **Gemini CLI**（免费额度最多）
- **直接用 VS Code Copilot**（手动逐步执行）

### Q: 没有网络能用吗？

可以。所有技能和工作流模板都是本地 Markdown/JSON 文件，不依赖网络。母盘 clone 一次即可离线使用。

### Q: 能自定义 profile 吗？

编辑 `bootstrap.sh` 中的 `SKILLS_PROFILE`：

```bash
SKILLS_PROFILE[my-custom]="
    multi-tenant
    billing-sub
    ccxt
    backtesting
"
```

然后 `bash bootstrap.sh -p my-custom`。

### Q: 技能文件太大，AI 上下文放不下怎么办？

每个 SKILL.md 是模块化的：
- **Quick Reference**：最核心，优先加载
- **Common Patterns**：按需参考
- **References**：链接资源，不占上下文

只让 AI 读前半部分（Quick Reference）即可。

### Q: 能不能不拉取，直接引用母盘中的技能？

可以。不运行 bootstrap.sh，直接在 .cursorrules 中写绝对路径：

```
参考 ~/vibe-coding-cn/assets/skills/multi-tenant/SKILL.md
```

但这样换机器就失效了，推荐拉取到项目内。
