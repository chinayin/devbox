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

# Non-critical errors should not stop the entire script; critical steps use try/catch + throw
$ErrorActionPreference = 'Continue'

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
$script:VERSION = "v1.4.1"
$script:PROJECT_URL = "https://github.com/chinayin/devbox"

# Scoop install URLs
$script:SCOOP_OFFICIAL_URL = "get.scoop.sh"
$script:SCOOP_CN_URL = "scoop.201704.xyz"
$script:SCOOP_CN_REPO = "https://gitee.com/scoop-installer/scoop"
$script:SCOOP_CN_EXTRAS_REPO = "https://gitee.com/scoop-installer/Extras"
$script:SCOOP_CN_MAIN_REPO = "https://gitee.com/scoop-installer/Main"
$script:GH_PROXY = "https://gh-proxy.org"

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
    # Only exclude WindowsApps stub for python/python3 (Store stub that opens Microsoft Store)
    if ($Name -match '^python' -and $cmd.Source -match 'WindowsApps') { return $false }
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
# Detection Functions
#===========================================

# Network connectivity check (only when no proxy and no -China)
function Test-Network {
    $unreachable = 0
    foreach ($url in @("https://github.com", "https://registry.npmjs.org")) {
        try {
            Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing | Out-Null
        } catch {
            $unreachable++
        }
    }
    if ($unreachable -gt 0) {
        Write-Warn "Some overseas sources are unreachable, consider using -China for mirrors"
    }
}

# Python real check (exclude Windows Store stub)
function Test-PythonReal {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    if ($cmd.Source -match 'WindowsApps') { return $false }
    try {
        $output = python --version 2>&1
        if ($output -match 'Microsoft Store|was not found') { return $false }
        return $true
    } catch {
        return $false
    }
}

# Generic post-install verification
function Test-InstallResult {
    param(
        [string]$Name,
        [string]$VersionCmd
    )
    
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    
    if (Test-Command $Name) {
        try {
            if ($VersionCmd) {
                $ver = Invoke-Expression $VersionCmd 2>&1 | Select-Object -First 1
            } else {
                $ver = & $Name --version 2>&1 | Select-Object -First 1
            }
            Write-Info "$Name verified ($ver)"
            return $true
        } catch {
            Write-Info "$Name verified (version check failed)"
            return $true
        }
    } else {
        Write-Fail "$Name not found after install, check PATH configuration"
        Write-Dim "    Tip: Restart PowerShell to reload PATH"
        return $false
    }
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
    Write-Host "  -China              Use China mirrors (Tsinghua/Taobao)"
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
    Write-Host "  -Kiro               Install Kiro (AI IDE)"
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
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    Write-Host "  ExecPolicy $policy"
    
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
    # Python with Store stub detection
    $pycmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pycmd) {
        if ($pycmd.Source -match 'WindowsApps') {
            Write-Warn "Python (Windows Store stub, not real Python)"
        } elseif (Test-PythonReal) {
            $pyVer = (python --version 2>&1) -replace 'Python ', ''
            Write-Info "Python $pyVer"
            Write-Dim "    Path: $($pycmd.Source)"
            $pipConfig = "$env:APPDATA\pip\pip.ini"
            if (Test-Path $pipConfig) {
                $pipMirror = (Get-Content $pipConfig | Select-String 'index-url' | ForEach-Object { $_ -replace '.*=\s*', '' })
                Write-Dim "    pip:  $pipMirror"
            } else {
                Write-Dim "    pip:  Official"
            }
            if (Test-Command uv) {
                Write-Dim "    uv:   $(uv --version)"
            }
        } else {
            Write-Warn "Python (detected but not functional)"
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
        if (-not (Test-Command npx)) {
            Write-Warn "    npx not found, check Node.js installation"
        }
        if (Test-Command pnpm) {
            Write-Dim "    pnpm: $(pnpm --version)"
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
# Install Functions - Layer 1: Package Manager
#===========================================
function Install-Scoop {
    Write-Step "Installing Scoop"
    
    if (-not (Test-Command scoop)) {
        # Check and set ExecutionPolicy
        Write-Step "Checking ExecutionPolicy"
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-Info "ExecutionPolicy set to RemoteSigned"
            } catch {
                Write-Fail "Failed to set ExecutionPolicy"
                Write-Host ""
                Write-Host "  Please run this command manually first:" -ForegroundColor Yellow
                Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
                Write-Host ""
                throw "ExecutionPolicy configuration required"
            }
        } else {
            Write-Info "ExecutionPolicy OK ($currentPolicy)"
        }
        
        # Decide install source: proxy -> official, no proxy + China -> mirror, else official
        $proxy = Get-SystemProxy
        $useOfficialSource = $true
        if ($China -and -not $proxy) {
            $useOfficialSource = $false
        }
        
        # Build install args
        $adminFlag = ''
        if ($script:IsAdmin) {
            $adminFlag = ' -RunAsAdmin'
            Write-Dim "    Admin mode, installing globally"
        }
        
        if ($useOfficialSource) {
            if ($proxy) { Write-Dim "    Proxy detected, using official source" }
            try {
                Invoke-Expression "& {$(Invoke-RestMethod $script:SCOOP_OFFICIAL_URL)}$adminFlag"
            } catch {
                throw "Scoop installation failed: $_"
            }
        } else {
            Write-Dim "    Using China mirror"
            try {
                Invoke-Expression "& {$(Invoke-RestMethod $script:SCOOP_CN_URL)}$adminFlag"
            } catch {
                Write-Warn "China mirror failed, trying official source..."
                try {
                    Invoke-Expression "& {$(Invoke-RestMethod $script:SCOOP_OFFICIAL_URL)}$adminFlag"
                } catch {
                    # Fallback: check if winget is available
                    if (Test-Command winget) {
                        Write-Dim "    You can install tools via winget manually."
                    }
                    throw "Scoop installation failed: $_"
                }
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
}

# Git: In China mode without proxy, must be installed before Scoop (needed for bucket mirror switch).
# In non-China mode (or with proxy), can be installed via Scoop after Scoop is set up.
function Install-Git {
    Write-Step "Installing Git"
    
    if (Test-Command git) {
        $gitVer = git --version
        Write-Info "Git already installed ($gitVer)"
        return
    }
    
    # Try Scoop (only if Scoop is available AND git is not yet present)
    if (Test-Command scoop) {
        Write-Dim "    Installing Git via Scoop..."
        try { scoop install git 2>$null } catch {}
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        if (Test-Command git) {
            Write-Info "Git installed via Scoop ($(git --version))"
            return
        }
        Write-Dim "    Scoop install git failed, trying other methods..."
    }
    
    # Try winget (non-China or with proxy; China without proxy downloads from GitHub so skip)
    $proxy = Get-SystemProxy
    if ((Test-Command winget) -and (-not $China -or $proxy)) {
        Write-Dim "    Installing Git via winget..."
        try {
            winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            $gitPath = "$env:ProgramFiles\Git\cmd"
            if ((Test-Path $gitPath) -and ($env:PATH -notmatch [regex]::Escape($gitPath))) {
                $env:PATH = "$gitPath;$env:PATH"
            }
            if (Test-Command git) {
                Write-Info "Git installed via winget ($(git --version))"
                return
            }
        } catch {
            Write-Warn "winget install failed: $_"
        }
    }
    
    # Fallback: prompt user to install manually
    Write-Fail "Git is required but could not be installed automatically"
    Write-Host ""
    Write-Host "  Please install Git for Windows:" -ForegroundColor Yellow
    Write-Host "  1. Download: https://git-scm.com/download/win" -ForegroundColor Cyan
    Write-Host "  2. Run the installer (use default options)" -ForegroundColor Cyan
    Write-Host "  3. Restart PowerShell" -ForegroundColor Cyan
    Write-Host "  4. Re-run this script" -ForegroundColor Cyan
    Write-Host ""
    throw "Git is required. Install it and re-run this script."
}

# Configure Scoop main bucket to use China mirror (requires git)
function Set-ScoopChinaMirror {
    if (-not $China -or (Get-SystemProxy)) { return }
    if (-not (Test-Command git)) { return }
    
    Write-Step "Configuring Scoop China mirror"
    
    # Set Scoop repo
    $repoOutput = scoop config SCOOP_REPO 2>$null
    if ($repoOutput -notmatch 'gitee\.com') {
        scoop config SCOOP_REPO $script:SCOOP_CN_REPO
        Write-Dim "    Scoop repo -> gitee"
    }
    
    # Switch main bucket to gitee
    $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
    $mainBucketPath = Join-Path $scoopDir "buckets\main"
    $gitDir = Join-Path $mainBucketPath ".git"
    
    $needSwitch = $false
    if (Test-Path $gitDir) {
        $remoteUrl = git -C $mainBucketPath remote get-url origin 2>$null
        if ($remoteUrl -notmatch 'gitee\.com') { $needSwitch = $true }
    } else {
        $needSwitch = $true
    }
    
    if ($needSwitch) {
        Write-Dim "    Switching main bucket to gitee mirror..."
        try { scoop bucket rm main 2>$null } catch {}
        if (Test-Path $mainBucketPath) {
            Remove-Item -Path $mainBucketPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        try {
            scoop bucket add main $script:SCOOP_CN_MAIN_REPO
            Write-Info "main bucket -> gitee mirror"
        } catch {
            Write-Warn "Failed to switch main bucket to gitee: $_"
        }
    } else {
        Write-Info "main bucket already on gitee mirror"
    }
}

function Set-ScoopProxy {
    param([switch]$Enable, [switch]$Disable)
    if ($Enable) {
        $proxy = Get-SystemProxy
        if ($proxy) {
            scoop config proxy $proxy.Value
            Write-Info "Scoop proxy -> $($proxy.Value) (session only)"
            return $true
        }
        return $false
    }
    if ($Disable) {
        scoop config rm proxy
        Write-Dim "    Scoop session proxy removed"
    }
}

function Ensure-ExtrasBucket {
    $buckets = scoop bucket list 2>$null | Select-Object -ExpandProperty Name -ErrorAction SilentlyContinue
    if ($buckets -contains 'extras') { return }
    
    Write-Step "Adding scoop extras bucket (this may take a while)"
    if ($China -and -not (Get-SystemProxy)) {
        scoop bucket add extras $script:SCOOP_CN_EXTRAS_REPO
    } else {
        scoop bucket add extras
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
    scoop config aria2-options '--check-certificate=false'
    Write-Info "aria2 enabled"
}

#===========================================
# Install Functions - Layer 2: Runtimes
#===========================================
function Install-Python {
    Write-Step "Installing Python"
    
    $pkg = "python"
    if ($PythonVersion) { $pkg = "python$PythonVersion" }
    
    $pythonInstalled = $false
    if (Test-PythonReal) {
        $pyOutput = python --version 2>&1
        $pythonInstalled = $true
        Write-Info "Python already installed ($pyOutput)"
    } else {
        $pycmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pycmd -and $pycmd.Source -match 'WindowsApps') {
            Write-Warn "Detected Windows Store stub, installing real Python via Scoop"
        }
    }
    
    if (-not $pythonInstalled) {
        scoop install $pkg
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        if (-not (Test-PythonReal)) {
            Write-Fail "Python installation failed"
            return
        }
        Test-InstallResult -Name "python" | Out-Null
    }
    
    # Only configure pip mirror when -China is specified
    if ($China -and (Test-Command pip)) {
        Write-Step "Configuring pip mirror"
        $pipDir = "$env:APPDATA\pip"
        if (-not (Test-Path $pipDir)) { New-Item -ItemType Directory -Path $pipDir -Force | Out-Null }
        $mirror = $script:CN_PIP_MIRROR
        $pipHost = ([uri]$mirror).Host
        $pipContent = "[global]`nindex-url = $mirror`ntrusted-host = $pipHost"
        Set-Content -Path "$pipDir\pip.ini" -Value $pipContent
        Write-Info "pip -> $mirror"
    }
    
    # Install uv (includes uvx)
    if (Test-Command pip) {
        if (-not (Test-Command uv)) {
            Write-Step "Installing uv"
            pip install uv
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            if (Test-Command uv) {
                Write-Info "uv installed ($(uv --version))"
            } else {
                Write-Warn "uv installation failed"
            }
        } else {
            Write-Info "uv already installed ($(uv --version))"
        }
    }
}

function Install-NodeJS {
    Write-Step "Installing Node.js"
    
    $pkg = "nodejs-lts"
    if ($NodeJSVersion) { $pkg = "nodejs$NodeJSVersion" }
    
    if (Test-Command node) {
        $nodeVer = node --version
        Write-Info "Node.js already installed ($nodeVer)"
    } else {
        scoop install $pkg
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Test-InstallResult -Name "node" | Out-Null
        if (-not (Test-Command npx)) {
            Write-Warn "npx not found, check Node.js installation"
        }
    }
    
    # Only configure npm mirror when -China is specified
    if ($China -and (Test-Command npm)) {
        Write-Step "Configuring npm mirror"
        $mirror = $script:CN_NPM_MIRROR
        npm config set registry $mirror
        Write-Info "npm -> $mirror"
    }
    
    # Enable pnpm via corepack
    # Node.js <=24: corepack is bundled; Node.js 25+: need to install corepack first
    if (-not (Test-Command pnpm)) {
        Write-Step "Enabling pnpm"
        if (-not (Test-Command corepack)) {
            Write-Dim "    Installing corepack..."
            npm install -g corepack
        }
        if (Test-Command corepack) {
            # China: use npm mirror for corepack download
            if ($China) {
                $env:COREPACK_NPM_REGISTRY = $script:CN_NPM_MIRROR
            }
            $env:COREPACK_ENABLE_AUTO_PIN = "0"
            corepack enable pnpm
        }
        if (Test-Command pnpm) {
            Write-Info "pnpm enabled ($(pnpm --version))"
        } else {
            Write-Warn "pnpm enable failed"
        }
    } else {
        Write-Info "pnpm already available ($(pnpm --version))"
    }
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
        Test-InstallResult -Name "go" -VersionCmd "go version" | Out-Null
    }
    
    # Ensure GOPATH\bin is in PATH
    if (Test-Command go) {
        $gopath = go env GOPATH 2>$null
        if ($gopath) {
            $gopathBin = Join-Path $gopath "bin"
            $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
            if ($currentPath -notmatch [regex]::Escape($gopathBin)) {
                [System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;$gopathBin", "User")
                $env:PATH = "$env:PATH;$gopathBin"
                Write-Info "Added $gopathBin to PATH"
            }
        }
    }
    
    if ($China) {
        Write-Step "Configuring Go proxy"
        $goProxy = $script:CN_GO_PROXY
        go env -w GOPROXY="$goProxy"
        Write-Info "GOPROXY -> $goProxy"
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
    Test-InstallResult -Name "cmake" -VersionCmd "cmake --version | Select-Object -First 1" | Out-Null
}

function Test-VCToolsInstalled {
    $pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $pf = [Environment]::GetFolderPath('ProgramFiles')
    
    $vswherePath = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswherePath) {
        $result = $null
        try {
            $result = & $vswherePath -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        } catch {}
        if ($result) { return $true }
    }
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
    
    if (-not $script:IsAdmin) {
        Write-Warn "Installing VS Build Tools requires Administrator privileges"
        Write-Host ""
        Write-Host "  Please re-run this script as Administrator, or install manually:" -ForegroundColor Yellow
        Write-Host "  https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor Cyan
        Write-Host ""
        return
    }
    
    $installed = $false
    
    # Method 1: Chocolatey
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
    
    # Method 2: winget
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
    
    # Method 3: Direct download
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
    
    $mirror = if ($China) { $script:CN_RUST_MIRROR } else { $null }
    
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
        Remove-Item $rustupInit -Force -ErrorAction SilentlyContinue
        
        # Refresh PATH from registry
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        # Also ensure long-path cargo bin is in PATH
        $cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
        if ((Test-Path $cargoBin) -and ($env:PATH -notmatch [regex]::Escape($cargoBin))) {
            $env:PATH = "$cargoBin;$env:PATH"
        }
        
        Test-InstallResult -Name "rustc" | Out-Null
    }
    
    if ($mirror) {
        Write-Step "Configuring Rust mirror"
        $cargoConfig = "$env:USERPROFILE\.cargo\config.toml"
        $cargoDir = "$env:USERPROFILE\.cargo"
        if (-not (Test-Path $cargoDir)) { New-Item -ItemType Directory -Path $cargoDir -Force | Out-Null }
        $cargoContent = "[source.crates-io]`nreplace-with = 'rsproxy'`n`n[source.rsproxy]`nregistry = `"$mirror/crates.io-index`""
        Set-Content -Path $cargoConfig -Value $cargoContent
        Write-Info "Cargo -> $mirror"
    }
}

#===========================================
# Install Functions - Layer 3: Dev Tools
#===========================================
function Install-Kiro {
    Write-Step "Installing Kiro"
    
    $kiroPath = "$env:LOCALAPPDATA\Programs\Kiro\Kiro.exe"
    if (Test-Path $kiroPath) {
        Write-Info "Kiro already installed"
        return
    }
    
    if (Test-Command kiro) {
        Write-Info "Kiro already installed (scoop)"
        return
    }
    
    Ensure-ExtrasBucket
    scoop install extras/kiro
    Write-Info "Kiro installed"
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
    
    Ensure-ExtrasBucket
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
    
    Ensure-ExtrasBucket
    scoop install extras/vscode
    Write-Info "VS Code installed"
}

#===========================================
# Command: install
#===========================================
function Invoke-Install {
    if ($China) {
        $region = "China Mirror"
    } else {
        $region = "Official"
    }
    
    if ($VibeCoding) {
        $Python = $true
        $NodeJS = $true
    }
    
    Write-Header "install - Setup [$region]"
    Write-Dim "  PowerShell $($PSVersionTable.PSVersion) | $(Get-AdminStatus) | $env:PROCESSOR_ARCHITECTURE"
    
    # Proxy detection
    $proxy = Get-SystemProxy
    $scoopProxySet = $false
    if ($proxy) {
        Write-Info "Proxy detected: $($proxy.Value) ($($proxy.Source))"
        if ($China) {
            Write-Warn "Proxy detected, -China mirror may not be needed"
        }
    }
    
    # Network check (no proxy and no -China)
    if (-not $China -and -not $proxy) {
        Test-Network
    }
    
    # ── Layer 1: Base Infrastructure (failure stops script) ──
    if ($China -and -not $proxy) {
        # China mode: Git first (winget/manual) → Scoop → mirror switch
        try {
            Install-Git
        } catch {
            Write-Fail "Git installation failed, cannot continue: $_"
            return
        }
        
        try {
            Install-Scoop
        } catch {
            Write-Fail "Scoop installation failed, cannot continue: $_"
            return
        }
        
        Set-ScoopChinaMirror
    } else {
        # Non-China mode (or with proxy): Scoop first → Git via Scoop/winget
        try {
            Install-Scoop
        } catch {
            Write-Fail "Scoop installation failed, cannot continue: $_"
            return
        }
        
        # Set Scoop proxy after Scoop is ready (session only)
        if ($proxy) { $scoopProxySet = Set-ScoopProxy -Enable }
        
        try {
            Install-Git
        } catch {
            Write-Fail "Git installation failed, cannot continue: $_"
            return
        }
    }
    
    if (-not $NoAria2) { Install-Aria2 }
    
    if ($ScoopOnly) {
        Write-Host ""
        Write-Info "Scoop installed (-ScoopOnly)"
        Write-Warn "Restart PowerShell to take effect"
        if ($scoopProxySet) { Set-ScoopProxy -Disable }
        return
    }
    
    # ── Layer 2: Runtimes (failure warns and continues) ──
    if ($Python -or $PythonVersion) {
        try { Install-Python } catch { Write-Warn "Python installation incomplete: $_" }
    }
    if ($NodeJS -or $NodeJSVersion) {
        try { Install-NodeJS } catch { Write-Warn "Node.js installation incomplete: $_" }
    }
    if ($VCTools) {
        try { Install-VCTools } catch { Write-Warn "VC Tools installation incomplete: $_" }
    }
    if ($CMake) {
        try { Install-CMake } catch { Write-Warn "CMake installation incomplete: $_" }
    }
    if ($Go -or $GoVersion) {
        try { Install-Go } catch { Write-Warn "Go installation incomplete: $_" }
    }
    if ($Rust) {
        try { Install-Rust } catch { Write-Warn "Rust installation incomplete: $_" }
    }
    
    # ── Layer 3: Dev Tools (failure warns and continues) ──
    if ($Kiro) {
        try { Install-Kiro } catch { Write-Warn "Kiro installation incomplete: $_" }
    }
    if ($Cursor) {
        try { Install-Cursor } catch { Write-Warn "Cursor installation incomplete: $_" }
    }
    if ($VSCode) {
        try { Install-VSCode } catch { Write-Warn "VS Code installation incomplete: $_" }
    }
    
    # Summary
    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host "Installation Complete" -ForegroundColor Green
    Write-Host ""
    if (Test-Command scoop) { Write-Host "  Scoop     installed" }
    if (($Python -or $PythonVersion) -and (Test-PythonReal)) { Write-Host "  Python    $((python --version 2>&1) -replace 'Python ', '')" }
    if (($NodeJS -or $NodeJSVersion) -and (Test-Command node)) { Write-Host "  Node.js   $(node --version)" }
    if ($CMake -and (Test-Command cmake)) { Write-Host "  CMake     $((cmake --version | Select-Object -First 1) -replace 'cmake version ', '')" }
    if ($VCTools -and (Test-VCToolsInstalled)) { Write-Host "  VC Tools  installed" }
    if (($Go -or $GoVersion) -and (Test-Command go)) { Write-Host "  Go        $((go version) -replace 'go version go', '' -replace ' .*', '')" }
    if ($Rust -and (Test-Command rustc)) { Write-Host "  Rust      $((rustc --version) -replace 'rustc ', '' -replace ' .*', '')" }
    if ($Kiro) { $kp = "$env:LOCALAPPDATA\Programs\Kiro\Kiro.exe"; if (Test-Path $kp) { Write-Host "  Kiro      installed" } }
    if ($Cursor -and ((Test-Path "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe") -or (Test-Command cursor))) { Write-Host "  Cursor    installed" }
    if ($VSCode -and ((Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or (Test-Command code))) { Write-Host "  VS Code   installed" }
    Write-Host ""
    Write-Warn "Restart PowerShell to take effect"
    
    # Tips for optional tools
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
    
    # Clean up session-only Scoop proxy
    if ($scoopProxySet) {
        Set-ScoopProxy -Disable
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
