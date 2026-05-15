# AI_GUIDE.md — vibe-coding-cn 通用入口

> **本文件是所有 AI 工具的统一入口。**
> Claude Code、Cursor、Copilot、Windsurf、Cline 等工具均会通过各自的适配文件指向本文件。

---

## 这是什么？

[vibe-coding-cn](https://github.com/yongc2025/vibe-coding-cn) 是一个**工业母机**——你克隆它，用它孵化自己的项目。它不是让你直接开发的代码库，而是一个**项目孵化器**，包含：

| 资源 | 路径 | 用途 |
|---|---|---|
| 🛠️ Skills（技能库） | `assets/skills/` | 让 AI 变成领域专家 |
| 🚀 初始化脚本 | `vibe-init.sh` | 一键创建新项目（自动复制 Skills + 配置） |
| 🔄 全自动工作流 | `assets/workflow/auto-dev-loop/` | 需求→计划→实施→验证的 5 步闭环 |
| 📋 提示词库 | `assets/prompts/` | 编程场景专用提示词 |
| 📖 方法论文档 | `assets/documents/` | 核心理念、入门指南、架构模板 |
| 📂 案例研究 | `assets/documents/case-studies/` | 真实项目的完整开发过程 |
| 🔧 工具脚本 | `assets/scripts/` | skill-picker.py 等辅助工具 |

---

## 场景 → 模块速查表

> **不知道用什么？先查这张表。**

| 我要做… | 推荐项目类型 | 必装 Skills | 关键文档 |
|---|---|---|---|
| **加密货币量化交易** | `quant-crypto` | ccxt, cryptofeed, hummingbot, coingecko, polymarket, postgresql, timescaledb, proxychains | [ccxt 技能](assets/skills/ccxt/SKILL.md) · [案例](assets/documents/case-studies/) |
| **A 股量化** | `quant-astock` | postgresql, timescaledb | — |
| **美股量化** | `quant-usstock` | postgresql, timescaledb, twscrape, proxychains | — |
| **APP / 小程序** | `app` | canvas-dev, ddd-doc-steward, snapdom + (flutter/react-native/uniapp/wechat-mp 四选一) | [canvas-dev](assets/skills/canvas-dev/SKILL.md) |
| **企业级应用 / 管理后台** | `enterprise` | canvas-dev, ddd-doc-steward, sop-generator, postgresql, claude-cookbooks | [架构模板](assets/documents/principles/fundamentals/通用项目架构模板.md) |
| **互联网 SaaS** | `saas` | canvas-dev, ddd-doc-steward, sop-generator, postgresql, telegram-dev, snapdom | — |
| **Telegram Bot** | `custom --skills telegram-dev` | telegram-dev, postgresql | [telegram-dev](assets/skills/telegram-dev/SKILL.md) |
| **数据采集 / 爬虫** | `custom --skills twscrape,proxychains` | twscrape, proxychains | [twscrape](assets/skills/twscrape/SKILL.md) |
| **不知道选什么** | 先看下方流程 | — | [分步指南](docs/onboarding/分步指南.md) |

> **所有类型都自动包含基础技能：** skills-skills（元技能）、sop-generator、canvas-dev、headless-cli
>
> **查看完整推荐：** `python assets/scripts/skill-picker.py --list`
> **按类型推荐：** `python assets/scripts/skill-picker.py --type <类型>`

---

## 完整孵化流程（从 0 到项目完成，再到持续迭代）

### 阶段一：孵化项目

#### 第 1 步：克隆母机

```bash
git clone --recursive https://github.com/yongc2025/vibe-coding-cn.git
cd vibe-coding-cn
git submodule update --init --recursive
```

#### 第 2 步：用 vibe-init.sh 创建项目

```bash
./vibe-init.sh --help                    # 查看所有选项
./vibe-init.sh --type <类型> --name <项目名>

# 示例
./vibe-init.sh --type quant-crypto --name my-bot
./vibe-init.sh --type app --name my-app
./vibe-init.sh --type custom --name my-project --skills ccxt,postgresql,canvas-dev

# 先预览不执行
./vibe-init.sh --type quant-crypto --name my-bot --dry-run
```

#### 第 3 步：填写项目定义

进入项目目录，创建 `docs/PROJECT_BRIEF.md`，回答 4 个问题：

1. **目标**：我要解决什么问题？
2. **现状**：当前是什么情况？
3. **差距**：从现状到目标，缺什么？
4. **判断标准**：怎么知道做完了？

#### 第 3.5 步：需求理解确认（必须，不可跳过）

用户填写 PROJECT_BRIEF.md 后，AI 必须先执行以下确认流程，用户确认后才能进入第 4 步：

**AI 必须做：**
1. 用 3-5 句话复述对需求的理解
2. 列出需求中所有模糊点
3. 对每个模糊点给出 2-4 个选项，标注推荐选项（✅）和推荐理由
4. 列出默认假设（用户不做选择时的兜底方案）

**AI 禁止做：**
- ❌ "你想怎么做？""你觉得用什么技术栈？"（开放性问题）
- ✅ "目标链选 A/BSC 还是 B/Solana？推荐 A，因为土狗项目最多"（选项式问题）

**确认方式**：用户回复选择（如"1A 2B 3A"）或"都按推荐"即视为确认。

**产出**：更新 `docs/PROJECT_BRIEF.md`，补充确认后的决策记录。

**锁定后**：需求锁定，后续步骤基于锁定的需求进行。锁定后的新需求记入 `docs/MEMORY.md`，不立即打乱当前流程。

#### 第 4 步：用 AI 开发

确认 Skills 已就位：`ls skills/`

在项目的 CLAUDE.md / AGENTS.md 中引用 Skills：

```markdown
## 可用技能
@skills/ccxt/SKILL.md
@skills/postgresql/SKILL.md
```

第 4 步不是一步完成的，而是包含 4 个子步骤，每个子步骤都需要用户确认：

##### 4.1 设计方案确认

AI 基于锁定的需求，输出技术方案：

- **架构设计**：整体架构描述（入口→处理→存储→输出）
- **技术栈选型**：每层用什么技术，为什么选它
- **模块划分**：目录结构和各模块职责
- **关键接口**：核心模块的输入输出定义
- **方案对比**：如有备选方案，给出对比表和推荐理由

用户确认后，产出 `docs/DESIGN.md` 并锁定。

##### 4.2 任务拆解确认

AI 基于锁定的方案，拆解为具体任务：

- **P0（必须完成）**：MVP 核心功能，每个任务有编号、依赖、预估时间、验收标准
- **P1（重要）**：MVP 后第一批迭代
- **P2（可选）**：锦上添花
- **执行顺序**：任务间的依赖关系和执行顺序

用户确认后，产出 `docs/TASKS.md` 并锁定。

##### 4.3 逐个实施

AI 按任务编号顺序执行，**每次只做一个任务**：

- 完成后展示：做了什么、变更了哪些文件、如何验证
- 标记任务状态（✅ 完成）并更新进度
- 遇到阻塞时暂停，给出 2-3 个解决方案让用户选择
- **禁止一口气做完所有任务**

每完成一个任务，更新 `docs/TASKS.md` 的进度。

##### 4.4 阶段验证

P0 任务全部完成后，AI 输出阶段验证报告：

- 所有 P0 任务的完成状态和验证结果
- 已知问题和后续建议
- P1/P2 任务的优先级建议

用户确认后，进入第 5 步。

**产出文档汇总：**

| 子步骤 | 产出 | 说明 |
|--------|------|------|
| 4.1 | `docs/DESIGN.md` | 技术方案，锁定后只读 |
| 4.2 | `docs/TASKS.md` | 任务清单，可追加 P1/P2 |
| 4.3 | 代码 + `docs/TASKS.md` 更新 | 逐个任务实施 |
| 4.4 | `docs/MEMORY.md` 更新 | 项目记忆和状态 |

> 💡 **为什么拆成 4 步？** 不拆的话，AI 读完需求直接写代码，产出的东西没有文档、没有对齐、没有验收，用户拿到的是黑盒，100% 需要重构。拆开后每一步都有文档产出和用户确认，开发过程透明可追溯。

#### 第 5 步：验证与提交

**交付前自检：**
- [ ] `docs/PROJECT_BRIEF.md` — 需求文档存在且已锁定
- [ ] `docs/DESIGN.md` — 技术方案文档存在且已锁定
- [ ] `docs/TASKS.md` — 任务清单存在，P0 任务全部标记完成
- [ ] `docs/MEMORY.md` — 项目记忆存在，记录了关键决策和踩坑
- [ ] 代码可运行 — 核心功能通过测试

```bash
pytest tests/ -v
git add . && git commit -m "feat: 完成核心功能"
git push origin main
```

> 📖 **详细指南：** [docs/onboarding/孵化我的项目.md](docs/onboarding/孵化我的项目.md) · [分步指南](docs/onboarding/分步指南.md)

---

### 阶段二：持续迭代

项目第一个版本完成后，进入迭代阶段：

#### 添加新功能

1. 在 `docs/PROJECT_BRIEF.md` 中补充新需求（或创建 `docs/TODO.md`）
2. 按「接口定义 → 实现 → 测试 → 提交」的顺序推进
3. 每次只改一个模块，避免大范围重构

#### 添加新 Skills（在子项目中）

当现有 Skills 不够用时：

```bash
# 方式 1：从母机复制
cp -r /path/to/vibe-coding-cn/assets/skills/<skill-name>/ skills/

# 方式 2：用元技能生成新 Skill
cat skills/skills-skills/SKILL.md
# 将 SKILL.md 内容 + 你的领域资料一起喂给 AI，AI 会生成新的 SKILL.md

# 方式 3：用 skill-picker 搜索
python assets/scripts/skill-picker.py --search <关键词>
```

添加后，在项目的 CLAUDE.md / AGENTS.md 中引用新 Skill。

#### 同步母机更新

母机（vibe-coding-cn）会持续更新 Skills 和文档。子项目同步方式：

```bash
# 方式 1：手动复制更新的 Skill
cp -r /path/to/vibe-coding-cn/assets/skills/<updated-skill>/ skills/

# 方式 2：重新运行 vibe-init.sh（会提示覆盖）
./vibe-init.sh --type <类型> --name <项目名> --update-skills
```

> ⚠️ 注意：vibe-init.sh 覆盖 Skills 时会保留你的自定义修改（通过 `.skill-meta.json` 追踪）。

---

### 阶段三：反哺母机

你在子项目中创造了有价值的 Skill？贡献回母机，让更多人受益：

#### 贡献新 Skill

1. 确保你的 Skill 遵循规范（参考 `skills-skills/SKILL.md` 的格式）
2. 在子项目中测试通过
3. Fork 母机仓库，将 Skill 放入 `assets/skills/<your-skill>/`
4. 更新 `assets/skills/README.md` 的 Skills 一览表
5. 更新 `INSTALL-PLAN.md` 的 Skills 矩阵（如涉及新业务线）
6. 提交 PR

#### 贡献文档 / 案例

1. 新文档放入 `assets/documents/` 对应子目录
2. 案例放入 `assets/documents/case-studies/`
3. 更新对应目录的 `README.md`
4. 提交 PR

#### 贡献提示词

1. 新提示词放入 `assets/prompts/`
2. 更新提示词索引
3. 提交 PR

> 📖 **贡献指南：** [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 学习路径（推荐顺序）

| 顺序 | 做什么 | 看什么 |
|---|---|---|
| 1 | 理解核心理念 | [Vibe Coding 哲学原理](assets/documents/guides/getting-started/Vibe%20Coding%20哲学原理.md) |
| 2 | 学会定义问题 | [问题求解能力](assets/documents/principles/fundamentals/问题求解能力.md) |
| 3 | 搭建环境 | [开发环境搭建](assets/documents/guides/getting-started/开发环境搭建.md) · [IDE 配置](assets/documents/guides/getting-started/IDE配置.md) |
| 4 | 学会架构 | [通用项目架构模板](assets/documents/principles/fundamentals/通用项目架构模板.md) |
| 5 | 避坑 | [常见坑汇总](assets/documents/principles/fundamentals/常见坑汇总.md) |
| 6 | 看案例 | [案例研究](assets/documents/case-studies/) |
| 7 | 动手做 | 按上方「完整孵化流程」开始 |

---

## 核心原则

1. **规划就是一切** — 先想清楚再动手
2. **上下文是第一性要素** — 垃圾进，垃圾出
3. **先结构，后代码** — 一定先规划好框架
4. **接口先行，实现后补** — 先定义输入输出
5. **一次只改一个模块** — 保持专注
6. **文档即上下文** — 不是事后补，是同步写
7. **奥卡姆剃刀** — 如无必要，勿增代码
8. **凡是 AI 能做的，就不要人工做**
9. **AI 给建议，用户做选择** — 禁止问开放性问题（"你想怎么做？"），必须给出选项让用户选（"A/B/C 你选哪个？推荐 A，因为..."）。每个决策点都要有推荐选项和理由
10. **每步确认后锁定** — 需求未确认不得做设计，设计未确认不得拆任务，任务未确认不得写代码。不可跳步

---

## 各 AI 工具入口说明

本文件（`AI_GUIDE.md`）是通用入口。以下文件会自动被对应 AI 工具读取，内容均为指向本文件的引用：

| AI 工具 | 入口文件 | 说明 |
|---|---|---|
| Claude Code | `CLAUDE.md` | Claude 项目上下文 |
| Cursor | `.cursorrules` | Cursor 规则文件 |
| GitHub Copilot | `.github/copilot-instructions.md` | Copilot 指令 |
| Windsurf | `.windsurfrules` | Windsurf 规则 |
| Cline | `.clinerules` | Cline 规则 |
| OpenClaw | `AGENTS.md` | OpenClaw Agent 行为准则（独立内容，非指向） |

> 如果你使用的 AI 工具不在列表中，直接把本文件内容粘贴到对话中即可。

---

## 相关资源

- 📖 [README.md](README.md) — 项目主文档（详细版）
- 📘 [AGENTS.md](AGENTS.md) — AI Agent 行为准则
- 📋 [INSTALL-PLAN.md](INSTALL-PLAN.md) — Skills 矩阵规划
- 💬 [Telegram 交流群](https://t.me/glue_coding)
