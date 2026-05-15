---
name: onboarding
description: "Vibe Coding 新用户引导：从零开始使用 vibe-coding-cn 仓库完成项目。当用户问「怎么开始」「如何使用」「新手入门」「项目初始化」「vibe-init」时触发。"
---

# onboarding Skill

引导新用户使用 vibe-coding-cn 仓库（37 个 Skills），从零开始完成一个项目。

## When to Use This Skill

触发当以下任一条件满足：
- 用户问「怎么开始用 vibe-coding-cn」「如何使用这个仓库」
- 用户是新用户，需要从零搭建项目
- 用户问「vibe-init 怎么用」「项目怎么初始化」
- 用户需要选择合适的 Skills
- 用户问「vibe coding 流程是什么」「开发顺序是什么」

## Not For / Boundaries

- 不是代码生成器——不直接写业务代码
- 不是调试工具——不解决具体的 bug
- 不替代仓库本身的内容——只做导航和引导
- 如果用户已经有明确的技术问题，直接回答，不需要走引导流程

## Quick Reference

### Pattern 1: 新用户入门

**场景**：用户第一次接触 vibe-coding-cn

**步骤**：
1. 确认用户已克隆仓库（`git clone --recursive`）
2. 确认子模块已初始化（`git submodule update --init --recursive`）
3. 引导阅读入门指南：`assets/documents/guides/getting-started/`
4. 引导使用 `vibe-init.sh` 创建项目

**提示词**：
```
你好！欢迎使用 vibe-coding-cn。

这是一个 Vibe Coding 工作站，核心理念是「规划就是一切」。

快速上手：
1. 你有什么项目想法？（一句话描述）
2. 你的项目属于哪种类型？
   - quant-crypto（加密货币量化）
   - quant-astock（A 股量化）
   - quant-usstock（美股量化）
   - app（APP/小程序）
   - enterprise（企业级应用）
   - saas（互联网 SaaS）
   - custom（自定义）

告诉我，我帮你推荐 Skills 和创建命令。
```

### Pattern 2: 使用 vibe-init.sh 创建项目

**场景**：用户已确定项目类型

**步骤**：
1. 根据类型选择 vibe-init.sh 参数
2. 执行创建命令
3. 引导填写 docs/PROJECT_BRIEF.md
4. 引导在 CLAUDE.md 中引用 Skills

**命令模板**：
```bash
# 基础创建
./vibe-init.sh --type <类型> --name <项目名>

# 带工作流
./vibe-init.sh --type <类型> --name <项目名> --with-workflow

# 自定义 Skills
./vibe-init.sh --type custom --name <项目名> --skills skill1,skill2,skill3

# 先预览
./vibe-init.sh --type <类型> --name <项目名> --dry-run
```

### Pattern 3: 推荐 Skills

**场景**：用户需要知道用哪些 Skills

**步骤**：
1. 运行 `python assets/scripts/skill-picker.py --type <类型>`
2. 查看必装和可选 Skills
3. 用元技能生成缺失的 Skill

### Pattern 4: 生成缺失的 Skill

**场景**：仓库中没有用户需要的 Skill

**步骤**：
1. 查看元技能 `assets/skills/skills-skills/SKILL.md`
2. 准备领域资料（文档、代码、规范）
3. 让 AI 根据元技能生成新 Skill

### Pattern 5: 开发流程引导

**场景**：用户已搭建好骨架，不知道下一步做什么

**推荐顺序**：
```
contract（接口定义）→ config（配置管理）→ writer（核心实现）→ collect（数据采集）→ validate（测试验证）
```

**参考文档**：
- 方法论：`assets/documents/guides/playbook/四阶段×十二原则方法论.md`
- 经验：`assets/documents/guides/playbook/vibe-coding-经验收集.md`
- 避坑：`assets/documents/principles/fundamentals/常见坑汇总.md`
- 案例：`assets/documents/case-studies/`

## Examples

### Example 1: 加密货币量化项目

**输入**：「我想做一个加密货币交易机器人」

**流程**：
1. 推荐：`./vibe-init.sh --type quant-crypto --name my-bot --with-workflow`
2. Skills：ccxt, cryptofeed, hummingbot, coingecko, polymarket, postgresql, timescaledb, proxychains
3. 引导填写 PROJECT_BRIEF.md
4. 引导查看案例：`assets/documents/case-studies/polymarket-dev/`

### Example 2: 企业级应用

**输入**：「我要做一个企业管理系统」

**流程**：
1. 推荐：`./vibe-init.sh --type enterprise --name my-enterprise`
2. Skills：canvas-dev, ddd-doc-steward, sop-generator, postgresql, claude-cookbooks
3. 待生成：rbac, workflow-engine, microservice

### Example 3: 缺少 Skill

**输入**：「我需要对接 Dune Analytics，但没有这个 Skill」

**流程**：
1. 引导查看元技能：`cat assets/skills/skills-skills/SKILL.md`
2. 让用户准备 Dune Analytics API 文档
3. 让 AI 生成 `dune-analytics/SKILL.md`

## References

- `assets/skills/skills-skills/SKILL.md` — 元技能
- `assets/documents/principles/fundamentals/通用项目架构模板.md` — 架构模板
- `assets/documents/guides/getting-started/` — 入门指南
- `assets/documents/case-studies/` — 案例研究
- `INSTALL-PLAN.md` — Skills 规划矩阵
- `vibe-init.sh` — 项目初始化脚本

---

- Sources: vibe-coding-cn 仓库文档
- Last updated: 2025-05-15
- Known limits: 引导流程假设用户使用 Python 技术栈
