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
    [switch]$ScoopOnly
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
$script:VERSION = "v0.1"
$script:PROJECT_URL = "https://github.com/chinayin/devbox"

# Mirror configuration
$script:SCOOP_MIRROR = ""
$script:PIP_MIRROR = "https://pypi.org/simple"
$script:NPM_MIRROR = "https://registry.npmjs.org"
$script:GO_PROXY = ""
$script:RUST_MIRROR = ""

# China mirrors
$script:CN_SCOOP_MIRROR = "https://gitee.com/scoop-installer"
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
    Write-Host "devbox " -ForegroundColor White -NoNewline
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
    $script:SCOOP_MIRROR = $script:CN_SCOOP_MIRROR
    $script:PIP_MIRROR = $script:CN_PIP_MIRROR
    $script:NPM_MIRROR = $script:CN_NPM_MIRROR
    $script:GO_PROXY = $script:CN_GO_PROXY
    $script:RUST_MIRROR = $script:CN_RUST_MIRROR
}

#===========================================
# Help
#===========================================
function Show-Help {
    @"
devbox $script:VERSION
Windows Development Environment Setup | $script:PROJECT_URL

Usage: .\devbox-win.ps1 <command> [options]

Commands:
  install     Install development environment
  status      Check installation status
  help        Show this help

Install Options:
  -China, -c          Use China mirrors (Tsinghua/Taobao/Gitee)
  -ScoopOnly          Only install Scoop
  -VibeCoding         Install AI coding environment (Python + Node.js)
  -Python             Install Python
  -PythonVersion      Specify Python version (e.g. 3.12)
  -NodeJS             Install Node.js
  -NodeJSVersion      Specify Node.js version (e.g. 20)
  -Go                 Install Go
  -GoVersion          Specify Go version
  -Rust               Install Rust

Examples:
  .\devbox-win.ps1 status                           # Check environment
  .\devbox-win.ps1 install -China -VibeCoding       # AI coding (recommended)
  .\devbox-win.ps1 install -China -Python -NodeJS   # Install Python + Node.js
  .\devbox-win.ps1 install -ScoopOnly -China        # Only install Scoop
"@
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
        $scoopVer = (scoop --version 2>$null | Select-Object -First 1) -replace 'v', ''
        Write-Info "Scoop $scoopVer"
        Write-Dim "    Path: $(Get-Command scoop | Select-Object -ExpandProperty Source)"
        $scoopConfig = scoop config 2>$null
        if ($scoopConfig -match 'SCOOP_REPO') {
            Write-Dim "    Mirror: Configured"
        } else {
            Write-Dim "    Mirror: Official"
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
    
    Write-Host ""
}

#===========================================
# Install Functions
#===========================================
function Install-Scoop {
    Write-Step "Installing Scoop"
    
    if (Test-Command scoop) {
        $scoopVer = scoop --version 2>$null | Select-Object -First 1
        Write-Info "Scoop already installed ($scoopVer)"
        return
    }
    
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    
    # Debug info
    Write-Dim "    IsAdmin: $($script:IsAdmin)"
    Write-Dim "    SCOOP_MIRROR: $($script:SCOOP_MIRROR)"
    
    # Auto-detect admin and pass -RunAsAdmin to install script
    if ($script:IsAdmin) {
        Write-Info "Admin detected, installing globally"
        if ($script:SCOOP_MIRROR) {
            Write-Dim "    Using mirror with -RunAsAdmin"
            $env:SCOOP_REPO = "$script:SCOOP_MIRROR/scoop"
            $installUrl = "$script:SCOOP_MIRROR/scoop/raw/master/bin/install.ps1"
            Write-Dim "    Install URL: $installUrl"
            iex "& {$(irm $installUrl)} -RunAsAdmin"
        } else {
            Write-Dim "    Using official with -RunAsAdmin"
            iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
        }
    } else {
        Write-Info "User mode, installing to user directory"
        if ($script:SCOOP_MIRROR) {
            Write-Dim "    Using mirror"
            $env:SCOOP_REPO = "$script:SCOOP_MIRROR/scoop"
            irm "$script:SCOOP_MIRROR/scoop/raw/master/bin/install.ps1" | iex
        } else {
            Write-Dim "    Using official"
            irm get.scoop.sh | iex
        }
    }
    
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    
    Write-Info "Scoop installed"
}

function Install-Git {
    Write-Step "Installing Git"
    
    if (Test-Command git) {
        $gitVer = git --version
        Write-Info "Git already installed ($gitVer)"
        return
    }
    
    scoop install git
    Write-Info "Git installed"
}

function Save-ScoopMirror {
    Write-Step "Configuring Scoop bucket"
    
    if ($script:SCOOP_MIRROR) {
        scoop config SCOOP_REPO "$script:SCOOP_MIRROR/scoop"
        
        $env:GIT_TERMINAL_PROMPT = "0"
        
        scoop bucket rm main 2>$null
        scoop update 2>$null
        scoop bucket add main "$script:SCOOP_MIRROR/Main" 2>$null
        
        Remove-Item Env:GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue
        
        $buckets = scoop bucket list 2>$null
        if ($buckets -match 'main') {
            Write-Info "Scoop mirror configured (Gitee)"
            return
        }
        
        Write-Warn "Gitee mirror unavailable, falling back to official"
    }
    
    $buckets = scoop bucket list 2>$null
    if ($buckets -match 'main') {
        Write-Info "main bucket exists"
        return
    }
    
    scoop bucket add main
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add Scoop main bucket"
    }
    Write-Info "Scoop main bucket configured"
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
    @"
[global]
index-url = $mirror
trusted-host = $pipHost
"@ | Set-Content "$pipDir\pip.ini"
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
        @"
[source.crates-io]
replace-with = 'rsproxy'

[source.rsproxy]
registry = "$mirror/crates.io-index"
"@ | Set-Content $cargoConfig
        Write-Info "Cargo -> $mirror"
    }
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
    }
    
    Write-Header "install - Setup [$region]"
    
    $proxy = Get-SystemProxy
    if ($proxy) {
        Write-Info "Proxy detected: $($proxy.Value) ($($proxy.Source))"
        if ($China) {
            Write-Warn "Proxy detected, -China mirror may not be needed"
        }
    }
    
    Install-Scoop
    Install-Git
    Save-ScoopMirror
    
    if ($ScoopOnly) {
        Write-Host ""
        Write-Info "Scoop installed (-ScoopOnly)"
        Write-Warn "Restart PowerShell to take effect"
        return
    }
    
    if ($Python -or $PythonVersion) { Install-Python }
    if ($NodeJS -or $NodeJSVersion) { Install-NodeJS }
    if ($Go -or $GoVersion) { Install-Go }
    if ($Rust) { Install-Rust }
    
    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host "Installation Complete" -ForegroundColor Green
    Write-Host ""
    if (Test-Command scoop) { Write-Host "  Scoop     $((scoop --version 2>$null | Select-Object -First 1) -replace 'v', '')" }
    if ($Python -and (Test-Command python)) { Write-Host "  Python    $((python --version 2>&1) -replace 'Python ', '')" }
    if ($NodeJS -and (Test-Command node)) { Write-Host "  Node.js   $(node --version)" }
    if ($Go -and (Test-Command go)) { Write-Host "  Go        $((go version) -replace 'go version go', '' -replace ' .*', '')" }
    if ($Rust -and (Test-Command rustc)) { Write-Host "  Rust      $((rustc --version) -replace 'rustc ', '' -replace ' .*', '')" }
    Write-Host ""
    Write-Warn "Restart PowerShell to take effect"
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
