#
# bootstrap.ps1 — 新项目一键拉取 vibe-coding-cn 技能母盘 (Windows PowerShell)
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File bootstrap.ps1 [选项]
#
# 选项:
#   -Source <path>     母盘路径 (默认: 自动检测)
#   -Profile <name>    业务线 (见下方列表)
#   -All               拉取全部技能
#   -Workflow          同时拉取 auto-dev-loop 工作流
#   -Output <dir>      输出目录 (默认: .vibe)
#   -DryRun            预览模式，不实际复制
#
# 可用 Profile:
#   saas            SaaS 应用
#   enterprise      企业级应用
#   quant-crypto    加密货币量化
#   quant-astock    A 股量化
#   quant-us        美股量化
#   app-mini        APP/小程序
#   full-stack      全栈开发
#   all             全部技能 + 工作流
#
# 示例:
#   powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -Profile saas
#   powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -Profile quant-crypto -Workflow
#   powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -All -Workflow -Output .ai-skills
#

param(
    [string]$Source = "",
    [string]$Profile = "",
    [switch]$All,
    [switch]$Workflow,
    [string]$Output = ".vibe",
    [switch]$DryRun
)

# ==================== 颜色 ====================
function Write-Info    { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red }
function Write-Step    { param($msg) Write-Host "[→] $msg" -ForegroundColor Cyan }

# ==================== 母盘自动检测 ====================
function Detect-Source {
    # 环境变量
    if ($env:VIBE_CODING_CN -and (Test-Path "$env:VIBE_CODING_CN\assets\skills")) {
        return $env:VIBE_CODING_CN
    }

    # 常见 Windows 路径
    $candidates = @(
        "D:\workspace\vibe-coding-cn",
        "D:\vibe-coding-cn",
        "C:\Users\$env:USERNAME\vibe-coding-cn",
        "C:\Users\$env:USERNAME\workspace\vibe-coding-cn",
        "C:\Users\$env:USERNAME\projects\vibe-coding-cn",
        "$env:USERPROFILE\vibe-coding-cn",
        "$env:USERPROFILE\workspace\vibe-coding-cn",
        "$env:USERPROFILE\projects\vibe-coding-cn"
    )

    foreach ($path in $candidates) {
        if (Test-Path "$path\assets\skills") {
            return $path
        }
    }

    # 从当前目录往上找
    $dir = Get-Location
    while ($dir) {
        if ((Test-Path "$dir\assets\skills") -and (Test-Path "$dir\assets\workflow")) {
            return $dir.Path
        }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    return ""
}

# ==================== 技能分组定义 ====================

# 通用基础层
$SkillsBase = @(
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
$SkillsProfile = @{
    "saas" = @(
        "multi-tenant"
        "billing-sub"
        "oauth-sso"
        "event-driven"
        "microservice"
        "message-queue"
        "rbac"
        "workflow-engine"
        "snapdom"
    )
    "enterprise" = @(
        "rbac"
        "workflow-engine"
        "message-queue"
        "microservice"
        "oauth-sso"
        "event-driven"
        "snapdom"
        "timescaledb"
    )
    "quant-crypto" = @(
        "ccxt"
        "cryptofeed"
        "hummingbot"
        "coingecko"
        "polymarket"
        "backtesting"
        "risk-management"
        "timescaledb"
        "proxychains"
        "twscrape"
    )
    "quant-astock" = @(
        "tushare-akshare"
        "quant-factor"
        "backtesting"
        "risk-management"
        "timescaledb"
    )
    "quant-us" = @(
        "alpaca-polygon"
        "quant-factor"
        "backtesting"
        "risk-management"
        "timescaledb"
        "proxychains"
        "twscrape"
    )
    "app-mini" = @(
        "flutter"
        "react-native"
        "uniapp"
        "wechat-mp"
        "snapdom"
    )
    "full-stack" = @(
        "multi-tenant"
        "billing-sub"
        "oauth-sso"
        "event-driven"
        "microservice"
        "message-queue"
        "rbac"
        "workflow-engine"
        "ccxt"
        "cryptofeed"
        "hummingbot"
        "coingecko"
        "polymarket"
        "backtesting"
        "risk-management"
        "tushare-akshare"
        "quant-factor"
        "alpaca-polygon"
        "flutter"
        "react-native"
        "uniapp"
        "wechat-mp"
        "snapdom"
        "timescaledb"
        "proxychains"
        "twscrape"
        "telegram-dev"
        "markdown-to-epub"
    )
}

# ==================== 收集技能列表 ====================
function Collect-Skills {
    $skills = [System.Collections.ArrayList]::new()

    # 通用基础
    foreach ($s in $SkillsBase) { [void]$skills.Add($s) }

    if ($All) {
        # 全量：遍历所有技能目录
        $skillsDir = Join-Path $Source "assets\skills"
        foreach ($dir in Get-ChildItem -Path $skillsDir -Directory) {
            if ($dir.Name -eq "workflow") { continue }
            if (Test-Path (Join-Path $dir.FullName "SKILL.md")) {
                [void]$skills.Add($dir.Name)
            }
        }
    }
    elseif ($Profile -ne "") {
        if (-not $SkillsProfile.ContainsKey($Profile)) {
            Write-Err "未知 profile: $Profile"
            Write-Host "可用: $($SkillsProfile.Keys -join ', ')"
            exit 1
        }
        foreach ($s in $SkillsProfile[$Profile]) {
            [void]$skills.Add($s)
        }
    }

    # 去重
    return $skills | Sort-Object -Unique
}

# ==================== 复制技能 ====================
function Copy-Skill {
    param($SkillName)

    $srcDir = Join-Path $Source "assets\skills\$SkillName"
    $dstDir = Join-Path $Output "skills\$SkillName"

    if (-not (Test-Path $srcDir)) {
        Write-Warn "跳过 $SkillName (源目录不存在)"
        return $false
    }

    if (-not (Test-Path "$srcDir\SKILL.md")) {
        Write-Warn "跳过 $SkillName (无 SKILL.md)"
        return $false
    }

    if ($DryRun) {
        Write-Info "[DRY] $SkillName"
        return $true
    }

    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    Copy-Item "$srcDir\SKILL.md" "$dstDir\SKILL.md" -Force

    # 复制 references/
    if (Test-Path "$srcDir\references") {
        Copy-Item "$srcDir\references" "$dstDir\references" -Recurse -Force
    }

    # 复制 assets/
    if (Test-Path "$srcDir\assets") {
        Copy-Item "$srcDir\assets" "$dstDir\assets" -Recurse -Force
    }

    Write-Info $SkillName
    return $true
}

# ==================== 复制工作流 ====================
function Copy-Workflow {
    $src = Join-Path $Source "assets\workflow\auto-dev-loop"
    $dst = Join-Path $Output "workflow\auto-dev-loop"

    if (-not (Test-Path $src)) {
        Write-Warn "工作流目录不存在: $src"
        return
    }

    if ($DryRun) {
        Write-Info "[DRY] auto-dev-loop workflow"
        return
    }

    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    Copy-Item "$src\*" $dst -Recurse -Force
    Write-Info "auto-dev-loop workflow"
}

# ==================== 生成索引 ====================
function Generate-Index {
    $indexFile = Join-Path $Output "INDEX.md"

    if ($DryRun) { return }

    $content = @"
# 🎯 项目技能索引

> 由 bootstrap.ps1 自动生成，请勿手动编辑

## 已安装技能

| 技能 | 说明 | 来源 |
|------|------|------|
"@

    $skillsDir = Join-Path $Output "skills"
    foreach ($dir in Get-ChildItem -Path $skillsDir -Directory) {
        $skillMd = Join-Path $dir.FullName "SKILL.md"
        if (-not (Test-Path $skillMd)) { continue }

        $name = $dir.Name
        $desc = "-"
        $lines = Get-Content $skillMd -Encoding UTF8
        $inFrontmatter = $false
        foreach ($line in $lines) {
            if ($line -eq "---") {
                if ($inFrontmatter) { break }
                $inFrontmatter = $true
                continue
            }
            if ($inFrontmatter -and $line -match "^description:\s*(.+)") {
                $desc = $Matches[1].Trim('" ')
                break
            }
        }

        $content += "`n| [$name](skills/$name/SKILL.md) | $desc | vibe-coding-cn |"
    }

    $content += @"


## 使用方式

### VS Code + Copilot
1. 打开技能文件作为上下文参考
2. 在 Copilot Chat 中引用: ``@workspace #file:skills/multi-tenant/SKILL.md``

### Claude Code / Codex
在项目根目录的 ``.cursorrules`` 或 ``AGENTS.md`` 中引用技能路径。

### OpenClaw
将 ``.vibe/skills/`` 注册为技能目录。
"@

    Set-Content -Path $indexFile -Value $content -Encoding UTF8
    Write-Info "索引文件: $indexFile"
}

# ==================== 主流程 ====================

# 检测母盘路径
if ($Source -eq "") {
    $Source = Detect-Source
}

if ($Source -eq "" -or -not (Test-Path "$Source\assets\skills")) {
    Write-Err "找不到母盘目录，请用 -Source 指定路径"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -Source D:\workspace\vibe-coding-cn -Profile saas"
    exit 1
}

# 校验参数
if ($Profile -eq "" -and -not $All) {
    Write-Err "请指定 -Profile <name> 或 -All"
    Write-Host ""
    Write-Host "可用 profile:"
    Write-Host "  saas            SaaS 应用"
    Write-Host "  enterprise      企业级应用"
    Write-Host "  quant-crypto    加密货币量化"
    Write-Host "  quant-astock    A 股量化"
    Write-Host "  quant-us        美股量化"
    Write-Host "  app-mini        APP/小程序"
    Write-Host "  full-stack      全栈开发"
    Write-Host "  all             全部技能 + 工作流"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -Profile saas"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -Profile quant-crypto -Workflow"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -All -Workflow"
    exit 1
}

# all profile 同时开启全量和工作流
if ($Profile -eq "all") {
    $All = $true
    $Workflow = $true
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  vibe-coding-cn 项目技能拉取 (Windows)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "  母盘路径:  " -NoNewline; Write-Host $Source -ForegroundColor Green
Write-Host "  输出目录:  " -NoNewline; Write-Host $Output -ForegroundColor Green
Write-Host "  业务线:    " -NoNewline; Write-Host $(if ($Profile) { $Profile } else { "all" }) -ForegroundColor Green
Write-Host "  拉工作流:  " -NoNewline; Write-Host $Workflow -ForegroundColor Green
Write-Host ""

# 收集技能列表
$skills = Collect-Skills
$count = $skills.Count

Write-Host "  待拉取:    " -NoNewline; Write-Host "$count 个技能" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 创建目录
if (-not $DryRun) {
    New-Item -ItemType Directory -Path "$Output\skills" -Force | Out-Null
}

# 复制技能
$success = 0
$failed = 0
foreach ($skill in $skills) {
    if ($skill -eq "") { continue }
    if (Copy-Skill $skill) {
        $success++
    } else {
        $failed++
    }
}

# 复制工作流
if ($Workflow) {
    Copy-Workflow
}

# 生成索引
Generate-Index

# 汇总
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  完成! 成功: $success  跳过: $failed" -ForegroundColor Green
Write-Host "  输出: " -NoNewline; Write-Host $Output -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
