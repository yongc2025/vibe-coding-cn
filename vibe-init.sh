#!/bin/bash
# ============================================================
# vibe-init.sh — 从母机初始化新项目
# 用法: ./vibe-init.sh --ai <助手> --type <类型> [--name <项目名>] [--skills <额外技能>]
# ============================================================

set -e

# ── 颜色 ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ── 母机远程地址 ──────────────────────────────────────────────
VIBE_REMOTE_URL="https://github.com/yongc2025/vibe-coding-cn.git"

# ── 网络诊断结果（全局） ──────────────────────────────────────
# ok = 成功 | network = 网络不通 | auth = 认证/权限问题 | unknown = 其他
VIBE_CLONE_DIAGNOSIS=""

# ── 帮助 ──────────────────────────────────────────────────────
usage() {
    cat <<EOF
${BLUE}vibe-init.sh${NC} — 从母机初始化新项目

${YELLOW}用法:${NC}
  ./vibe-init.sh --ai <助手> --type <类型> [选项]

${YELLOW}AI 助手 (--ai):${NC}
  claude        生成 CLAUDE.md（Claude Code）
  cursor        生成 .cursorrules（Cursor）
  copilot       生成 .github/copilot-instructions.md（GitHub Copilot）
  windsurf      生成 .windsurfrules（Windsurf）
  cline         生成 .clinerules（Cline）
  codex         生成 AGENTS.md（OpenAI Codex）
  all           生成以上所有文件（默认）

${YELLOW}项目类型 (--type):${NC}
  quant-crypto    加密货币量化（ccxt + cryptofeed + hummingbot + timescaledb）
  quant-astock    A股量化（tushare + akshare + timescaledb）
  quant-usstock   美股量化（alpaca + polygon + timescaledb）
  app             APP/小程序（canvas-dev + ddd-doc-steward）
  enterprise      企业级应用（canvas-dev + ddd-doc-steward + sop-generator）
  saas            互联网SaaS（canvas-dev + ddd-doc-steward + sop-generator）
  custom          自定义（需手动指定 --skills）

${YELLOW}选项:${NC}
  --type <类型>       项目类型（必填）
  --ai <助手>         AI 助手类型（默认: all）
  --name <名称>       项目目录名（默认: my-<类型>-project）
  --dir <路径>        项目创建目录（默认: 当前目录）
  --skills <技能列表>  额外技能，逗号分隔
  --with-workflow     同时复制 auto-dev-loop 工作流
  --no-codex          不复制 .codex/ 配置
  --no-agents         不复制 AGENTS.md
  --dry-run           只显示会做什么，不实际执行
  --help              显示此帮助

${YELLOW}示例:${NC}
  ./vibe-init.sh --ai claude --type quant-crypto --name my-bot
  ./vibe-init.sh --ai cursor --type app --name my-app --skills twscrape,telegram-dev
  ./vibe-init.sh --ai all --type custom --skills ccxt,postgresql,canvas-dev
  ./vibe-init.sh --type quant-crypto --name my-bot --dry-run
EOF
    exit 0
}

# ── 网络连通性检测 ────────────────────────────────────────────
# 检测是否能访问 GitHub，结果写入全局变量 VIBE_CLONE_DIAGNOSIS
check_github_connectivity() {
    local err_output="$1"

    # 1. 快速检测：能否解析 GitHub 域名
    if ! host github.com >/dev/null 2>&1 && ! nslookup github.com >/dev/null 2>&1; then
        VIBE_CLONE_DIAGNOSIS="network"
        return
    fi

    # 2. 快速检测：能否建立 HTTPS 连接
    if ! curl -sI --connect-timeout 5 --max-time 10 https://github.com >/dev/null 2>&1; then
        VIBE_CLONE_DIAGNOSIS="network"
        return
    fi

    # 3. 从 git clone 错误输出判断
    if echo "$err_output" | grep -qiE "timeout|timed out|couldn't connect|couldn't resolve|network|connection refused|Connection reset|proxy|SSL|certificate"; then
        VIBE_CLONE_DIAGNOSIS="network"
        return
    fi

    # 4. 认证/权限问题
    if echo "$err_output" | grep -qiE "authentication|permission|403|401|fatal: unable to access"; then
        VIBE_CLONE_DIAGNOSIS="auth"
        return
    fi

    # 5. 其他
    VIBE_CLONE_DIAGNOSIS="unknown"
}

# ── 打印网络问题指引 ──────────────────────────────────────────
print_network_help() {
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ❌ 网络无法访问 GitHub${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  脚本需要从 GitHub 下载母机资源，但当前网络不通。"
    echo ""
    echo -e "${YELLOW}  解决方案（任选其一）：${NC}"
    echo ""
    echo -e "  ${GREEN}方案 1：设置代理后重试${NC}"
    echo -e "    export https_proxy=http://127.0.0.1:7890"
    echo -e "    export http_proxy=http://127.0.0.1:7890"
    echo -e "    bash vibe-init.sh --ai copilot --type quant-crypto --name my-bot"
    echo ""
    echo -e "  ${GREEN}方案 2：手动克隆母机到本地${NC}"
    echo -e "    # 先用代理或其他方式把母机 clone 下来"
    echo -e "    git clone --depth 1 $VIBE_REMOTE_URL ~/vibe-coding-cn"
    echo -e "    # 然后再运行脚本（会自动检测到本地母机）"
    echo -e "    bash vibe-init.sh --ai copilot --type quant-crypto --name my-bot"
    echo ""
    echo -e "  ${GREEN}方案 3：用 GitHub 镜像${NC}"
    echo -e "    git clone --depth 1 https://ghproxy.com/$VIBE_REMOTE_URL ~/vibe-coding-cn"
    echo -e "    bash vibe-init.sh --ai copilot --type quant-crypto --name my-bot"
    echo ""
    echo -e "  ${GREEN}方案 4：设置环境变量指向已有母机${NC}"
    echo -e "    export VIBE_MACHINE_DIR=/path/to/vibe-coding-cn"
    echo -e "    bash vibe-init.sh --ai copilot --type quant-crypto --name my-bot"
    echo ""
}

# ── 母机目录检测 ──────────────────────────────────────────────
# 优先级: VIBE_MACHINE_DIR 环境变量 > 脚本所在目录 > 默认路径 > 远程下载
detect_machine_dir() {
    # 1. 用户显式设置的环境变量
    if [ -n "$VIBE_MACHINE_DIR" ] && [ -d "$VIBE_MACHINE_DIR/assets/skills" ]; then
        echo "$VIBE_MACHINE_DIR"
        return
    fi
    # 2. 脚本所在目录（用户在母机目录内运行脚本）
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$script_dir/assets/skills" ]; then
        echo "$script_dir"
        return
    fi
    # 3. 默认路径
    local default_dir="$HOME/vibe-coding-cn"
    if [ -d "$default_dir/assets/skills" ]; then
        echo "$default_dir"
        return
    fi
    # 4. workspace 路径
    local ws_dir="$HOME/.openclaw/workspace/vibe-coding-cn"
    if [ -d "$ws_dir/assets/skills" ]; then
        echo "$ws_dir"
        return
    fi

    # 5. 本地找不到，从远程下载（sparse checkout，只拉需要的目录）
    echo -e "${YELLOW}本地未找到母机，正在从 GitHub 下载...${NC}" >&2
    local temp_dir
    temp_dir=$(mktemp -d)
    local clone_err
    clone_err=$(mktemp)

    if git clone --depth 1 --filter=blob:none --sparse \
        "$VIBE_REMOTE_URL" "$temp_dir/vibe-coding-cn" 2>"$clone_err"; then
        (cd "$temp_dir/vibe-coding-cn" && \
         git sparse-checkout set assets/skills assets/config assets/workflow 2>/dev/null) || true
        # 验证下载成功
        if [ -d "$temp_dir/vibe-coding-cn/assets/skills" ]; then
            echo -e "${GREEN}✓ 母机已下载到: $temp_dir/vibe-coding-cn${NC}" >&2
            rm -f "$clone_err"
            echo "$temp_dir/vibe-coding-cn"
            return
        fi
    fi

    # clone 失败，诊断原因
    check_github_connectivity "$(cat "$clone_err" 2>/dev/null)"
    rm -f "$clone_err"

    # 全部失败
    echo ""
}

# ── 技能映射 ──────────────────────────────────────────────────
declare -A TYPE_SKILLS
TYPE_SKILLS[quant-crypto]="ccxt,cryptofeed,hummingbot,coingecko,polymarket,postgresql,timescaledb,proxychains"
TYPE_SKILLS[quant-astock]="postgresql,timescaledb"
TYPE_SKILLS[quant-usstock]="postgresql,timescaledb,twscrape,proxychains"
TYPE_SKILLS[app]="canvas-dev,ddd-doc-steward,snapdom"
TYPE_SKILLS[enterprise]="canvas-dev,ddd-doc-steward,sop-generator,postgresql,claude-cookbooks"
TYPE_SKILLS[saas]="canvas-dev,ddd-doc-steward,sop-generator,postgresql,telegram-dev,snapdom"

# 所有类型共用的基础技能
BASE_SKILLS="skills-skills,sop-generator,canvas-dev,headless-cli"

# ── AI 助手入口文件生成 ───────────────────────────────────────
# 生成通用的入口文件内容（被各 AI 工具读取）
generate_ai_entry_content() {
    local skill_list="$1"
    local ai_name="$2"
    cat <<EOF
# ${ai_name} — vibe-coding-cn 孵化项目

> 本文件由 vibe-init.sh 自动生成。
> Skills 来自母机 vibe-coding-cn，位于 .skills/ 目录。

---

## 通用规则

1. **先读 Skills 再动手** — 每个 SKILL.md 包含该领域的完整知识
2. **文档先行，接口先行，实现后补** — 先定义输入输出
3. **一次只改一个模块** — 保持专注
4. **Debug 只给**：预期 vs 实际 + 最小复现

## 开发顺序

\`\`\`
接口定义 → 配置管理 → 核心实现 → 数据集成 → 测试验证
\`\`\`

## 已加载 Skills

EOF
    # 遍历 skills 列表，提取 description
    IFS=',' read -ra skills_arr <<< "$skill_list"
    for skill in "${skills_arr[@]}"; do
        skill=$(echo "$skill" | xargs)
        local skill_file=".skills/$skill/SKILL.md"
        if [ -f "$skill_file" ]; then
            echo "### $skill" >> /dev/stdout
            echo "" >> /dev/stdout
            # 提取 frontmatter 中的 description
            local desc
            desc=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "description:" | head -1 | sed 's/^description: *//' | sed 's/^"//' | sed 's/"$//')
            if [ -n "$desc" ]; then
                echo "$desc" >> /dev/stdout
            fi
            echo "" >> /dev/stdout
            echo "📖 详细文档: .skills/$skill/SKILL.md" >> /dev/stdout
            echo "" >> /dev/stdout
        fi
    done
}

# 生成 CLAUDE.md（Claude Code 专用）
generate_claude_md() {
    local full_path="$1"
    local skill_list="$2"
    local machine_dir="$3"
    cat > "$full_path/CLAUDE.md" << 'EOF'
# CLAUDE.md — vibe-coding-cn 孵化项目

> 本文件由 vibe-init.sh 自动生成，供 Claude Code 读取。

---

## 通用规则

1. **先读 .skills/ 下的 SKILL.md 再动手** — 每个文件包含该领域的完整知识
2. **文档先行，接口先行，实现后补** — 先定义输入输出再写实现
3. **一次只改一个模块** — 保持专注，不要顺手重构
4. **Debug 只给**：预期 vs 实际 + 最小复现

## 开发顺序

```
接口定义 → 配置管理 → 核心实现 → 数据集成 → 测试验证
```

## 参考技能

EOF
    # 添加 skills 引用
    IFS=',' read -ra skills_arr <<< "$skill_list"
    for skill in "${skills_arr[@]}"; do
        skill=$(echo "$skill" | xargs)
        if [ -d "$full_path/.skills/$skill" ]; then
            echo "@.skills/$skill/SKILL.md" >> "$full_path/CLAUDE.md"
        fi
    done

    cat >> "$full_path/CLAUDE.md" << 'EOF'

## 项目定义

创建项目后，请填写 `docs/PROJECT_BRIEF.md`：

1. **目标**：我要解决什么问题？
2. **现状**：当前是什么情况？
3. **差距**：从现状到目标，缺什么？
4. **判断标准**：怎么知道做完了？
EOF
    echo -e "  ${GREEN}✓${NC} CLAUDE.md"
}

# 生成 .cursorrules（Cursor 专用）
generate_cursorrules() {
    local full_path="$1"
    local skill_list="$2"
    cat > "$full_path/.cursorrules" << 'EOF'
# Cursor Rules — vibe-coding-cn 孵化项目

> 本文件由 vibe-init.sh 自动生成，供 Cursor 读取。

---

## 通用规则

1. 先读 .skills/ 下的 SKILL.md 再动手
2. 文档先行，接口先行，实现后补
3. 一次只改一个模块
4. Debug 只给：预期 vs 实际 + 最小复现

## 开发顺序

```
接口定义 → 配置管理 → 核心实现 → 数据集成 → 测试验证
```

## 已加载 Skills

EOF
    IFS=',' read -ra skills_arr <<< "$skill_list"
    for skill in "${skills_arr[@]}"; do
        skill=$(echo "$skill" | xargs)
        if [ -d "$full_path/.skills/$skill" ]; then
            local desc
            desc=$(sed -n '/^---$/,/^---$/p' "$full_path/.skills/$skill/SKILL.md" 2>/dev/null | grep "description:" | head -1 | sed 's/^description: *//' | sed 's/^"//' | sed 's/"$//')
            echo "- **$skill**: $desc" >> "$full_path/.cursorrules"
        fi
    done
    echo -e "  ${GREEN}✓${NC} .cursorrules"
}

# 生成 .github/copilot-instructions.md（Copilot 专用）
generate_copilot_instructions() {
    local full_path="$1"
    local skill_list="$2"
    mkdir -p "$full_path/.github"
    cat > "$full_path/.github/copilot-instructions.md" << 'EOF'
# Copilot Instructions — vibe-coding-cn 孵化项目

> 本文件由 vibe-init.sh 自动生成，供 GitHub Copilot 读取。

---

## 通用规则

1. 先读 .skills/ 下的 SKILL.md 再动手
2. 文档先行，接口先行，实现后补
3. 一次只改一个模块
4. Debug 只给：预期 vs 实际 + 最小复现

## 开发顺序

```
接口定义 → 配置管理 → 核心实现 → 数据集成 → 测试验证
```

## 已加载 Skills

EOF
    IFS=',' read -ra skills_arr <<< "$skill_list"
    for skill in "${skills_arr[@]}"; do
        skill=$(echo "$skill" | xargs)
        if [ -d "$full_path/.skills/$skill" ]; then
            local desc
            desc=$(sed -n '/^---$/,/^---$/p' "$full_path/.skills/$skill/SKILL.md" 2>/dev/null | grep "description:" | head -1 | sed 's/^description: *//' | sed 's/^"//' | sed 's/"$//')
            echo "- **$skill**: $desc" >> "$full_path/.github/copilot-instructions.md"
        fi
    done
    echo -e "  ${GREEN}✓${NC} .github/copilot-instructions.md"
}

# 生成 .windsurfrules（Windsurf 专用）
generate_windsurfrules() {
    local full_path="$1"
    local skill_list="$2"
    cat > "$full_path/.windsurfrules" << 'EOF'
# Windsurf Rules — vibe-coding-cn 孵化项目

> 本文件由 vibe-init.sh 自动生成，供 Windsurf 读取。

---

## 通用规则

1. 先读 .skills/ 下的 SKILL.md 再动手
2. 文档先行，接口先行，实现后补
3. 一次只改一个模块

## 已加载 Skills

EOF
    IFS=',' read -ra skills_arr <<< "$skill_list"
    for skill in "${skills_arr[@]}"; do
        skill=$(echo "$skill" | xargs)
        if [ -d "$full_path/.skills/$skill" ]; then
            local desc
            desc=$(sed -n '/^---$/,/^---$/p' "$full_path/.skills/$skill/SKILL.md" 2>/dev/null | grep "description:" | head -1 | sed 's/^description: *//' | sed 's/^"//' | sed 's/"$//')
            echo "- **$skill**: $desc" >> "$full_path/.windsurfrules"
        fi
    done
    echo -e "  ${GREEN}✓${NC} .windsurfrules"
}

# 生成 .clinerules（Cline 专用）
generate_clinerules() {
    local full_path="$1"
    local skill_list="$2"
    cat > "$full_path/.clinerules" << 'EOF'
# Cline Rules — vibe-coding-cn 孵化项目

> 本文件由 vibe-init.sh 自动生成，供 Cline 读取。

---

## 通用规则

1. 先读 .skills/ 下的 SKILL.md 再动手
2. 文档先行，接口先行，实现后补
3. 一次只改一个模块

## 已加载 Skills

EOF
    IFS=',' read -ra skills_arr <<< "$skill_list"
    for skill in "${skills_arr[@]}"; do
        skill=$(echo "$skill" | xargs)
        if [ -d "$full_path/.skills/$skill" ]; then
            local desc
            desc=$(sed -n '/^---$/,/^---$/p' "$full_path/.skills/$skill/SKILL.md" 2>/dev/null | grep "description:" | head -1 | sed 's/^description: *//' | sed 's/^"//' | sed 's/"$//')
            echo "- **$skill**: $desc" >> "$full_path/.clinerules"
        fi
    done
    echo -e "  ${GREEN}✓${NC} .clinerules"
}

# 生成 AGENTS.md（Codex/OpenClaw 专用）
generate_agents_md() {
    local full_path="$1"
    local skill_list="$2"
    local machine_dir="$3"
    if [ -f "$machine_dir/AGENTS.md" ]; then
        cp "$machine_dir/AGENTS.md" "$full_path/AGENTS.md"
        echo -e "  ${GREEN}✓${NC} AGENTS.md"
    fi
}

# ── 解析参数 ──────────────────────────────────────────────────
TYPE=""
AI_TYPE="all"
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
        --ai)         AI_TYPE="$2"; shift 2 ;;
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

# 验证 --ai 参数
case "$AI_TYPE" in
    claude|cursor|copilot|windsurf|cline|codex|all) ;;
    *)  echo -e "${RED}错误: 未知的 AI 助手类型: $AI_TYPE${NC}"
        echo "支持: claude, cursor, copilot, windsurf, cline, codex, all"
        exit 1 ;;
esac

# ── 检测母机 ──────────────────────────────────────────────────
MACHINE_DIR=$(detect_machine_dir)
if [ -z "$MACHINE_DIR" ]; then
    case "$VIBE_CLONE_DIAGNOSIS" in
        network)
            print_network_help
            ;;
        *)
            echo -e "${RED}错误: 无法获取母机${NC}"
            echo ""
            echo "请通过以下方式之一提供母机："
            echo "  1. 设置环境变量: export VIBE_MACHINE_DIR=/path/to/vibe-coding-cn"
            echo "  2. 在母机目录内运行此脚本"
            echo "  3. 将母机克隆到 ~/vibe-coding-cn"
            echo "  4. 确保网络可访问 GitHub"
            ;;
    esac
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
echo -e "  ${YELLOW}AI 助手:${NC}  $AI_TYPE"
echo -e "  ${YELLOW}项目:${NC}     $FULL_PATH"
echo -e "  ${YELLOW}技能:${NC}     $SKILLS_LIST"
echo -e "  ${YELLOW}工作流:${NC}   $WITH_WORKFLOW"
echo -e "  ${YELLOW}母机:${NC}     $MACHINE_DIR"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] 以下操作不会实际执行${NC}"
    echo ""
fi

# ── 辅助函数 ──────────────────────────────────────────────────
run() {
    if $DRY_RUN; then
        echo -e "  ${BLUE}[DRY]${NC} $*"
    else
        "$@"
    fi
}

# ── 步骤 1: 创建项目目录 ─────────────────────────────────────
echo -e "${GREEN}[1/6] 创建项目目录...${NC}"
run mkdir -p "$FULL_PATH"

# ── 步骤 2: 复制 .codex/ ─────────────────────────────────────
if ! $NO_CODEX; then
    echo -e "${GREEN}[2/6] 复制 .codex/ 配置...${NC}"
    if [ -d "$MACHINE_DIR/assets/config/.codex" ]; then
        run cp -r "$MACHINE_DIR/assets/config/.codex" "$FULL_PATH/.codex"
    fi
else
    echo -e "${GREEN}[2/6] 跳过 .codex/ 配置${NC}"
fi

# ── 步骤 3: 复制 Skills ─────────────────────────────────────
echo -e "${GREEN}[3/6] 复制 Skills...${NC}"
run mkdir -p "$FULL_PATH/.skills"
IFS=',' read -ra SKILLS <<< "$SKILLS_LIST"
for skill in "${SKILLS[@]}"; do
    skill=$(echo "$skill" | xargs)
    src="$MACHINE_DIR/assets/skills/$skill"
    if [ -d "$src" ]; then
        run cp -r "$src" "$FULL_PATH/.skills/$skill"
        echo -e "  ${GREEN}✓${NC} $skill"
    else
        echo -e "  ${YELLOW}⚠${NC} 技能不存在: $skill（跳过）"
    fi
done

# ── 步骤 4: 生成 AI 助手入口文件 ─────────────────────────────
echo -e "${GREEN}[4/6] 生成 AI 助手入口文件...${NC}"

if $DRY_RUN; then
    case "$AI_TYPE" in
        claude)  echo -e "  ${BLUE}[DRY]${NC} 将生成 CLAUDE.md" ;;
        cursor)  echo -e "  ${BLUE}[DRY]${NC} 将生成 .cursorrules" ;;
        copilot) echo -e "  ${BLUE}[DRY]${NC} 将生成 .github/copilot-instructions.md" ;;
        windsurf) echo -e "  ${BLUE}[DRY]${NC} 将生成 .windsurfrules" ;;
        cline)   echo -e "  ${BLUE}[DRY]${NC} 将生成 .clinerules" ;;
        codex)   echo -e "  ${BLUE}[DRY]${NC} 将生成 AGENTS.md" ;;
        all)
            echo -e "  ${BLUE}[DRY]${NC} 将生成 CLAUDE.md"
            echo -e "  ${BLUE}[DRY]${NC} 将生成 .cursorrules"
            echo -e "  ${BLUE}[DRY]${NC} 将生成 .github/copilot-instructions.md"
            echo -e "  ${BLUE}[DRY]${NC} 将生成 .windsurfrules"
            echo -e "  ${BLUE}[DRY]${NC} 将生成 .clinerules"
            echo -e "  ${BLUE}[DRY]${NC} 将生成 AGENTS.md"
            ;;
    esac
else
    case "$AI_TYPE" in
        claude)  generate_claude_md "$FULL_PATH" "$SKILLS_LIST" "$MACHINE_DIR" ;;
        cursor)  generate_cursorrules "$FULL_PATH" "$SKILLS_LIST" ;;
        copilot) generate_copilot_instructions "$FULL_PATH" "$SKILLS_LIST" ;;
        windsurf) generate_windsurfrules "$FULL_PATH" "$SKILLS_LIST" ;;
        cline)   generate_clinerules "$FULL_PATH" "$SKILLS_LIST" ;;
        codex)   generate_agents_md "$FULL_PATH" "$SKILLS_LIST" "$MACHINE_DIR" ;;
        all)
            generate_claude_md "$FULL_PATH" "$SKILLS_LIST" "$MACHINE_DIR"
            generate_cursorrules "$FULL_PATH" "$SKILLS_LIST"
            generate_copilot_instructions "$FULL_PATH" "$SKILLS_LIST"
            generate_windsurfrules "$FULL_PATH" "$SKILLS_LIST"
            generate_clinerules "$FULL_PATH" "$SKILLS_LIST"
            if ! $NO_AGENTS; then
                generate_agents_md "$FULL_PATH" "$SKILLS_LIST" "$MACHINE_DIR"
            fi
            ;;
    esac
fi

# ── 步骤 5: 复制工作流（可选）────────────────────────────────
if $WITH_WORKFLOW; then
    echo -e "${GREEN}[5/6] 复制 auto-dev-loop 工作流...${NC}"
    if [ -d "$MACHINE_DIR/assets/workflow/auto-dev-loop" ]; then
        run cp -r "$MACHINE_DIR/assets/workflow/auto-dev-loop" "$FULL_PATH/.workflow/auto-dev-loop"
        echo -e "  ${GREEN}✓${NC} auto-dev-loop"
    fi
else
    echo -e "${GREEN}[5/6] 跳过工作流${NC}"
fi

# ── 步骤 6: 初始化 Git ───────────────────────────────────────
echo -e "${GREEN}[6/6] 初始化 Git...${NC}"
if ! $DRY_RUN; then
    if [ ! -d "$FULL_PATH/.git" ]; then
        (cd "$FULL_PATH" && git init -q && git add -A && git commit -q -m "init: vibe-init from mother machine" 2>/dev/null || true)
        echo -e "  ${GREEN}✓${NC} Git 仓库已初始化"
    else
        echo -e "  ${YELLOW}⚠${NC} Git 仓库已存在（跳过）"
    fi
else
    echo -e "  ${BLUE}[DRY]${NC} git init"
fi

# ── 完成 ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 项目初始化完成！${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}进入项目:${NC}  cd $FULL_PATH"
echo ""

# 根据 AI 类型给出提示
case "$AI_TYPE" in
    claude)  echo -e "  ${YELLOW}开始开发:${NC}  在项目目录运行 claude" ;;
    cursor)  echo -e "  ${YELLOW}开始开发:${NC}  用 Cursor 打开项目目录" ;;
    copilot) echo -e "  ${YELLOW}开始开发:${NC}  用 VS Code 打开项目目录（Copilot 自动加载）" ;;
    windsurf) echo -e "  ${YELLOW}开始开发:${NC}  用 Windsurf 打开项目目录" ;;
    cline)   echo -e "  ${YELLOW}开始开发:${NC}  用 VS Code + Cline 扩展打开项目目录" ;;
    codex)   echo -e "  ${YELLOW}开始开发:${NC}  在项目目录运行 codex" ;;
    all)
        echo -e "  ${YELLOW}开始开发:${NC}"
        echo -e "    Claude:  cd $FULL_PATH && claude"
        echo -e "    Cursor:  用 Cursor 打开 $FULL_PATH"
        echo -e "    Copilot: 用 VS Code 打开 $FULL_PATH"
        echo -e "    Codex:   cd $FULL_PATH && codex"
        ;;
esac
echo ""
