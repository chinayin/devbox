#Requires -Version 5.1
<#
.SYNOPSIS
    devbox-win.ps1 - Windows 开发环境初始化脚本
.DESCRIPTION
    项目: https://github.com/chinaiyn/devbox
    协议: MIT
.EXAMPLE
    .\devbox-win.ps1 install -China -VibeCoding
    .\devbox-win.ps1 status
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'status', 'help')]
    [string]$Command = 'help',
    
    [Alias('c')]
    [switch]$China,
    
    [switch]$VibeCoding,
    [switch]$Python,
    [string]$PythonVersion,
    [switch]$NodeJS,
    [string]$NodeJSVersion,
    [switch]$Go,
    [string]$GoVersion,
    [switch]$Rust,
    [switch]$ScoopOnly
)

$ErrorActionPreference = 'Stop'

#===========================================
# 配置
#===========================================
$script:VERSION = "v0.1"
$script:PROJECT_URL = "https://github.com/chinaiyn/devbox"

# 镜像源配置
$script:SCOOP_MIRROR = ""
$script:PIP_MIRROR = "https://pypi.org/simple"
$script:NPM_MIRROR = "https://registry.npmjs.org"
$script:GO_PROXY = ""
$script:RUST_MIRROR = ""

# 中国镜像
# 注意: Gitee 镜像在 CI 环境可能需要认证,使用 GitHub 镜像作为备选
$script:CN_SCOOP_MIRROR = "https://gitee.com/scoop-installer"
$script:CN_SCOOP_MIRROR_FALLBACK = "https://github.com/ScoopInstaller"
$script:CN_PIP_MIRROR = "https://pypi.tuna.tsinghua.edu.cn/simple"
$script:CN_NPM_MIRROR = "https://registry.npmmirror.com"
$script:CN_GO_PROXY = "https://goproxy.cn,direct"
$script:CN_RUST_MIRROR = "https://rsproxy.cn"

#===========================================
# 工具函数
#===========================================
function Write-Info { param([string]$Message) Write-Host "✓ " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-Fail { param([string]$Message) Write-Host "✗ " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host "! " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Dim { param([string]$Message) Write-Host $Message -ForegroundColor Gray }
function Write-Step { param([string]$Message) Write-Host "`n==> " -ForegroundColor Cyan -NoNewline; Write-Host $Message -ForegroundColor White }

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host $Title -ForegroundColor White
    Write-Host "────────────────────────────────────────"
}

function Write-Header {
    param([string]$Subtitle)
    Write-Host ""
    Write-Host "devbox " -ForegroundColor White -NoNewline
    Write-Host $script:VERSION
    Write-Host $script:PROJECT_URL -ForegroundColor Gray
    Write-Host "────────────────────────────────────────"
    Write-Host $Subtitle -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    # 排除 Windows App Alias (假命令)
    if ($cmd.Source -match 'WindowsApps') { return $false }
    return $true
}

function Get-ProfilePath {
    if ($PROFILE) { return $PROFILE }
    return "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}

function Add-ToProfile {
    param([string]$Content, [string]$Marker)
    $profilePath = Get-ProfilePath
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
    $existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($existing -notmatch [regex]::Escape($Marker)) {
        Add-Content -Path $profilePath -Value $Content
    }
}

function Get-SystemProxy {
    # 1. 检查环境变量
    if ($env:HTTPS_PROXY) { return @{ Source = "HTTPS_PROXY"; Value = $env:HTTPS_PROXY } }
    if ($env:HTTP_PROXY) { return @{ Source = "HTTP_PROXY"; Value = $env:HTTP_PROXY } }
    if ($env:ALL_PROXY) { return @{ Source = "ALL_PROXY"; Value = $env:ALL_PROXY } }
    
    # 2. 检查 Windows 系统代理
    $reg = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($reg.ProxyEnable -eq 1 -and $reg.ProxyServer) {
        return @{ Source = "系统代理"; Value = $reg.ProxyServer }
    }
    
    return $null
}

#===========================================
# 镜像配置
#===========================================
function Set-ChinaMirror {
    $script:SCOOP_MIRROR = $script:CN_SCOOP_MIRROR
    $script:PIP_MIRROR = $script:CN_PIP_MIRROR
    $script:NPM_MIRROR = $script:CN_NPM_MIRROR
    $script:GO_PROXY = $script:CN_GO_PROXY
    $script:RUST_MIRROR = $script:CN_RUST_MIRROR
}

#===========================================
# 帮助信息
#===========================================
function Show-Help {
    @"
devbox $script:VERSION
Windows 开发环境初始化脚本 | $script:PROJECT_URL

用法: .\devbox-win.ps1 <命令> [选项]

命令:
  install     安装开发环境
  status      检查安装状态
  help        显示帮助信息

install 选项:
  -China, -c          使用中国镜像源 (清华/淘宝/Gitee)
  -ScoopOnly          只安装 Scoop
  -VibeCoding         安装 AI 编程环境 (Python + Node.js)
  -Python             安装 Python
  -PythonVersion      指定 Python 版本 (如 3.12)
  -NodeJS             安装 Node.js
  -NodeJSVersion      指定 Node.js 版本 (如 20)
  -Go                 安装 Go
  -GoVersion          指定 Go 版本
  -Rust               安装 Rust

示例:
  .\devbox-win.ps1 status                           # 检查当前环境
  .\devbox-win.ps1 install -China -VibeCoding       # AI 编程环境 (推荐)
  .\devbox-win.ps1 install -China -Python -NodeJS   # 安装 Python + Node.js
  .\devbox-win.ps1 install -ScoopOnly -China        # 只装 Scoop
"@
}

#===========================================
# 命令: status
#===========================================
function Invoke-Status {
    Write-Header "status - 环境检查"
    
    Write-Section "系统信息"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host "  Windows    $($os.Caption) ($($os.Version))"
    Write-Host "  架构       $env:PROCESSOR_ARCHITECTURE"
    Write-Host "  PowerShell $($PSVersionTable.PSVersion)"
    Write-Host "  配置文件   $(Get-ProfilePath)"
    
    # 显示代理信息
    $proxy = Get-SystemProxy
    if ($proxy) {
        Write-Host "  Proxy      " -NoNewline
        Write-Host "$($proxy.Value)" -ForegroundColor Green -NoNewline
        Write-Host " ($($proxy.Source))" -ForegroundColor Gray
    }
    
    Write-Section "基础工具"
    if (Test-Command scoop) {
        $scoopVer = (scoop --version 2>$null | Select-Object -First 1) -replace 'v', ''
        Write-Info "Scoop $scoopVer"
        Write-Dim "    ├─ 路径: $(Get-Command scoop | Select-Object -ExpandProperty Source)"
        $scoopConfig = scoop config 2>$null
        if ($scoopConfig -match 'SCOOP_REPO') {
            Write-Dim "    └─ 镜像: 已配置"
        } else {
            Write-Dim "    └─ 镜像: 官方源"
        }
    } else {
        Write-Fail "Scoop 未安装"
    }
    
    if (Test-Command git) {
        $gitVer = (git --version) -replace 'git version ', ''
        Write-Info "Git $gitVer"
    } else {
        Write-Fail "Git 未安装"
    }
    
    Write-Section "编程语言"
    if (Test-Command python) {
        $pyVer = (python --version 2>&1) -replace 'Python ', ''
        Write-Info "Python $pyVer"
        Write-Dim "    ├─ 路径: $(Get-Command python | Select-Object -ExpandProperty Source)"
        $pipConfig = "$env:APPDATA\pip\pip.ini"
        if (Test-Path $pipConfig) {
            $pipMirror = (Get-Content $pipConfig | Select-String 'index-url' | ForEach-Object { $_ -replace '.*=\s*', '' })
            Write-Dim "    └─ pip:  $pipMirror"
        } else {
            Write-Dim "    └─ pip:  官方源"
        }
    } else {
        Write-Dim "  Python 未安装"
    }
    
    if (Test-Command node) {
        $nodeVer = node --version
        Write-Info "Node.js $nodeVer"
        Write-Dim "    ├─ 路径: $(Get-Command node | Select-Object -ExpandProperty Source)"
        if (Test-Command npm) {
            $npmMirror = npm config get registry 2>$null
            Write-Dim "    └─ npm:  $npmMirror"
        }
    } else {
        Write-Dim "  Node.js 未安装"
    }
    
    if (Test-Command go) {
        $goVer = (go version) -replace 'go version go', '' -replace ' .*', ''
        Write-Info "Go $goVer"
        Write-Dim "    ├─ 路径: $(Get-Command go | Select-Object -ExpandProperty Source)"
        $goProxy = go env GOPROXY 2>$null
        Write-Dim "    └─ proxy: $goProxy"
    } else {
        Write-Dim "  Go 未安装"
    }
    
    if (Test-Command rustc) {
        $rustVer = (rustc --version) -replace 'rustc ', '' -replace ' .*', ''
        Write-Info "Rust $rustVer"
        Write-Dim "    └─ 路径: $(Get-Command rustc | Select-Object -ExpandProperty Source)"
    } else {
        Write-Dim "  Rust 未安装"
    }
    
    Write-Host ""
}

#===========================================
# 安装函数
#===========================================
function Install-Scoop {
    Write-Step "安装 Scoop"
    
    if (Test-Command scoop) {
        $scoopVer = scoop --version 2>$null | Select-Object -First 1
        Write-Info "Scoop 已安装 ($scoopVer)"
        return
    }
    
    # 设置执行策略
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    
    if ($script:SCOOP_MIRROR) {
        # 使用 Gitee 镜像安装
        $env:SCOOP_REPO = "$script:SCOOP_MIRROR/scoop"
        Invoke-RestMethod "$script:SCOOP_MIRROR/scoop/raw/master/bin/install.ps1" | Invoke-Expression
    } else {
        # 官方安装
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    }
    
    # 刷新环境变量
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    
    Write-Info "Scoop 安装完成"
}

function Install-Git {
    Write-Step "安装 Git"
    
    if (Test-Command git) {
        $gitVer = git --version
        Write-Info "Git 已安装 ($gitVer)"
        return
    }
    
    scoop install git
    Write-Info "Git 安装完成"
}

function Save-ScoopMirror {
    Write-Step "配置 Scoop bucket"
    
    if ($script:SCOOP_MIRROR) {
        # 配置 Scoop 仓库镜像
        scoop config SCOOP_REPO "$script:SCOOP_MIRROR/scoop"
        
        # 临时禁用 Git 交互式认证 (仅影响当前命令)
        $env:GIT_TERMINAL_PROMPT = "0"
        
        # 移除现有的 main bucket (可能是官方源)
        scoop bucket rm main 2>$null
        
        scoop update 2>$null
        
        # 添加镜像 bucket (注意: Gitee 上是大写 Main)
        scoop bucket add main "$script:SCOOP_MIRROR/Main" 2>$null
        $addResult = $LASTEXITCODE
        
        # 恢复环境变量
        Remove-Item Env:GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue
        
        # 验证 bucket 是否添加成功
        $buckets = scoop bucket list 2>$null
        if ($buckets -match 'main') {
            Write-Info "Scoop 镜像已配置 (Gitee)"
            return
        }
        
        Write-Warn "Gitee 镜像不可用,回退到官方源"
    }
    
    # 检查 main bucket 是否已存在 (非镜像模式)
    $buckets = scoop bucket list 2>$null
    if ($buckets -match 'main') {
        Write-Info "main bucket 已存在"
        return
    }
    
    # 使用官方 bucket
    scoop bucket add main
    if ($LASTEXITCODE -ne 0) {
        throw "无法添加 Scoop main bucket"
    }
    Write-Info "Scoop main bucket 已配置"
}

function Install-Python {
    Write-Step "安装 Python"
    
    $pkg = "python"
    if ($PythonVersion) { $pkg = "python$PythonVersion" }
    
    # 检查是否真正安装了 Python (排除 Windows Store 别名)
    $pythonInstalled = $false
    if (Test-Command python) {
        $pyOutput = python --version 2>&1
        if ($pyOutput -notmatch 'Microsoft Store|was not found') {
            $pythonInstalled = $true
            Write-Info "Python 已安装 ($pyOutput)"
        }
    }
    
    if (-not $pythonInstalled) {
        scoop install $pkg
        if ($LASTEXITCODE -ne 0) {
            throw "Python 安装失败"
        }
        # 刷新环境变量
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Info "Python 安装完成 ($(python --version 2>&1))"
    }
    
    Write-Step "配置 pip 镜像"
    $pipDir = "$env:APPDATA\pip"
    if (-not (Test-Path $pipDir)) { New-Item -ItemType Directory -Path $pipDir -Force | Out-Null }
    $mirror = $script:PIP_MIRROR
    if (-not $mirror) { $mirror = "https://pypi.org/simple" }
    $pipHost = ([uri]$mirror).Host
    @"
[global]
index-url = $mirror
trusted-host = $pipHost
"@ | Set-Content "$pipDir\pip.ini"
    Write-Info "pip → $mirror"
}

function Install-NodeJS {
    Write-Step "安装 Node.js"
    
    $pkg = "nodejs"
    if ($NodeJSVersion) { $pkg = "nodejs$NodeJSVersion" }
    
    if (Test-Command node) {
        $nodeVer = node --version
        Write-Info "Node.js 已安装 ($nodeVer)"
    } else {
        scoop install $pkg
        # 刷新环境变量
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Info "Node.js 安装完成 ($(node --version))"
    }
    
    Write-Step "配置 npm 镜像"
    $mirror = $script:NPM_MIRROR
    if (-not $mirror) { $mirror = "https://registry.npmjs.org" }
    npm config set registry $mirror
    Write-Info "npm → $mirror"
}

function Install-Go {
    Write-Step "安装 Go"
    
    $pkg = "go"
    
    if (Test-Command go) {
        $goVer = go version
        Write-Info "Go 已安装 ($goVer)"
    } else {
        scoop install $pkg
        # 刷新环境变量
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Info "Go 安装完成 ($(go version))"
    }
    
    $proxy = $script:GO_PROXY
    if ($proxy) {
        Write-Step "配置 Go 镜像"
        go env -w GOPROXY="$proxy"
        Write-Info "GOPROXY → $proxy"
    }
}

function Install-Rust {
    Write-Step "安装 Rust"
    
    $mirror = $script:RUST_MIRROR
    
    if (Test-Command rustc) {
        $rustVer = rustc --version
        Write-Info "Rust 已安装 ($rustVer)"
    } else {
        if ($mirror) {
            $env:RUSTUP_DIST_SERVER = $mirror
            $env:RUSTUP_UPDATE_ROOT = "$mirror/rustup"
        }
        
        # 下载并运行 rustup-init
        $rustupInit = "$env:TEMP\rustup-init.exe"
        Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $rustupInit
        & $rustupInit -y --default-toolchain stable
        Remove-Item $rustupInit -Force
        
        # 刷新环境变量
        $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
        
        Write-Info "Rust 安装完成 ($(rustc --version))"
    }
    
    if ($mirror) {
        Write-Step "配置 Rust 镜像"
        $cargoConfig = "$env:USERPROFILE\.cargo\config"
        @"
[source.crates-io]
replace-with = 'rsproxy'

[source.rsproxy]
registry = "$mirror/crates.io-index"
"@ | Set-Content $cargoConfig
        Write-Info "Cargo → $mirror"
    }
}

#===========================================
# 命令: install
#===========================================
function Invoke-Install {
    # 设置镜像
    if ($China) {
        Set-ChinaMirror
        $region = "中国镜像"
    } else {
        $region = "官方源"
    }
    
    # VibeCoding 快捷方式
    if ($VibeCoding) {
        $script:Python = $true
        $script:NodeJS = $true
    }
    
    Write-Header "install - 环境安装 [$region]"
    
    # 检测代理并提示
    $proxy = Get-SystemProxy
    if ($proxy) {
        Write-Info "检测到代理: $($proxy.Value) ($($proxy.Source))"
        if ($China) {
            Write-Warn "已有代理,可能不需要 -China 镜像"
        }
    }
    
    Install-Scoop
    Install-Git
    Save-ScoopMirror
    
    if ($ScoopOnly) {
        Write-Host ""
        Write-Info "Scoop 安装完成 (-ScoopOnly)"
        Write-Warn "重新打开 PowerShell 生效"
        return
    }
    
    if ($Python -or $PythonVersion) { Install-Python }
    if ($NodeJS -or $NodeJSVersion) { Install-NodeJS }
    if ($Go -or $GoVersion) { Install-Go }
    if ($Rust) { Install-Rust }
    
    Write-Host ""
    Write-Host "────────────────────────────────────────"
    Write-Host "安装完成" -ForegroundColor Green
    Write-Host ""
    if (Test-Command scoop) { Write-Host "  Scoop     $((scoop --version 2>$null | Select-Object -First 1) -replace 'v', '')" }
    if ($Python -and (Test-Command python)) { Write-Host "  Python    $((python --version 2>&1) -replace 'Python ', '')" }
    if ($NodeJS -and (Test-Command node)) { Write-Host "  Node.js   $(node --version)" }
    if ($Go -and (Test-Command go)) { Write-Host "  Go        $((go version) -replace 'go version go', '' -replace ' .*', '')" }
    if ($Rust -and (Test-Command rustc)) { Write-Host "  Rust      $((rustc --version) -replace 'rustc ', '' -replace ' .*', '')" }
    Write-Host ""
    Write-Warn "重新打开 PowerShell 生效"
}

#===========================================
# 主入口
#===========================================
switch ($Command) {
    'install' { Invoke-Install }
    'status'  { Invoke-Status }
    'help'    { Show-Help }
    default   { Show-Help }
}
