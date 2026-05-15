#!/bin/bash
# ============================================================
# vibe-init.sh — 从母机初始化新项目
# 用法: ./vibe-init.sh --type <类型> [--name <项目名>] [--skills <额外技能>]
# ============================================================

set -e

# ── 配置 ──────────────────────────────────────────────────────
MACHINE_DIR="${VIBE_MACHINE_DIR:-$HOME/vibe-coding-cn}"
# 如果母机在 workspace 里，自动检测
if [ -d "$HOME/.openclaw/workspace/vibe-coding-cn" ]; then
    MACHINE_DIR="$HOME/.openclaw/workspace/vibe-coding-cn"
fi

# ── 颜色 ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ── 帮助 ──────────────────────────────────────────────────────
usage() {
    cat <<EOF
${BLUE}vibe-init.sh${NC} — 从母机初始化新项目

${YELLOW}用法:${NC}
  ./vibe-init.sh --type <类型> [选项]

${YELLOW}项目类型:${NC}
  quant-crypto    加密货币量化（ccxt + cryptofeed + hummingbot + timescaledb）
  quant-astock    A股量化（tushare + akshare + timescaledb）
  quant-usstock   美股量化（alpaca + polygon + timescaledb）
  app             APP/小程序（canvas-dev + ddd-doc-steward）
  enterprise      企业级应用（canvas-dev + ddd-doc-steward + sop-generator）
  saas            互联网SaaS（canvas-dev + ddd-doc-steward + sop-generator）
  custom          自定义（需手动指定 --skills）

${YELLOW}选项:${NC}
  --type <类型>       项目类型（必填）
  --name <名称>       项目目录名（默认: my-<类型>-project）
  --dir <路径>        项目创建目录（默认: 当前目录）
  --skills <技能列表>  额外技能，逗号分隔
  --with-workflow     同时复制 auto-dev-loop 工作流
  --no-codex          不复制 .codex/ 配置
  --no-agents         不复制 AGENTS.md
  --dry-run           只显示会做什么，不实际执行
  --help              显示此帮助

${YELLOW}示例:${NC}
  ./vibe-init.sh --type quant-crypto --name my-bot
  ./vibe-init.sh --type app --name my-app --skills twscrape,telegram-dev
  ./vibe-init.sh --type custom --skills ccxt,postgresql,canvas-dev
EOF
    exit 0
}

# ── 技能映射 ──────────────────────────────────────────────────
# 每种项目类型的默认技能
declare -A TYPE_SKILLS
TYPE_SKILLS[quant-crypto]="ccxt,cryptofeed,hummingbot,coingecko,polymarket,postgresql,timescaledb,proxychains"
TYPE_SKILLS[quant-astock]="postgresql,timescaledb"
TYPE_SKILLS[quant-usstock]="postgresql,timescaledb,twscrape,proxychains"
TYPE_SKILLS[app]="canvas-dev,ddd-doc-steward,snapdom"
TYPE_SKILLS[enterprise]="canvas-dev,ddd-doc-steward,sop-generator,postgresql,claude-cookbooks"
TYPE_SKILLS[saas]="canvas-dev,ddd-doc-steward,sop-generator,postgresql,telegram-dev,snapdom"

# 所有类型共用的基础技能
BASE_SKILLS="skills-skills,sop-generator,canvas-dev,headless-cli"

# ── 解析参数 ──────────────────────────────────────────────────
TYPE=""
PROJECT_NAME=""
PROJECT_DIR="."
EXTRA_SKILLS=""
WITH_WORKFLOW=false
NO_CODEX=false
NO_AGENTS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)       TYPE="$2"; shift 2 ;;
        --name)       PROJECT_NAME="$2"; shift 2 ;;
        --dir)        PROJECT_DIR="$2"; shift 2 ;;
        --skills)     EXTRA_SKILLS="$2"; shift 2 ;;
        --with-workflow) WITH_WORKFLOW=true; shift ;;
        --no-codex)   NO_CODEX=true; shift ;;
        --no-agents)  NO_AGENTS=true; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --help|-h)    usage ;;
        *)            echo -e "${RED}未知参数: $1${NC}"; usage ;;
    esac
done

if [ -z "$TYPE" ]; then
    echo -e "${RED}错误: 必须指定 --type${NC}"
    usage
fi

# ── 验证母机存在 ──────────────────────────────────────────────
if [ ! -d "$MACHINE_DIR/assets/skills" ]; then
    echo -e "${RED}错误: 找不到母机目录: $MACHINE_DIR${NC}"
    echo "请设置 VIBE_MACHINE_DIR 环境变量，或将母机放在 ~/.openclaw/workspace/vibe-coding-cn/"
    exit 1
fi

# ── 计算技能列表 ──────────────────────────────────────────────
SKILLS_LIST="$BASE_SKILLS"
if [ -n "${TYPE_SKILLS[$TYPE]}" ]; then
    SKILLS_LIST="$SKILLS_LIST,${TYPE_SKILLS[$TYPE]}"
fi
if [ -n "$EXTRA_SKILLS" ]; then
    SKILLS_LIST="$SKILLS_LIST,$EXTRA_SKILLS"
fi

# 去重
SKILLS_LIST=$(echo "$SKILLS_LIST" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

# ── 项目目录 ──────────────────────────────────────────────────
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="my-${TYPE}-project"
fi
FULL_PATH="$PROJECT_DIR/$PROJECT_NAME"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  vibe-init — 从母机初始化项目${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}类型:${NC}     $TYPE"
echo -e "  ${YELLOW}项目:${NC}     $FULL_PATH"
echo -e "  ${YELLOW}技能:${NC}     $SKILLS_LIST"
echo -e "  ${YELLOW}工作流:${NC}   $WITH_WORKFLOW"
echo -e "  ${YELLOW}母机:${NC}     $MACHINE_DIR"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] 以下操作不会实际执行${NC}"
    echo ""
fi

# ── 创建项目目录 ──────────────────────────────────────────────
run() {
    if $DRY_RUN; then
        echo -e "  ${BLUE}[DRY]${NC} $*"
    else
        "$@"
    fi
}

echo -e "${GREEN}[1/5] 创建项目目录...${NC}"
run mkdir -p "$FULL_PATH"

# ── 复制 AGENTS.md ────────────────────────────────────────────
if ! $NO_AGENTS; then
    echo -e "${GREEN}[2/5] 复制 AGENTS.md...${NC}"
    if [ -f "$MACHINE_DIR/AGENTS.md" ]; then
        run cp "$MACHINE_DIR/AGENTS.md" "$FULL_PATH/AGENTS.md"
    fi
fi

# ── 复制 .codex/ ─────────────────────────────────────────────
if ! $NO_CODEX; then
    echo -e "${GREEN}[3/5] 复制 .codex/ 配置...${NC}"
    if [ -d "$MACHINE_DIR/assets/config/.codex" ]; then
        run cp -r "$MACHINE_DIR/assets/config/.codex" "$FULL_PATH/.codex"
    fi
fi

# ── 复制 Skills ───────────────────────────────────────────────
echo -e "${GREEN}[4/5] 复制 Skills...${NC}"
run mkdir -p "$FULL_PATH/.skills"
IFS=',' read -ra SKILLS <<< "$SKILLS_LIST"
for skill in "${SKILLS[@]}"; do
    skill=$(echo "$skill" | xargs)  # trim whitespace
    src="$MACHINE_DIR/assets/skills/$skill"
    if [ -d "$src" ]; then
        run cp -r "$src" "$FULL_PATH/.skills/$skill"
        echo -e "  ${GREEN}✓${NC} $skill"
    else
        echo -e "  ${YELLOW}⚠${NC} 技能不存在: $skill（跳过）"
    fi
done

# ── 生成 copilot-instructions.md ─────────────────────────────
echo -e "${GREEN}[5/5] 生成 .github/copilot-instructions.md...${NC}"
if ! $DRY_RUN; then
    mkdir -p "$FULL_PATH/.github"
    cat > "$FULL_PATH/.github/copilot-instructions.md" << 'HEADER'
# Copilot Instructions

本文件由 vibe-init 自动生成。Skills 来自母机 vibe-coding-cn。

## 通用规则

- 先读 .skills/ 下的 SKILL.md 再动手
- 遵循 AGENTS.md 中的行为准则
- 文档先行，接口先行，实现后补
- Debug 只给：预期 vs 实际 + 最小复现

## 已加载 Skills

HEADER
    for skill in "${SKILLS[@]}"; do
        skill=$(echo "$skill" | xargs)
        if [ -d "$FULL_PATH/.skills/$skill" ]; then
            echo "### $skill" >> "$FULL_PATH/.github/copilot-instructions.md"
            echo "" >> "$FULL_PATH/.github/copilot-instructions.md"
            # 提取 SKILL.md 的 description 和 Quick Reference
            if [ -f "$FULL_PATH/.skills/$skill/SKILL.md" ]; then
                head -5 "$FULL_PATH/.skills/$skill/SKILL.md" >> "$FULL_PATH/.github/copilot-instructions.md"
                echo "" >> "$FULL_PATH/.github/copilot-instructions.md"
            fi
            echo "详细文档: .skills/$skill/SKILL.md" >> "$FULL_PATH/.github/copilot-instructions.md"
            echo "" >> "$FULL_PATH/.github/copilot-instructions.md"
        fi
    done
    echo -e "  ${GREEN}✓${NC} .github/copilot-instructions.md"
fi

# ── 复制工作流（可选）────────────────────────────────────────
if $WITH_WORKFLOW; then
    echo -e "${GREEN}[额外] 复制 auto-dev-loop 工作流...${NC}"
    if [ -d "$MACHINE_DIR/assets/workflow/auto-dev-loop" ]; then
        run cp -r "$MACHINE_DIR/assets/workflow/auto-dev-loop" "$FULL_PATH/.workflow/auto-dev-loop"
        echo -e "  ${GREEN}✓${NC} auto-dev-loop"
    fi
fi

# ── 初始化 Git ────────────────────────────────────────────────
if ! $DRY_RUN; then
    if [ ! -d "$FULL_PATH/.git" ]; then
        (cd "$FULL_PATH" && git init -q && git add -A && git commit -q -m "init: vibe-init from mother machine")
        echo -e "  ${GREEN}✓${NC} Git 仓库已初始化"
    fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 项目初始化完成！${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}进入项目:${NC}  cd $FULL_PATH"
echo -e "  ${YELLOW}开始开发:${NC}  codex \"你的需求描述\""
echo -e "  ${YELLOW}或用 Copilot:${NC} 直接在 VS Code 中写代码"
echo ""
