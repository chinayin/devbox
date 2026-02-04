#!/bin/bash
#
# devbox-mac.sh - Mac 开发环境初始化脚本
# 项目: https://github.com/chinaiyn/devbox
# 协议: MIT
#

set -e

VERSION="v0.1"
PROJECT_URL="https://github.com/chinaiyn/devbox"

#===========================================
# 镜像源配置
#===========================================
CN_BREW_MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
CN_PIP_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
CN_NPM_MIRROR="https://registry.npmmirror.com"

OFFICIAL_BREW_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
OFFICIAL_PIP_MIRROR="https://pypi.org/simple"
OFFICIAL_NPM_MIRROR="https://registry.npmjs.org"

#===========================================
# 工具函数
#===========================================
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; GRAY='\033[0;90m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { printf "${GREEN}✓${NC} %s\n" "$1"; }
fail() { printf "${RED}✗${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$1"; }
dim() { printf "${GRAY}%s${NC}\n" "$1"; }
step() { printf "\n${CYAN}==>${NC} ${BOLD}%s${NC}\n" "$1"; }

section() {
    local title="$1"
    echo ""
    printf "${BOLD}%s${NC}\n" "$title"
    echo "────────────────────────────────────────"
}

show_header() {
    local subtitle="$1"
    echo ""
    printf "${BOLD}Devbox${NC} ${VERSION}\n"
    printf "${GRAY}${PROJECT_URL}${NC}\n"
    echo "────────────────────────────────────────"
    printf "${CYAN}${subtitle}${NC}\n"
}

has() { command -v "$1" &>/dev/null; }

get_shell_rc() {
    case "$SHELL" in
        */zsh)  echo ~/.zshrc ;;
        */bash) echo ~/.bash_profile ;;
        *)      echo ~/.profile ;;
    esac
}

append_if_missing() {
    local file="$1" content="$2" marker="$3"
    [[ -f "$file" ]] || touch "$file"
    grep -q "$marker" "$file" 2>/dev/null || echo "$content" >> "$file"
}

#===========================================
# 帮助信息
#===========================================
show_help() {
    cat << EOF
Devbox ${VERSION}
Mac 开发环境初始化脚本 | ${PROJECT_URL}

用法: ./devbox-mac.sh <命令> [选项]

命令:
  install     安装开发环境
  status      检查安装状态

install 选项:
  --china, -c       使用中国镜像源 (清华/淘宝)
  --brew-only       只安装 Homebrew
  --vibecoding      安装 AI 编程环境 (Python + Node.js)
  --python[=版本]   安装 Python (如 --python=3.12)
  --nodejs[=版本]   安装 Node.js (如 --nodejs=24)
  --go[=版本]       安装 Go (如 --go=1.25)
  --rust            安装 Rust

通用选项:
  -h, --help        显示帮助信息
  -v, --version     显示版本信息

示例:
  ./devbox-mac.sh status                             # 检查当前环境
  ./devbox-mac.sh install --china --vibecoding       # AI 编程环境 (推荐)
  ./devbox-mac.sh install --china --python --nodejs  # 安装 Python + Node.js
  ./devbox-mac.sh install --china --python=3.12      # 指定 Python 版本
  ./devbox-mac.sh install --brew-only --china        # 只装 Homebrew
EOF
    exit 0
}

show_version() {
    echo "Devbox ${VERSION}"
    exit 0
}

#===========================================
# 命令: status (检查环境)
#===========================================
cmd_status() {
    show_header "status - 环境检查"

    section "系统信息"
    echo "  macOS      $(sw_vers -productVersion)"
    echo "  芯片       $(uname -m)"
    echo "  Shell      $(basename $SHELL)"
    echo "  配置文件   $(get_shell_rc)"

    section "基础工具"
    if has brew; then
        local brew_ver=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
        info "Homebrew ${brew_ver}"
        dim "    ├─ 路径: $(which brew)"
        # 从配置文件检测镜像
        local rc=$(get_shell_rc)
        local brew_mirror=$(grep "HOMEBREW_BOTTLE_DOMAIN" "$rc" 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' | tail -1)
        if [[ -n "$brew_mirror" ]]; then
            dim "    └─ 镜像: $brew_mirror"
        elif [[ -n "$HOMEBREW_BOTTLE_DOMAIN" ]]; then
            dim "    └─ 镜像: $HOMEBREW_BOTTLE_DOMAIN"
        else
            dim "    └─ 镜像: 官方源"
        fi
    else
        fail "Homebrew 未安装"
    fi

    if xcode-select -p &>/dev/null; then
        info "Xcode CLI Tools"
    else
        fail "Xcode CLI Tools 未安装"
    fi

    section "编程语言"
    if has python3; then
        info "Python $(python3 --version | awk '{print $2}')"
        dim "    ├─ 路径: $(which python3)"
        if [[ -f ~/.pip/pip.conf ]]; then
            pip_mirror=$(grep "index-url" ~/.pip/pip.conf 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            dim "    └─ pip:  $pip_mirror"
        else
            dim "    └─ pip:  官方源"
        fi
    else
        dim "  Python 未安装"
    fi

    if has node; then
        info "Node.js $(node --version)"
        dim "    ├─ 路径: $(which node)"
        if has npm; then
            npm_mirror=$(npm config get registry 2>/dev/null)
            dim "    └─ npm:  $npm_mirror"
        fi
    else
        dim "  Node.js 未安装"
    fi

    if has go; then
        info "Go $(go version | awk '{print $3}' | sed 's/go//')"
        dim "    ├─ 路径: $(which go)"
        dim "    └─ proxy: $(go env GOPROXY 2>/dev/null)"
    else
        dim "  Go 未安装"
    fi

    if has rustc; then
        info "Rust $(rustc --version | awk '{print $2}')"
        dim "    └─ 路径: $(which rustc)"
    else
        dim "  Rust 未安装"
    fi
    echo ""
}

#===========================================
# 命令: install (安装环境)
#===========================================
USE_CHINA_MIRROR=false
BREW_ONLY=false
INSTALL_PYTHON=false
INSTALL_NODEJS=false
INSTALL_GO=false
INSTALL_RUST=false
PYTHON_VERSION=""
NODEJS_VERSION=""
GO_VERSION=""

parse_install_args() {
    for arg in "$@"; do
        case $arg in
            --china|-c)      USE_CHINA_MIRROR=true ;;
            --brew-only)     BREW_ONLY=true ;;
            --vibecoding)    INSTALL_PYTHON=true; INSTALL_NODEJS=true ;;
            --python=*)      INSTALL_PYTHON=true; PYTHON_VERSION="${arg#*=}" ;;
            --python)        INSTALL_PYTHON=true ;;
            --nodejs=*)      INSTALL_NODEJS=true; NODEJS_VERSION="${arg#*=}" ;;
            --nodejs)        INSTALL_NODEJS=true ;;
            --go=*)          INSTALL_GO=true; GO_VERSION="${arg#*=}" ;;
            --go)            INSTALL_GO=true ;;
            --rust)          INSTALL_RUST=true ;;
        esac
    done

    if $USE_CHINA_MIRROR; then
        BREW_MIRROR="$CN_BREW_MIRROR"
        PIP_MIRROR="$CN_PIP_MIRROR"
        NPM_MIRROR="$CN_NPM_MIRROR"
        REGION="中国镜像"
    else
        BREW_MIRROR=""
        PIP_MIRROR="$OFFICIAL_PIP_MIRROR"
        NPM_MIRROR="$OFFICIAL_NPM_MIRROR"
        REGION="官方源"
    fi
}

install_homebrew() {
    step "安装 Homebrew"
    
    if has brew; then
        local brew_ver=$(brew --version 2>/dev/null | head -1 || echo "unknown")
        info "Homebrew 已安装 (${brew_ver})"
        return 0
    fi
    
    if ! xcode-select -p &>/dev/null; then
        warn "需要先安装 Xcode 命令行工具"
        xcode-select --install 2>/dev/null || true
        read -p "安装完成后按回车继续..."
    fi
    
    if $USE_CHINA_MIRROR; then
        export HOMEBREW_BREW_GIT_REMOTE="${BREW_MIRROR}/git/homebrew/brew.git"
        export HOMEBREW_CORE_GIT_REMOTE="${BREW_MIRROR}/git/homebrew/homebrew-core.git"
        export HOMEBREW_INSTALL_FROM_API=1
        /bin/bash -c "$(curl -fsSL ${BREW_MIRROR}/git/homebrew/install/HEAD/install.sh)"
    else
        /bin/bash -c "$(curl -fsSL ${OFFICIAL_BREW_URL})"
    fi
    
    local rc=$(get_shell_rc)
    if [[ $(uname -m) == "arm64" ]]; then
        append_if_missing "$rc" 'eval "$(/opt/homebrew/bin/brew shellenv)"' "/opt/homebrew"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        append_if_missing "$rc" 'eval "$(/usr/local/bin/brew shellenv)"' "/usr/local"
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    info "Homebrew 安装完成"
}

config_homebrew_mirror() {
    $USE_CHINA_MIRROR || return 0
    
    step "配置 Homebrew 镜像"
    local rc=$(get_shell_rc)
    local config="
# Homebrew 镜像
export HOMEBREW_API_DOMAIN=\"${BREW_MIRROR}/homebrew-bottles/api\"
export HOMEBREW_BOTTLE_DOMAIN=\"${BREW_MIRROR}/homebrew-bottles\""
    
    append_if_missing "$rc" "$config" "HOMEBREW_BOTTLE_DOMAIN"
    export HOMEBREW_API_DOMAIN="${BREW_MIRROR}/homebrew-bottles/api"
    export HOMEBREW_BOTTLE_DOMAIN="${BREW_MIRROR}/homebrew-bottles"
    info "Homebrew 镜像已配置"
}

install_python() {
    step "安装 Python"
    local pkg="python"
    [[ -n "$PYTHON_VERSION" ]] && pkg="python@${PYTHON_VERSION}"
    
    if brew list "$pkg" &>/dev/null; then
        info "Python 已安装 ($(python3 --version))"
    else
        brew install "$pkg"
        info "Python 安装完成 ($(python3 --version))"
    fi
    
    step "配置 pip 镜像"
    mkdir -p ~/.pip ~/.config/pip
    local host=$(echo $PIP_MIRROR | sed 's|https\?://||;s|/.*||')
    cat > ~/.pip/pip.conf << EOF
[global]
index-url = ${PIP_MIRROR}
trusted-host = ${host}
EOF
    cp ~/.pip/pip.conf ~/.config/pip/pip.conf
    info "pip → $PIP_MIRROR"
}

install_nodejs() {
    step "安装 Node.js"
    local pkg="node"
    [[ -n "$NODEJS_VERSION" ]] && pkg="node@${NODEJS_VERSION}"
    
    if brew list "$pkg" &>/dev/null; then
        info "Node.js 已安装 ($(node --version))"
    else
        brew install "$pkg"
        info "Node.js 安装完成 ($(node --version))"
    fi
    
    step "配置 npm 镜像"
    npm config set registry "$NPM_MIRROR"
    info "npm → $NPM_MIRROR"
}

install_go() {
    step "安装 Go"
    local pkg="go"
    [[ -n "$GO_VERSION" ]] && pkg="go@${GO_VERSION}"
    
    if brew list "$pkg" &>/dev/null; then
        info "Go 已安装 ($(go version))"
    else
        brew install "$pkg"
        info "Go 安装完成 ($(go version))"
    fi
    
    if $USE_CHINA_MIRROR; then
        step "配置 Go 镜像"
        go env -w GOPROXY=https://goproxy.cn,direct
        info "GOPROXY → https://goproxy.cn"
    fi
}

install_rust() {
    step "安装 Rust"
    
    if has rustc; then
        info "Rust 已安装 ($(rustc --version))"
    else
        if $USE_CHINA_MIRROR; then
            export RUSTUP_DIST_SERVER="https://rsproxy.cn"
            export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
        fi
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        info "Rust 安装完成 ($(rustc --version))"
    fi
    
    if $USE_CHINA_MIRROR; then
        step "配置 Rust 镜像"
        mkdir -p ~/.cargo
        cat > ~/.cargo/config << 'EOF'
[source.crates-io]
replace-with = 'rsproxy'

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"
EOF
        info "Cargo → rsproxy.cn"
    fi
}

cmd_install() {
    parse_install_args "$@"
    
    show_header "install - 环境安装 [$REGION]"
    
    install_homebrew
    config_homebrew_mirror
    
    if $BREW_ONLY; then
        echo ""
        info "Homebrew 安装完成 (--brew-only)"
        warn "运行 source $(get_shell_rc) 或重开终端生效"
        return 0
    fi
    
    # 确保镜像配置在 brew install 前生效
    if $USE_CHINA_MIRROR; then
        export HOMEBREW_API_DOMAIN="${CN_BREW_MIRROR}/homebrew-bottles/api"
        export HOMEBREW_BOTTLE_DOMAIN="${CN_BREW_MIRROR}/homebrew-bottles"
    fi
    
    $INSTALL_PYTHON && install_python
    $INSTALL_NODEJS && install_nodejs
    $INSTALL_GO && install_go
    $INSTALL_RUST && install_rust
    
    echo ""
    echo "────────────────────────────────────────"
    printf "${GREEN}安装完成${NC}\n"
    echo ""
    local brew_ver=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "")
    echo "  Homebrew  ${brew_ver}"
    $INSTALL_PYTHON && echo "  Python    $(python3 --version 2>/dev/null | awk '{print $2}')"
    $INSTALL_NODEJS && echo "  Node.js   $(node --version 2>/dev/null)"
    $INSTALL_GO && echo "  Go        $(go version 2>/dev/null | awk '{print $3}')"
    $INSTALL_RUST && echo "  Rust      $(rustc --version 2>/dev/null | awk '{print $2}')"
    echo ""
    warn "运行 source $(get_shell_rc) 或重开终端生效"
}

#===========================================
# 主入口
#===========================================
main() {
    local cmd="${1:-}"
    shift 2>/dev/null || true
    
    case "$cmd" in
        install)        cmd_install "$@" ;;
        status)         cmd_status ;;
        -h|--help|help) show_help ;;
        -v|--version)   show_version ;;
        *)              show_help ;;
    esac
}

main "$@"
