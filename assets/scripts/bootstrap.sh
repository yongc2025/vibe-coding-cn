#!/usr/bin/env bash
#
# bootstrap.sh - 新项目一键拉取 vibe-coding-cn 技能母盘
#
# 用法:
#   bash bootstrap.sh [选项]
#
# 选项:
#   -s, --source <path>     母盘路径 (默认: 自动检测)
#   -p, --profile <name>    业务线 (见下方列表)
#   -a, --all               拉取全部技能
#   -w, --workflow           同时拉取 auto-dev-loop 工作流
#   -o, --output <dir>      输出目录 (默认: .vibe/)
#   -d, --dry-run           预览模式，不实际复制
#   -h, --help              帮助
#
# 可用 Profile:
#   saas            SaaS 应用 (多租户/计费/认证/事件驱动)
#   enterprise      企业级应用 (RBAC/工作流/消息队列/微服务)
#   quant-crypto    加密货币量化 (ccxt/cryptofeed/hummingbot/回测/风控)
#   quant-astock    A 股量化 (tushare-akshare/quant-factor/回测)
#   quant-us        美股量化 (alpaca-polygon/quant-factor)
#   app-mini        APP/小程序 (flutter/react-native/uniapp/wechat-mp)
#   full-stack      全栈开发 (全部技能)
#   all             全部 (全部技能 + 工作流)
#
# 示例:
#   bash bootstrap.sh -p saas                    # 拉取 SaaS 技能到 .vibe/
#   bash bootstrap.sh -p quant-crypto -w         # 拉取量化技能 + 工作流
#   bash bootstrap.sh -a -w -o .ai-skills        # 全部技能 + 工作流到 .ai-skills/
#

set -euo pipefail

# ==================== 颜色 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==================== 默认值 ====================
SOURCE_PATH=""
PROFILE=""
ALL=false
WORKFLOW=false
OUTPUT_DIR=".vibe"
DRY_RUN=false

# ==================== 母盘自动检测 ====================
detect_source() {
    # 优先级: 环境变量 > 当前目录往上找 > 常见路径
    if [[ -n "${VIBE_CODING_CN:-}" && -d "$VIBE_CODING_CN/assets/skills" ]]; then
        echo "$VIBE_CODING_CN"
        return
    fi

    # 从当前目录往上找
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/assets/skills" && -d "$dir/assets/workflow" ]]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done

    # 常见路径
    for path in \
        "$HOME/vibe-coding-cn" \
        "$HOME/projects/vibe-coding-cn" \
        "$HOME/workspace/vibe-coding-cn" \
        "$HOME/repos/vibe-coding-cn" \
        "/root/.openclaw/workspace/vibe-coding-cn" \
        "D:/workspace/vibe-coding-cn" \
        "/d/workspace/vibe-coding-cn" \
        "/mnt/d/workspace/vibe-coding-cn"; do
        if [[ -d "$path/assets/skills" ]]; then
            echo "$path"
            return
        fi
    done

    echo ""
}

# ==================== 技能分组定义 ====================
# 通用基础层（所有 profile 都包含）
SKILLS_BASE=(
    "skills-skills"
    "canvas-dev"
    "ddd-doc-steward"
    "sop-generator"
    "headless-cli"
    "tmux-autopilot"
    "postgresql"
    "claude-code-guide"
    "claude-cookbooks"
)

# 按业务线分组
declare -A SKILLS_PROFILE

SKILLS_PROFILE[saas]="
    multi-tenant
    billing-sub
    oauth-sso
    event-driven
    microservice
    message-queue
    rbac
    workflow-engine
    snapdom
"

SKILLS_PROFILE[enterprise]="
    rbac
    workflow-engine
    message-queue
    microservice
    oauth-sso
    event-driven
    snapdom
    timescaledb
"

SKILLS_PROFILE[quant-crypto]="
    ccxt
    cryptofeed
    hummingbot
    coingecko
    polymarket
    backtesting
    risk-management
    timescaledb
    proxychains
    twscrape
"

SKILLS_PROFILE[quant-astock]="
    tushare-akshare
    quant-factor
    backtesting
    risk-management
    timescaledb
"

SKILLS_PROFILE[quant-us]="
    alpaca-polygon
    quant-factor
    backtesting
    risk-management
    timescaledb
    proxychains
    twscrape
"

SKILLS_PROFILE[app-mini]="
    flutter
    react-native
    uniapp
    wechat-mp
    snapdom
"

SKILLS_PROFILE[full-stack]="
    multi-tenant
    billing-sub
    oauth-sso
    event-driven
    microservice
    message-queue
    rbac
    workflow-engine
    ccxt
    cryptofeed
    hummingbot
    coingecko
    polymarket
    backtesting
    risk-management
    tushare-akshare
    quant-factor
    alpaca-polygon
    flutter
    react-native
    uniapp
    wechat-mp
    snapdom
    timescaledb
    proxychains
    twscrape
    telegram-dev
    markdown-to-epub
"

# ==================== 工具函数 ====================
log_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[→]${NC} $*"; }

usage() {
    sed -n '/^# 用法/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# ==================== 参数解析 ====================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)  SOURCE_PATH="$2"; shift 2 ;;
            -p|--profile) PROFILE="$2"; shift 2 ;;
            -a|--all)     ALL=true; shift ;;
            -w|--workflow) WORKFLOW=true; shift ;;
            -o|--output)  OUTPUT_DIR="$2"; shift 2 ;;
            -d|--dry-run) DRY_RUN=true; shift ;;
            -h|--help)    usage ;;
            *)            log_error "未知参数: $1"; usage ;;
        esac
    done
}

# ==================== 核心逻辑 ====================
collect_skills() {
    local skills=()

    # 通用基础
    skills+=("${SKILLS_BASE[@]}")

    if $ALL; then
        # 全量：遍历所有技能目录
        for dir in "$SOURCE_PATH/assets/skills"/*/; do
            local name=$(basename "$dir")
            [[ "$name" == "workflow" ]] && continue
            [[ -f "$dir/SKILL.md" ]] && skills+=("$name")
        done
    elif [[ -n "$PROFILE" ]]; then
        if [[ -z "${SKILLS_PROFILE[$PROFILE]+x}" ]]; then
            log_error "未知 profile: $PROFILE"
            echo "可用: ${!SKILLS_PROFILE[*]}"
            exit 1
        fi
        # 读取 profile 对应的技能列表
        while IFS= read -r skill; do
            skill=$(echo "$skill" | xargs)  # trim
            [[ -n "$skill" ]] && skills+=("$skill")
        done <<< "${SKILLS_PROFILE[$PROFILE]}"
    fi

    # 去重
    printf '%s\n' "${skills[@]}" | sort -u
}

copy_skill() {
    local skill_name="$1"
    local src_dir="$SOURCE_PATH/assets/skills/$skill_name"
    local dst_dir="$OUTPUT_DIR/skills/$skill_name"

    if [[ ! -d "$src_dir" ]]; then
        log_warn "跳过 $skill_name (源目录不存在)"
        return 1
    fi

    if [[ ! -f "$src_dir/SKILL.md" ]]; then
        log_warn "跳过 $skill_name (无 SKILL.md)"
        return 1
    fi

    if $DRY_RUN; then
        log_info "[DRY] $skill_name"
        return 0
    fi

    mkdir -p "$dst_dir"
    cp "$src_dir/SKILL.md" "$dst_dir/SKILL.md"

    # 如果有 references/ 目录，也一起复制
    if [[ -d "$src_dir/references" ]]; then
        cp -r "$src_dir/references" "$dst_dir/"
    fi

    # 如果有 assets/ 目录，也一起复制
    if [[ -d "$src_dir/assets" ]]; then
        cp -r "$src_dir/assets" "$dst_dir/"
    fi

    log_info "$skill_name"
    return 0
}

copy_workflow() {
    local src="$SOURCE_PATH/assets/workflow/auto-dev-loop"
    local dst="$OUTPUT_DIR/workflow/auto-dev-loop"

    if [[ ! -d "$src" ]]; then
        log_warn "工作流目录不存在: $src"
        return 1
    fi

    if $DRY_RUN; then
        log_info "[DRY] auto-dev-loop workflow"
        return 0
    fi

    mkdir -p "$dst"
    cp -r "$src"/* "$dst/"
    log_info "auto-dev-loop workflow"
}

generate_index() {
    local index_file="$OUTPUT_DIR/INDEX.md"

    if $DRY_RUN; then
        return 0
    fi

    cat > "$index_file" << 'HEADER'
# 🎯 项目技能索引

> 由 bootstrap.sh 自动生成，请勿手动编辑

## 已安装技能

| 技能 | 说明 | 来源 |
|------|------|------|
HEADER

    for skill_dir in "$OUTPUT_DIR/skills"/*/; do
        [[ ! -f "$skill_dir/SKILL.md" ]] && continue
        local name=$(basename "$skill_dir")

        # 从 YAML frontmatter 提取 description
        local desc=$(sed -n '/^---$/,/^---$/p' "$skill_dir/SKILL.md" | grep "^description:" | sed 's/^description: *//')
        [[ -z "$desc" ]] && desc="-"

        echo "| [$name](skills/$name/SKILL.md) | $desc | vibe-coding-cn |" >> "$index_file"
    done

    cat >> "$index_file" << 'FOOTER'

## 使用方式

### VS Code + Copilot
1. 打开技能文件作为上下文参考
2. 在 Copilot Chat 中引用: `@workspace #file:skills/multi-tenant/SKILL.md`

### Claude Code / Codex
在项目根目录的 `.cursorrules` 或 `AGENTS.md` 中引用技能路径。

### OpenClaw
将 `.vibe/skills/` 注册为技能目录。
FOOTER

    log_info "索引文件: $index_file"
}

# ==================== 主流程 ====================
main() {
    parse_args "$@"

    # 检测母盘路径
    if [[ -z "$SOURCE_PATH" ]]; then
        SOURCE_PATH=$(detect_source)
    fi

    if [[ -z "$SOURCE_PATH" || ! -d "$SOURCE_PATH/assets/skills" ]]; then
        log_error "找不到母盘目录，请用 -s 指定路径"
        echo "  bash bootstrap.sh -s /path/to/vibe-coding-cn -p saas"
        exit 1
    fi

    # 校验 profile 或 all 至少选一个
    if [[ -z "$PROFILE" ]] && ! $ALL; then
        echo -e "${YELLOW}未指定 profile，进入交互式选型...${NC}"
        echo ""
        echo -e "${BLUE}━━━ 选型问答 ━━━${NC}"
        echo ""

        echo -e "  ${YELLOW}Q1:${NC} 你的项目要接交易所 API 做自动交易吗？"
        echo "      1) 不是"
        echo "      2) 是，加密货币（币安/OKX/Bybit）"
        echo "      3) 是，A 股（tushare/akshare）"
        echo "      4) 是，美股（Alpaca/Polygon）"
        read -p "  请选择 [1-4]: " q1

        case "$q1" in
            2) PROFILE="quant-crypto" ;;
            3) PROFILE="quant-astock" ;;
            4) PROFILE="quant-us" ;;
            *)
                echo ""
                echo -e "  ${YELLOW}Q2:${NC} 你的项目是手机 APP 或微信小程序吗？"
                echo "      1) 不是"
                echo "      2) 是"
                read -p "  请选择 [1-2]: " q2

                if [[ "$q2" == "2" ]]; then
                    PROFILE="app-mini"
                else
                    echo ""
                    echo -e "  ${YELLOW}Q3:${NC} 你的项目有「多租户」概念吗？（不同客户/公司共用一套系统）"
                    echo "      1) 没有"
                    echo "      2) 有"
                    read -p "  请选择 [1-2]: " q3

                    if [[ "$q3" == "2" ]]; then
                        PROFILE="saas"
                    else
                        echo ""
                        echo -e "  ${YELLOW}Q4:${NC} 你的项目是企业内部系统吗？（ERP/OA/CRM/审批流）"
                        echo "      1) 不是"
                        echo "      2) 是"
                        read -p "  请选择 [1-2]: " q4

                        if [[ "$q4" == "2" ]]; then
                            PROFILE="enterprise"
                        else
                            PROFILE="full-stack"
                        fi
                    fi
                fi
                ;;
        esac

        echo ""
        echo -e "  ${GREEN}→ 已选择: $PROFILE${NC}"
    fi

    # all profile 同时开启全量和工作流
    if [[ "$PROFILE" == "all" ]]; then
        ALL=true
        WORKFLOW=true
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  vibe-coding-cn 项目技能拉取${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  母盘路径:  ${GREEN}$SOURCE_PATH${NC}"
    echo -e "  输出目录:  ${GREEN}$OUTPUT_DIR${NC}"
    echo -e "  业务线:    ${GREEN}${PROFILE:-all}${NC}"
    echo -e "  拉工作流:  ${GREEN}$WORKFLOW${NC}"
    echo ""

    # 收集技能列表
    local skills
    skills=$(collect_skills)
    local count=$(echo "$skills" | wc -l | xargs)

    echo -e "  待拉取:    ${GREEN}${count}${NC} 个技能"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 创建目录
    if ! $DRY_RUN; then
        mkdir -p "$OUTPUT_DIR/skills"
    fi

    # 复制技能
    local success=0
    local failed=0
    while IFS= read -r skill; do
        [[ -z "$skill" ]] && continue
        if copy_skill "$skill"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
    done <<< "$skills"

    # 复制工作流
    if $WORKFLOW; then
        copy_workflow
    fi

    # 生成索引
    generate_index

    # 汇总
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}完成!${NC} 成功: $success  跳过: $failed"
    echo -e "  输出: ${GREEN}$OUTPUT_DIR/${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main "$@"
