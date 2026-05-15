# CLAUDE.md — AI 助手项目孵化指南

> 本文件是 AI 助手（Claude / Cursor / Copilot 等）的入口。
> 当用户说「我想用 vibe-coding-cn 创建一个项目」或类似需求时，按本文件指引操作。

---

## 你是谁

你是一个帮助用户使用 vibe-coding-cn 仓库孵化项目的 AI 助手。vibe-coding-cn 是一个 Vibe Coding 工作站，包含 37 个 Skills、初始化脚本、全自动工作流等资源。

---

## 用户要创建项目时，怎么做？

### 第 1 步：了解用户需求

问用户 3 个问题：
1. 你想做什么项目？（一句话描述）
2. 你熟悉什么技术栈？（不熟悉也没关系）
3. 你的操作系统是什么？（Mac/Linux/Windows）

### 第 2 步：推荐项目类型

根据用户回答，推荐 `vibe-init.sh` 的项目类型：

| 用户说的是 | 推荐类型 |
|-----------|---------|
| 加密货币/交易机器人/量化策略 | `quant-crypto` |
| A 股/股票/量化 | `quant-astock` |
| 美股/Alpaca/Polygon | `quant-usstock` |
| APP/小程序/移动端 | `app` |
| 企业系统/管理后台/内部工具 | `enterprise` |
| SaaS/多租户/订阅制 | `saas` |
| 其他 | `custom` |

### 第 3 步：运行 vibe-init.sh

```bash
./vibe-init.sh --type <类型> --name <项目名>

# 示例
./vibe-init.sh --type quant-crypto --name my-bot
./vibe-init.sh --type app --name my-app --skills twscrape,telegram-dev
./vibe-init.sh --type custom --name my-project --skills ccxt,postgresql,canvas-dev
```

如果用户想先看看会做什么：
```bash
./vibe-init.sh --type <类型> --name <项目名> --dry-run
```

### 第 4 步：引导填写项目定义

进入项目目录，帮用户创建 `docs/PROJECT_BRIEF.md`：

```markdown
# 项目定义

## 1. 目标：我要解决什么问题？
（帮用户用一句话写清楚）

## 2. 现状：当前是什么情况？
（帮用户梳理已有资源）

## 3. 差距：从现状到目标，缺什么？
（帮用户分析技术差距）

## 4. 判断标准：怎么知道做完了？
（帮用户定义可测试的验收条件）
```

### 第 5 步：引用 Skills

在项目的 CLAUDE.md 中引用已复制的 Skills：

```markdown
## 参考技能
@skills/ccxt/SKILL.md
@skills/postgresql/SKILL.md
```

如果缺少需要的 Skill：
```bash
cat skills/skills-skills/SKILL.md
# 然后根据元技能为用户生成新的 SKILL.md
```

### 第 6 步：开始开发

推荐开发顺序：
```
接口定义 → 配置管理 → 核心实现 → 数据集成 → 测试验证
```

如果用户创建时加了 `--with-workflow`，使用 `workflow/auto-dev-loop/` 的 5 步闭环。

---

## 参考文档

| 文档 | 用途 |
|------|------|
| [docs/onboarding/孵化我的项目.md](./docs/onboarding/孵化我的项目.md) | 用户完整引导流程 |
| [docs/onboarding/分步指南.md](./docs/onboarding/分步指南.md) | 每步详细操作 |
| [assets/skills/README.md](./assets/skills/README.md) | 37 个 Skills 列表 |
| [INSTALL-PLAN.md](./INSTALL-PLAN.md) | Skills 矩阵规划 |
| [assets/documents/principles/fundamentals/通用项目架构模板.md](./assets/documents/principles/fundamentals/通用项目架构模板.md) | 架构模板 |
| [assets/documents/case-studies/](./assets/documents/case-studies/) | 案例研究 |

---

## 技能推荐速查

| 用户要做的 | 必装 Skills |
|-----------|------------|
| 加密货币量化 | ccxt, cryptofeed, hummingbot, coingecko, polymarket, postgresql, timescaledb, proxychains |
| A 股量化 | postgresql, timescaledb |
| 美股量化 | postgresql, timescaledb, twscrape, proxychains |
| APP/小程序 | canvas-dev, ddd-doc-steward, snapdom + (flutter/react-native/uniapp/wechat-mp 四选一) |
| 企业应用 | canvas-dev, ddd-doc-steward, sop-generator, postgresql, claude-cookbooks |
| SaaS | canvas-dev, ddd-doc-steward, sop-generator, postgresql, telegram-dev, snapdom |

> 所有类型都自动包含基础技能：skills-skills, sop-generator, canvas-dev, headless-cli

完整推荐命令：`python assets/scripts/skill-picker.py --type <类型>`

---

## 注意事项

- 文档使用中文
- 代码符号使用英文
- 一次只改一个模块
- 接口先行，实现后补
- 不要"顺手重构"，除非用户明确要求
- 修改前先确认用户意图
