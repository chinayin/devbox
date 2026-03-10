#Requires -Version 5.1
<#
.SYNOPSIS
    devbox-win.ps1 - Windows Development Environment Setup Script
.DESCRIPTION
    Project: https://github.com/chinayin/devbox
    License: MIT
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
    [switch]$Kiro,
    [switch]$Cursor,
    [switch]$VSCode,
    [switch]$CMake,
    [switch]$VCTools,
    [switch]$ScoopOnly,
    [switch]$NoAria2
)

$ErrorActionPreference = 'Stop'

#===========================================
# Admin Detection
#===========================================
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$script:IsAdmin = Test-IsAdmin

#===========================================
# Configuration
#===========================================
$script:VERSION = "v1.0"
$script:PROJECT_URL = "https://github.com/chinayin/devbox"

# Scoop install URLs
$script:SCOOP_OFFICIAL_URL = "get.scoop.sh"
$script:SCOOP_CN_URL = "scoop.201704.xyz"
$script:SCOOP_CN_REPO = "https://gitee.com/scoop-installer/scoop"
$script:GH_PROXY = "https://gh-proxy.org"

# Mirror configuration
$script:PIP_MIRROR = "https://pypi.org/simple"
$script:NPM_MIRROR = "https://registry.npmjs.org"
$script:GO_PROXY = ""
$script:RUST_MIRROR = ""

# China mirrors
$script:CN_PIP_MIRROR = "https://pypi.tuna.tsinghua.edu.cn/simple"
$script:CN_NPM_MIRROR = "https://registry.npmmirror.com"
$script:CN_GO_PROXY = "https://goproxy.cn,direct"
$script:CN_RUST_MIRROR = "https://rsproxy.cn"

#===========================================
# Utility Functions
#===========================================
function Write-Info { param([string]$Message) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-Fail { param([string]$Message) Write-Host "[X]  " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host "[!]  " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Dim { param([string]$Message) Write-Host $Message -ForegroundColor Gray }
function Write-Step { param([string]$Message) Write-Host "`n==> " -ForegroundColor Cyan -NoNewline; Write-Host $Message -ForegroundColor White }

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host $Title -ForegroundColor White
    Write-Host "----------------------------------------"
}

function Write-Header {
    param([string]$Subtitle)
    Write-Host ""
    Write-Host "Devbox " -ForegroundColor White -NoNewline
    Write-Host $script:VERSION
    Write-Host $script:PROJECT_URL -ForegroundColor Gray
    Write-Host "----------------------------------------"
    Write-Host $Subtitle -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    if ($cmd.Source -match 'WindowsApps') { return $false }
    return $true
}

function Get-ProfilePath {
    if ($PROFILE) { return $PROFILE }
    return "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}

function Get-SystemProxy {
    if ($env:HTTPS_PROXY) { return @{ Source = "HTTPS_PROXY"; Value = $env:HTTPS_PROXY } }
    if ($env:HTTP_PROXY) { return @{ Source = "HTTP_PROXY"; Value = $env:HTTP_PROXY } }
    if ($env:ALL_PROXY) { return @{ Source = "ALL_PROXY"; Value = $env:ALL_PROXY } }
    
    $reg = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($reg.ProxyEnable -eq 1 -and $reg.ProxyServer) {
        return @{ Source = "System"; Value = $reg.ProxyServer }
    }
    return $null
}

function Get-AdminStatus {
    if ($script:IsAdmin) { return "Admin" }
    return "User"
}

#===========================================
# Mirror Configuration
#===========================================
function Set-ChinaMirror {
    $script:PIP_MIRROR = $script:CN_PIP_MIRROR
    $script:NPM_MIRROR = $script:CN_NPM_MIRROR
    $script:GO_PROXY = $script:CN_GO_PROXY
    $script:RUST_MIRROR = $script:CN_RUST_MIRROR
}

#===========================================
# Help
#===========================================
function Show-Help {
    Write-Host "Devbox $script:VERSION"
    Write-Host "Windows 一行命令搞定 AI 编程环境 | $script:PROJECT_URL"
    Write-Host ""
    Write-Host "Usage: .\devbox-win.ps1 <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  install     Install development environment"
    Write-Host "  status      Check installation status"
    Write-Host "  help        Show this help"
    Write-Host ""
    Write-Host "Install Options:"
    Write-Host "  -China, -c          Use China mirrors (Tsinghua/Taobao)"
    Write-Host "  -ScoopOnly          Only install Scoop"
    Write-Host "  -NoAria2            Disable aria2 (enabled by default for faster downloads)"
    Write-Host "  -VibeCoding         Install AI coding environment (Python + Node.js)"
    Write-Host "  -Python             Install Python"
    Write-Host "  -PythonVersion      Specify Python version (e.g. 3.12)"
    Write-Host "  -NodeJS             Install Node.js"
    Write-Host "  -NodeJSVersion      Specify Node.js version (e.g. 20)"
    Write-Host "  -Go                 Install Go"
    Write-Host "  -GoVersion          Specify Go version"
    Write-Host "  -Rust               Install Rust"
    Write-Host "  -CMake              Install CMake (needed by node-llama-cpp etc.)"
    Write-Host "  -VCTools            Install VS C++ Build Tools (needed by node-gyp)"
    Write-Host "  -Kiro               Install Kiro (AI IDE) - manual download"
    Write-Host "  -Cursor             Install Cursor (AI IDE)"
    Write-Host "  -VSCode             Install VS Code"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\devbox-win.ps1 status                           # Check environment"
    Write-Host "  .\devbox-win.ps1 install -China -VibeCoding       # AI coding (recommended)"
    Write-Host "  .\devbox-win.ps1 install -China -Python -NodeJS   # Install Python + Node.js"
    Write-Host "  .\devbox-win.ps1 install -Python -PythonVersion 3.12   # Install Python 3.12"
    Write-Host "  .\devbox-win.ps1 install -ScoopOnly               # Only install Scoop"
    Write-Host "  .\devbox-win.ps1 install -China -Cursor           # Install Cursor"
}

#===========================================
# Command: status
#===========================================
function Invoke-Status {
    Write-Header "status - Environment Check"
    
    Write-Section "System Info"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host "  Windows    $($os.Caption) ($($os.Version))"
    Write-Host "  Arch       $env:PROCESSOR_ARCHITECTURE"
    Write-Host "  PowerShell $($PSVersionTable.PSVersion)"
    Write-Host "  Profile    $(Get-ProfilePath)"
    Write-Host "  Mode       $(Get-AdminStatus)"
    
    $proxy = Get-SystemProxy
    if ($proxy) {
        Write-Host "  Proxy      " -NoNewline
        Write-Host "$($proxy.Value)" -ForegroundColor Green -NoNewline
        Write-Host " ($($proxy.Source))" -ForegroundColor Gray
    }
    
    Write-Section "Base Tools"
    if (Test-Command scoop) {
        Write-Info "Scoop"
        Write-Dim "    Path: $(Get-Command scoop | Select-Object -ExpandProperty Source)"
        # Check aria2 status
        if (Test-Command aria2c) {
            $aria2Enabled = scoop config aria2-enabled 2>$null
            if ($aria2Enabled -match 'True') {
                Write-Dim "    aria2: Enabled"
            } else {
                Write-Dim "    aria2: Installed but disabled"
            }
        }
    } else {
        Write-Fail "Scoop not installed"
    }
    
    if (Test-Command git) {
        $gitVer = (git --version) -replace 'git version ', ''
        Write-Info "Git $gitVer"
    } else {
        Write-Fail "Git not installed"
    }
    
    Write-Section "Languages"
    if (Test-Command python) {
        $pyVer = (python --version 2>&1) -replace 'Python ', ''
        Write-Info "Python $pyVer"
        Write-Dim "    Path: $(Get-Command python | Select-Object -ExpandProperty Source)"
        $pipConfig = "$env:APPDATA\pip\pip.ini"
        if (Test-Path $pipConfig) {
            $pipMirror = (Get-Content $pipConfig | Select-String 'index-url' | ForEach-Object { $_ -replace '.*=\s*', '' })
            Write-Dim "    pip:  $pipMirror"
        } else {
            Write-Dim "    pip:  Official"
        }
    } else {
        Write-Dim "  Python not installed"
    }
    
    if (Test-Command node) {
        $nodeVer = node --version
        Write-Info "Node.js $nodeVer"
        Write-Dim "    Path: $(Get-Command node | Select-Object -ExpandProperty Source)"
        if (Test-Command npm) {
            $npmMirror = npm config get registry 2>$null
            Write-Dim "    npm:  $npmMirror"
        }
    } else {
        Write-Dim "  Node.js not installed"
    }
    
    if (Test-Command go) {
        $goVer = (go version) -replace 'go version go', '' -replace ' .*', ''
        Write-Info "Go $goVer"
        Write-Dim "    Path: $(Get-Command go | Select-Object -ExpandProperty Source)"
        $goProxy = go env GOPROXY 2>$null
        Write-Dim "    proxy: $goProxy"
    } else {
        Write-Dim "  Go not installed"
    }
    
    if (Test-Command rustc) {
        $rustVer = (rustc --version) -replace 'rustc ', '' -replace ' .*', ''
        Write-Info "Rust $rustVer"
        Write-Dim "    Path: $(Get-Command rustc | Select-Object -ExpandProperty Source)"
    } else {
        Write-Dim "  Rust not installed"
    }
    
    Write-Section "Build Tools"
    if (Test-VCToolsInstalled) {
        Write-Info "VS C++ Build Tools"
        $pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
        $vswherePath = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path $vswherePath) {
            $vsPath = $null
            try {
                $vsPath = & $vswherePath -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
            } catch {}
            if ($vsPath) { Write-Dim "    Path: $vsPath" }
        }
    } else {
        Write-Dim "  VS C++ Build Tools not installed"
    }
    
    if (Test-Command cmake) {
        $cmakeVer = (cmake --version | Select-Object -First 1) -replace 'cmake version ', ''
        Write-Info "CMake $cmakeVer"
        Write-Dim "    Path: $(Get-Command cmake | Select-Object -ExpandProperty Source)"
    } else {
        Write-Dim "  CMake not installed"
    }
    
    Write-Section "Dev Tools"
    # Kiro
    $kiroPath = "$env:LOCALAPPDATA\Programs\Kiro\Kiro.exe"
    if (Test-Path $kiroPath) {
        Write-Info "Kiro"
        Write-Dim "    Path: $kiroPath"
    } else {
        Write-Dim "  Kiro not installed"
    }
    
    # Cursor
    $cursorPath = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"
    if (Test-Path $cursorPath) {
        Write-Info "Cursor"
        Write-Dim "    Path: $cursorPath"
    } elseif (Test-Command cursor) {
        Write-Info "Cursor (scoop)"
        Write-Dim "    Path: $(Get-Command cursor | Select-Object -ExpandProperty Source)"
    } else {
        Write-Dim "  Cursor not installed"
    }
    
    # VS Code
    $vscodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    if (Test-Path $vscodePath) {
        Write-Info "VS Code"
        Write-Dim "    Path: $vscodePath"
    } elseif (Test-Command code) {
        Write-Info "VS Code (scoop)"
        Write-Dim "    Path: $(Get-Command code | Select-Object -ExpandProperty Source)"
    } else {
        Write-Dim "  VS Code not installed"
    }
    
    Write-Host ""
}

#===========================================
# Install Functions
#===========================================
function Install-Scoop {
    Write-Step "Installing Scoop"
    
    if (-not (Test-Command scoop)) {
        # 检查并设置 ExecutionPolicy
        Write-Step "Checking ExecutionPolicy"
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-Info "ExecutionPolicy set to RemoteSigned"
            } catch {
                Write-Fail "Failed to set ExecutionPolicy"
                Write-Host ""
                Write-Host "Please run this command manually first:" -ForegroundColor Yellow
                Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
                Write-Host ""
                throw "ExecutionPolicy configuration required"
            }
        } else {
            Write-Info "ExecutionPolicy OK ($currentPolicy)"
        }
        
        # 决定安装源: 有代理走官方，无代理+China走镜像，其他走官方
        $proxy = Get-SystemProxy
        $useOfficialSource = $true
        if ($China -and -not $proxy) {
            $useOfficialSource = $false
        }
        
        # 构建安装参数
        $adminFlag = ''
        if ($script:IsAdmin) {
            $adminFlag = ' -RunAsAdmin'
            Write-Dim "    Admin mode, installing globally"
        }
        
        if ($useOfficialSource) {
            if ($proxy) { Write-Dim "    Proxy detected, using official source" }
            try {
                iex "& {$(irm $script:SCOOP_OFFICIAL_URL)}$adminFlag"
            } catch {
                throw "Scoop installation failed: $_"
            }
        } else {
            Write-Dim "    Using China mirror"
            try {
                iex "& {$(irm $script:SCOOP_CN_URL)}$adminFlag"
            } catch {
                Write-Warn "China mirror failed, trying official source..."
                iex "& {$(irm $script:SCOOP_OFFICIAL_URL)}$adminFlag"
            }
        }
        
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        
        if (-not (Test-Command scoop)) {
            throw "Scoop installation failed"
        }
        
        Write-Info "Scoop installed"
    } else {
        Write-Info "Scoop already installed"
    }
    
    # China 模式: 确保配置 gitee repo 和 main bucket 镜像
    # 注意: 不设置 URL_PROXY，因为 gh-proxy 只能代理 github.com 的资源
    # 而 scoop 的 URL_PROXY 会对所有下载链接加前缀（包括 python.org、nodejs.org 等），导致下载失败
    if ($China -and -not (Get-SystemProxy)) {
        # 检查 SCOOP_REPO 是否已经是 gitee（scoop config 输出带描述文字，用 match 判断）
        $repoOutput = scoop config SCOOP_REPO 2>$null
        if ($repoOutput -notmatch 'gitee\.com') {
            scoop config SCOOP_REPO $script:SCOOP_CN_REPO
            Write-Dim "    Scoop repo -> gitee"
        }
        
        # 确保 main bucket 是有效的 git 仓库且指向 gitee 镜像
        # 通过 scoop 自身获取 buckets 目录
        $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
        $mainBucketPath = Join-Path $scoopDir "buckets\main"
        
        $needReaddMain = $false
        $gitDir = Join-Path $mainBucketPath ".git"
        if (Test-Path $gitDir) {
            # 是 git 仓库，检查 remote URL 是否已经指向 gitee
            $remoteUrl = git -C $mainBucketPath remote get-url origin 2>$null
            if ($remoteUrl -notmatch 'gitee\.com') {
                $needReaddMain = $true
            }
        } elseif (Test-Path $mainBucketPath) {
            # 目录存在但不是 git 仓库
            $needReaddMain = $true
        } else {
            # 目录不存在
            $needReaddMain = $true
        }
        if ($needReaddMain) {
            Write-Dim "    Reinitializing main bucket for China mirror..."
            try { scoop bucket rm main 2>$null } catch {}
            if (Test-Path $mainBucketPath) {
                Remove-Item -Path $mainBucketPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            try {
                scoop bucket add main "https://gitee.com/scoop-installer/Main"
                Write-Dim "    main bucket -> gitee mirror"
            } catch {
                try {
                    scoop bucket add main "$($script:GH_PROXY)/https://github.com/ScoopInstaller/Main"
                    Write-Dim "    main bucket -> gh-proxy"
                } catch {
                    Write-Warn "Failed to reinitialize main bucket: $_"
                }
            }
        }
    }
}

function Install-Git {
    Write-Step "Installing Git"
    
    if (Test-Command git) {
        $gitVer = git --version
        Write-Info "Git already installed ($gitVer)"
        return
    }
    
    # 临时禁用 aria2，避免 SSL 证书吊销检查失败导致下载出错
    $aria2WasEnabled = $false
    if (Test-Command aria2c) {
        $aria2Status = scoop config aria2-enabled 2>$null
        if ($aria2Status -match 'True') {
            $aria2WasEnabled = $true
            scoop config aria2-enabled false
            Write-Dim "    aria2 temporarily disabled for Git install"
        }
    }
    
    try {
        scoop install git
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Info "Git installed"
    } catch {
        Write-Fail "Git installation failed: $_"
    } finally {
        # 恢复 aria2
        if ($aria2WasEnabled) {
            scoop config aria2-enabled true
            Write-Dim "    aria2 re-enabled"
        }
    }
}

function Install-Aria2 {
    Write-Step "Enabling aria2 (multi-threaded download)"
    
    if (-not (Test-Command aria2c)) {
        try {
            scoop install aria2
        } catch {
            Write-Warn "Failed to install aria2, skipping"
            return
        }
        if (-not (Test-Command aria2c)) {
            Write-Warn "aria2 installation incomplete, skipping"
            return
        }
    }
    
    scoop config aria2-enabled true
    scoop config aria2-warning-enabled false
    # 禁用证书吊销检查，避免某些网络环境下 SSL 握手失败
    scoop config aria2-options '--check-certificate=false'
    Write-Info "aria2 enabled"
}

function Install-Python {
    Write-Step "Installing Python"
    
    $pkg = "python"
    if ($PythonVersion) { $pkg = "python$PythonVersion" }
    
    $pythonInstalled = $false
    if (Test-Command python) {
        $pyOutput = python --version 2>&1
        if ($pyOutput -notmatch 'Microsoft Store|was not found') {
            $pythonInstalled = $true
            Write-Info "Python already installed ($pyOutput)"
        }
    }
    
    if (-not $pythonInstalled) {
        scoop install $pkg
        if ($LASTEXITCODE -ne 0) {
            throw "Python installation failed"
        }
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Info "Python installed ($(python --version 2>&1))"
    }
    
    Write-Step "Configuring pip mirror"
    $pipDir = "$env:APPDATA\pip"
    if (-not (Test-Path $pipDir)) { New-Item -ItemType Directory -Path $pipDir -Force | Out-Null }
    $mirror = $script:PIP_MIRROR
    if (-not $mirror) { $mirror = "https://pypi.org/simple" }
    $pipHost = ([uri]$mirror).Host
    $pipContent = "[global]`nindex-url = $mirror`ntrusted-host = $pipHost"
    Set-Content -Path "$pipDir\pip.ini" -Value $pipContent
    Write-Info "pip -> $mirror"
}

function Install-NodeJS {
    Write-Step "Installing Node.js"
    
    $pkg = "nodejs"
    if ($NodeJSVersion) { $pkg = "nodejs$NodeJSVersion" }
    
    if (Test-Command node) {
        $nodeVer = node --version
        Write-Info "Node.js already installed ($nodeVer)"
    } else {
        scoop install $pkg
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Info "Node.js installed ($(node --version))"
    }
    
    Write-Step "Configuring npm mirror"
    $mirror = $script:NPM_MIRROR
    if (-not $mirror) { $mirror = "https://registry.npmjs.org" }
    npm config set registry $mirror
    Write-Info "npm -> $mirror"
}

function Install-Go {
    Write-Step "Installing Go"
    
    $pkg = "go"
    if ($GoVersion) { $pkg = "go@$GoVersion" }
    
    if (Test-Command go) {
        $goVer = go version
        Write-Info "Go already installed ($goVer)"
    } else {
        scoop install $pkg
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Info "Go installed ($(go version))"
    }
    
    $proxy = $script:GO_PROXY
    if ($proxy) {
        Write-Step "Configuring Go proxy"
        go env -w GOPROXY="$proxy"
        Write-Info "GOPROXY -> $proxy"
    }
}

function Install-CMake {
    Write-Step "Installing CMake"
    
    if (Test-Command cmake) {
        $cmakeVer = (cmake --version | Select-Object -First 1) -replace 'cmake version ', ''
        Write-Info "CMake already installed ($cmakeVer)"
        return
    }
    
    scoop install cmake
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    Write-Info "CMake installed ($(cmake --version | Select-Object -First 1))"
}

function Test-VCToolsInstalled {
    # 检查 Visual Studio Build Tools / C++ 工作负载是否已安装
    $pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $pf = [Environment]::GetFolderPath('ProgramFiles')
    
    # 方法1: 通过 vswhere 查找
    $vswherePath = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswherePath) {
        $result = $null
        try {
            $result = & $vswherePath -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        } catch {}
        if ($result) { return $true }
    }
    # 方法2: 检查常见路径
    $path1 = Join-Path $pf 'Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC'
    $path2 = Join-Path $pf 'Microsoft Visual Studio\2022\Community\VC\Tools\MSVC'
    $path3 = Join-Path $pf86 'Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC'
    if (Test-Path $path1) { return $true }
    if (Test-Path $path2) { return $true }
    if (Test-Path $path3) { return $true }
    return $false
}

function Install-VCTools {
    Write-Step "Installing Visual Studio C++ Build Tools"
    
    if (Test-VCToolsInstalled) {
        Write-Info "Visual Studio C++ Build Tools already installed"
        return
    }
    
    # 需要管理员权限
    if (-not $script:IsAdmin) {
        Write-Warn "Installing VS Build Tools requires Administrator privileges"
        Write-Host ""
        Write-Host "  Please re-run this script as Administrator, or install manually:" -ForegroundColor Yellow
        Write-Host "  https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor Cyan
        Write-Host ""
        return
    }
    
    $installed = $false
    
    # 方案1: Chocolatey
    if (-not $installed -and (Test-Command choco)) {
        Write-Step "Trying Chocolatey..."
        try {
            choco install visualstudio2022-workload-vctools -y
            if (Test-VCToolsInstalled) {
                $installed = $true
                Write-Info "VS C++ Build Tools installed via Chocolatey"
            }
        } catch {
            Write-Warn "Chocolatey installation failed, trying next method..."
        }
    }
    
    # 方案2: winget
    if (-not $installed -and (Test-Command winget)) {
        Write-Step "Trying winget..."
        try {
            winget install --id Microsoft.VisualStudio.2022.BuildTools --silent --override '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
            if (Test-VCToolsInstalled) {
                $installed = $true
                Write-Info "VS C++ Build Tools installed via winget"
            }
        } catch {
            Write-Warn "winget installation failed, trying next method..."
        }
    }
    
    # 方案3: 直接下载 VS Build Tools installer
    if (-not $installed) {
        Write-Step "Downloading VS Build Tools installer..."
        $installerPath = "$env:TEMP\vs_BuildTools.exe"
        try {
            Invoke-WebRequest -Uri "https://aka.ms/vs/stable/vs_BuildTools.exe" -OutFile $installerPath -UseBasicParsing
            Write-Dim "    Installing (this may take a while)..."
            $process = Start-Process -FilePath $installerPath -ArgumentList "--quiet", "--wait", "--norestart", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--includeRecommended" -Wait -PassThru
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                $installed = $true
                Write-Info "VS C++ Build Tools installed via direct download"
                if ($process.ExitCode -eq 3010) {
                    Write-Warn "A reboot is required to complete the installation"
                }
            }
        } catch {
            Write-Warn "Direct download installation failed"
        }
    }
    
    # 全部失败，引导手动安装
    if (-not $installed) {
        Write-Fail "All automatic installation methods failed"
        Write-Host ""
        Write-Host "  Please install manually:" -ForegroundColor Yellow
        Write-Host "  1. Download: https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor Cyan
        Write-Host "  2. Run the installer" -ForegroundColor Cyan
        Write-Host "  3. Select 'Desktop development with C++' workload" -ForegroundColor Cyan
        Write-Host "  4. Click Install" -ForegroundColor Cyan
        Write-Host ""
    }
}

function Install-Rust {
    Write-Step "Installing Rust"
    
    $mirror = $script:RUST_MIRROR
    
    if (Test-Command rustc) {
        $rustVer = rustc --version
        Write-Info "Rust already installed ($rustVer)"
    } else {
        if ($mirror) {
            $env:RUSTUP_DIST_SERVER = $mirror
            $env:RUSTUP_UPDATE_ROOT = "$mirror/rustup"
        }
        
        $rustupInit = "$env:TEMP\rustup-init.exe"
        Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $rustupInit
        & $rustupInit -y --default-toolchain stable
        Remove-Item $rustupInit -Force
        
        $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
        
        Write-Info "Rust installed ($(rustc --version))"
    }
    
    if ($mirror) {
        Write-Step "Configuring Rust mirror"
        $cargoConfig = "$env:USERPROFILE\.cargo\config"
        $cargoContent = "[source.crates-io]`nreplace-with = 'rsproxy'`n`n[source.rsproxy]`nregistry = `"$mirror/crates.io-index`""
        Set-Content -Path $cargoConfig -Value $cargoContent
        Write-Info "Cargo -> $mirror"
    }
}

function Install-Kiro {
    Write-Step "Installing Kiro"
    
    $kiroPath = "$env:LOCALAPPDATA\Programs\Kiro\Kiro.exe"
    if (Test-Path $kiroPath) {
        Write-Info "Kiro already installed"
        return
    }
    
    # Kiro 目前不在 scoop 中，提示手动下载
    Write-Warn "Kiro is not available in Scoop"
    Write-Host ""
    Write-Host "  Please download Kiro manually from:" -ForegroundColor Yellow
    Write-Host "  https://kiro.dev/download" -ForegroundColor Cyan
    Write-Host ""
}

function Install-Cursor {
    Write-Step "Installing Cursor"
    
    $cursorPath = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"
    if (Test-Path $cursorPath) {
        Write-Info "Cursor already installed"
        return
    }
    
    if (Test-Command cursor) {
        Write-Info "Cursor already installed (scoop)"
        return
    }
    
    # 添加 extras bucket
    $buckets = scoop bucket list 2>$null
    if ($buckets -notmatch 'extras') {
        Write-Step "Adding scoop extras bucket"
        scoop bucket add extras
    }
    
    scoop install extras/cursor
    Write-Info "Cursor installed"
}

function Install-VSCode {
    Write-Step "Installing VS Code"
    
    $vscodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    if (Test-Path $vscodePath) {
        Write-Info "VS Code already installed"
        return
    }
    
    if (Test-Command code) {
        Write-Info "VS Code already installed (scoop)"
        return
    }
    
    # 添加 extras bucket
    $buckets = scoop bucket list 2>$null
    if ($buckets -notmatch 'extras') {
        Write-Step "Adding scoop extras bucket"
        scoop bucket add extras
    }
    
    scoop install extras/vscode
    Write-Info "VS Code installed"
}

#===========================================
# Command: install
#===========================================
function Invoke-Install {
    if ($China) {
        Set-ChinaMirror
        $region = "China Mirror"
    } else {
        $region = "Official"
    }
    
    if ($VibeCoding) {
        $script:Python = $true
        $script:NodeJS = $true
        # CMake 和 VCTools 安装耗时较长，不再默认包含，需要时用 -CMake / -VCTools 单独安装
    }
    
    Write-Header "install - Setup [$region]"
    Write-Dim "  PowerShell $($PSVersionTable.PSVersion) | $(Get-AdminStatus) | $env:PROCESSOR_ARCHITECTURE"
    
    $proxy = Get-SystemProxy
    if ($proxy) {
        Write-Info "Proxy detected: $($proxy.Value) ($($proxy.Source))"
        if ($China) {
            Write-Warn "Proxy detected, -China mirror may not be needed"
        }
    }
    
    Install-Scoop
    Install-Git
    if (-not $NoAria2) { Install-Aria2 }
    
    if ($ScoopOnly) {
        Write-Host ""
        Write-Info "Scoop installed (-ScoopOnly)"
        Write-Warn "Restart PowerShell to take effect"
        return
    }
    
    if ($Python -or $PythonVersion) { Install-Python }
    if ($NodeJS -or $NodeJSVersion) { Install-NodeJS }
    if ($VCTools) { Install-VCTools }
    if ($CMake) { Install-CMake }
    if ($Go -or $GoVersion) { Install-Go }
    if ($Rust) { Install-Rust }
    if ($Kiro) { Install-Kiro }
    if ($Cursor) { Install-Cursor }
    if ($VSCode) { Install-VSCode }
    
    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host "Installation Complete" -ForegroundColor Green
    Write-Host ""
    if (Test-Command scoop) { Write-Host "  Scoop     installed" }
    if ($Python -and (Test-Command python)) { Write-Host "  Python    $((python --version 2>&1) -replace 'Python ', '')" }
    if ($NodeJS -and (Test-Command node)) { Write-Host "  Node.js   $(node --version)" }
    if ($CMake -and (Test-Command cmake)) { Write-Host "  CMake     $((cmake --version | Select-Object -First 1) -replace 'cmake version ', '')" }
    if ($VCTools -and (Test-VCToolsInstalled)) { Write-Host "  VC Tools  installed" }
    if ($Go -and (Test-Command go)) { Write-Host "  Go        $((go version) -replace 'go version go', '' -replace ' .*', '')" }
    if ($Rust -and (Test-Command rustc)) { Write-Host "  Rust      $((rustc --version) -replace 'rustc ', '' -replace ' .*', '')" }
    if ($Cursor -and (Test-Command cursor)) { Write-Host "  Cursor    installed" }
    if ($VSCode -and (Test-Command code)) { Write-Host "  VS Code   installed" }
    Write-Host ""
    Write-Warn "Restart PowerShell to take effect"
    
    # 如果没有安装 CMake / VCTools，合并提示建议安装
    $tips = @()
    if (-not $CMake -and -not (Test-Command cmake)) {
        $tips += "CMake (-CMake)"
    }
    if (-not $VCTools -and -not (Test-VCToolsInstalled)) {
        $tips += "VC++ Build Tools (-VCTools)"
    }
    if ($tips.Count -gt 0) {
        Write-Host ""
        Write-Host "  Tip: " -ForegroundColor Yellow -NoNewline
        Write-Host "To compile native Node.js modules (node-gyp, node-llama-cpp), you may need:"
        foreach ($tip in $tips) {
            Write-Host "    - $tip" -ForegroundColor Cyan
        }
        Write-Host "  Run: " -NoNewline
        Write-Host ".\devbox-win.ps1 install -CMake -VCTools" -ForegroundColor Cyan
    }
}

#===========================================
# Main Entry
#===========================================
switch ($Command) {
    'install' { Invoke-Install }
    'status'  { Invoke-Status }
    'help'    { Show-Help }
    default   { Show-Help }
}
