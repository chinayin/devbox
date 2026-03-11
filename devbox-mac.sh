#!/bin/bash
#
# devbox-mac.sh - Mac 开发环境初始化脚本
# 项目: https://github.com/chinayin/devbox
# 协议: MIT
#

VERSION="v1.1"
PROJECT_URL="https://github.com/chinayin/devbox"

#===========================================
# 镜像源配置（默认官方源）
#===========================================
BREW_MIRROR=""
BREW_BOTTLE_MIRROR=""
PIP_MIRROR=""
NPM_MIRROR=""
GO_PROXY=""
RUST_MIRROR=""

# 中国镜像源
CN_BREW_MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
CN_BREW_BOTTLE="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
CN_BREW_INSTALL_SCRIPT="https://mirrors.ustc.edu.cn/misc/brew-install.sh"
CN_PIP_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
CN_NPM_MIRROR="https://registry.npmmirror.com"
CN_GO_PROXY="https://goproxy.cn,direct"
CN_RUST_MIRROR="https://rsproxy.cn"

OFFICIAL_BREW_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# 全局状态
SUDO_OK=false
USE_CHINA_MIRROR=false
BREW_ONLY=false
INSTALL_PYTHON=false
INSTALL_NODEJS=false
INSTALL_GO=false
INSTALL_RUST=false
INSTALL_CMAKE=false
INSTALL_KIRO=false
INSTALL_CURSOR=false
INSTALL_VSCODE=false
PYTHON_VERSION=""
NODEJS_VERSION=""
GO_VERSION=""

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

get_system_proxy() {
    if [[ -n "$HTTPS_PROXY" ]]; then
        echo "HTTPS_PROXY|$HTTPS_PROXY"
        return 0
    fi
    if [[ -n "$HTTP_PROXY" ]]; then
        echo "HTTP_PROXY|$HTTP_PROXY"
        return 0
    fi
    if [[ -n "$ALL_PROXY" ]]; then
        echo "ALL_PROXY|$ALL_PROXY"
        return 0
    fi
    return 1
}

#===========================================
# 检测函数
#===========================================

# 网络连通性检测（仅在无代理且未指定 --china 时调用）
check_network() {
    local unreachable=0
    for url in "https://github.com" "https://registry.npmjs.org"; do
        if ! curl -sI --connect-timeout 3 "$url" > /dev/null 2>&1; then
            unreachable=$((unreachable + 1))
        fi
    done
    if [[ $unreachable -gt 0 ]]; then
        warn "检测到部分境外源不可达，建议加 --china 参数使用镜像源"
    fi
}

# sudo 免密可用性检测
check_sudo() {
    if sudo -n true 2>/dev/null; then
        SUDO_OK=true
    else
        SUDO_OK=false
    fi
}

# Python3 真实性检测（macOS 14+ 可能是 Xcode CLT stub）
check_python_real() {
    if has python3; then
        if python3 -c "import sys" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

# 通用安装后验证
verify_install() {
    local cmd="$1" ver_cmd="${2:-$1 --version}"
    if has "$cmd"; then
        local ver=$(eval "$ver_cmd" 2>&1 | head -1)
        info "${cmd} 验证通过 (${ver})"
        return 0
    else
        fail "${cmd} 安装后未找到，请检查 PATH 配置"
        if [[ $(uname -m) == "arm64" ]] && has brew; then
            dim "    提示: Apple Silicon 请确认已执行 eval \"\$(/opt/homebrew/bin/brew shellenv)\""
        fi
        return 1
    fi
}

#===========================================
# 镜像配置
#===========================================
setup_china_mirror() {
    BREW_MIRROR="$CN_BREW_MIRROR"
    BREW_BOTTLE_MIRROR="$CN_BREW_BOTTLE"
    PIP_MIRROR="$CN_PIP_MIRROR"
    NPM_MIRROR="$CN_NPM_MIRROR"
    GO_PROXY="$CN_GO_PROXY"
    RUST_MIRROR="$CN_RUST_MIRROR"

    # 立即设置 Homebrew 环境变量（当前 session 生效，安装 brew 前必须 export）
    export HOMEBREW_BREW_GIT_REMOTE="${BREW_MIRROR}/git/homebrew/brew.git"
    export HOMEBREW_API_DOMAIN="${BREW_BOTTLE_MIRROR}/api"
    export HOMEBREW_BOTTLE_DOMAIN="${BREW_BOTTLE_MIRROR}"
}

# 统一持久化所有镜像配置到 shell rc
save_mirrors() {
    $USE_CHINA_MIRROR || return 0

    step "持久化镜像配置"
    local rc=$(get_shell_rc)

    # Homebrew 镜像（三组变量统一持久化）
    local brew_config="
# Homebrew 镜像 (devbox)
export HOMEBREW_BREW_GIT_REMOTE=\"${BREW_MIRROR}/git/homebrew/brew.git\"
export HOMEBREW_API_DOMAIN=\"${BREW_BOTTLE_MIRROR}/api\"
export HOMEBREW_BOTTLE_DOMAIN=\"${BREW_BOTTLE_MIRROR}\""

    append_if_missing "$rc" "$brew_config" "HOMEBREW_BOTTLE_DOMAIN"
    info "Homebrew 镜像已持久化"

    # Go 代理
    if has go && [[ -n "$GO_PROXY" ]]; then
        append_if_missing "$rc" "export GOPROXY=\"${GO_PROXY}\"" "GOPROXY"
        info "Go 代理已持久化"
    fi
}

#===========================================
# 帮助信息
#===========================================
show_help() {
    cat << EOF
Devbox ${VERSION}
Mac 一行命令搞定 AI 编程环境 | ${PROJECT_URL}

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
  --cmake           安装 CMake (node-llama-cpp 等需要)
  --kiro            安装 Kiro (AI IDE)
  --cursor          安装 Cursor (AI IDE)
  --vscode          安装 VS Code

通用选项:
  -h, --help        显示帮助信息
  -v, --version     显示版本信息

示例:
  ./devbox-mac.sh status                             # 检查当前环境
  ./devbox-mac.sh install --china --vibecoding       # AI 编程环境 (推荐)
  ./devbox-mac.sh install --china --python --nodejs  # 安装 Python + Node.js
  ./devbox-mac.sh install --china --python=3.12      # 指定 Python 版本
  ./devbox-mac.sh install --brew-only --china        # 只装 Homebrew
  ./devbox-mac.sh install --china --kiro             # 安装 Kiro
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

    # sudo 可用性
    if sudo -n true 2>/dev/null; then
        echo "  sudo       免密可用"
    else
        echo "  sudo       需要密码"
    fi

    # 代理信息
    local proxy_info=$(get_system_proxy)
    if [[ -n "$proxy_info" ]]; then
        local proxy_source=$(echo "$proxy_info" | cut -d'|' -f1)
        local proxy_value=$(echo "$proxy_info" | cut -d'|' -f2)
        printf "  Proxy      ${GREEN}%s${NC} ${GRAY}(%s)${NC}\n" "$proxy_value" "$proxy_source"
    fi

    section "基础工具"
    if xcode-select -p &>/dev/null; then
        info "Xcode CLI Tools"
        dim "    └─ 路径: $(xcode-select -p)"
    else
        fail "Xcode CLI Tools 未安装"
    fi

    if has brew; then
        local brew_ver=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
        info "Homebrew ${brew_ver}"
        dim "    ├─ 路径: $(which brew)"
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

    if has git; then
        local git_ver=$(git --version | awk '{print $3}')
        info "Git ${git_ver}"
        dim "    └─ 路径: $(which git)"
    else
        fail "Git 未安装"
    fi

    section "编程语言"
    if has python3; then
        if check_python_real; then
            info "Python $(python3 --version | awk '{print $2}')"
            dim "    ├─ 路径: $(which python3)"
            local pip_url=$(pip3 config get global.index-url 2>/dev/null)
            if [[ -n "$pip_url" && "$pip_url" != *"WARNING"* ]]; then
                dim "    ├─ pip:  $pip_url"
            else
                dim "    ├─ pip:  官方源"
            fi
            if has uv; then
                dim "    └─ uv:   $(uv --version 2>&1 | head -1)"
            fi
        else
            warn "Python (Xcode CLT stub，非真实 Python)"
        fi
    else
        dim "  Python 未安装"
    fi

    if has node; then
        info "Node.js $(node --version)"
        dim "    ├─ 路径: $(which node)"
        if has npm; then
            local npm_mirror=$(npm config get registry 2>/dev/null)
            dim "    └─ npm:  $npm_mirror"
        fi
        if ! has npx; then
            warn "    npx 未找到，请检查 Node.js 安装"
        fi
        if has pnpm; then
            dim "    └─ pnpm: $(pnpm --version)"
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

    section "构建工具"
    if has cmake; then
        local cmake_ver=$(cmake --version | head -1 | awk '{print $3}')
        info "CMake ${cmake_ver}"
        dim "    └─ 路径: $(which cmake)"
    else
        dim "  CMake 未安装"
    fi

    section "开发工具"
    if [[ -d "/Applications/Kiro.app" ]]; then
        info "Kiro"
        dim "    └─ 路径: /Applications/Kiro.app"
    else
        dim "  Kiro 未安装"
    fi

    if [[ -d "/Applications/Cursor.app" ]]; then
        info "Cursor"
        dim "    └─ 路径: /Applications/Cursor.app"
    else
        dim "  Cursor 未安装"
    fi

    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        info "VS Code"
        dim "    └─ 路径: /Applications/Visual Studio Code.app"
    else
        dim "  VS Code 未安装"
    fi

    echo ""
}

#===========================================
# 安装函数
#===========================================

parse_install_args() {
    for arg in "$@"; do
        case $arg in
            --china|-c)      USE_CHINA_MIRROR=true ;;
            --brew-only)     BREW_ONLY=true ;;
            --vibecoding)    INSTALL_PYTHON=true; INSTALL_NODEJS=true; INSTALL_CMAKE=true ;;
            --python=*)      INSTALL_PYTHON=true; PYTHON_VERSION="${arg#*=}" ;;
            --python)        INSTALL_PYTHON=true ;;
            --nodejs=*)      INSTALL_NODEJS=true; NODEJS_VERSION="${arg#*=}" ;;
            --nodejs)        INSTALL_NODEJS=true ;;
            --go=*)          INSTALL_GO=true; GO_VERSION="${arg#*=}" ;;
            --go)            INSTALL_GO=true ;;
            --rust)          INSTALL_RUST=true ;;
            --cmake)         INSTALL_CMAKE=true ;;
            --kiro)          INSTALL_KIRO=true ;;
            --cursor)        INSTALL_CURSOR=true ;;
            --vscode)        INSTALL_VSCODE=true ;;
        esac
    done
}

# ---- 第 1 层: Xcode CLT ----
install_xcode_clt() {
    step "安装 Xcode 命令行工具"

    if xcode-select -p &>/dev/null; then
        info "Xcode CLI Tools 已安装"
        return 0
    fi

    # 方式 A: sudo 可用，用 softwareupdate 静默安装（无 GUI 弹窗）
    if $SUDO_OK; then
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        local clt_label=$(softwareupdate --list 2>&1 | grep -o "Command Line Tools for Xcode-[0-9.]*" | sort -V | tail -1)
        if [[ -n "$clt_label" ]]; then
            info "找到安装包: $clt_label，正在安装..."
            sudo softwareupdate -i "$clt_label" --verbose
            rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
            if xcode-select -p &>/dev/null; then
                info "Xcode CLI Tools 安装完成"
                return 0
            fi
        fi
        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        warn "softwareupdate 安装失败，回退到 GUI 弹窗方式"
    fi

    # 方式 B: fallback 到 GUI 弹窗（sudo 不可用或方式 A 失败）
    warn "需要手动安装 Xcode 命令行工具"
    xcode-select --install 2>/dev/null || true
    echo "请在弹出的窗口中点击「安装」，完成后按回车继续..."
    read -r -p ""

    # 验证
    if xcode-select -p &>/dev/null; then
        info "Xcode CLI Tools 安装完成"
        return 0
    else
        fail "Xcode CLI Tools 安装失败"
        return 1
    fi
}

# ---- 第 1 层: Homebrew ----
install_homebrew() {
    step "安装 Homebrew"

    if has brew; then
        local brew_ver=$(brew --version 2>/dev/null | head -1 || echo "unknown")
        info "Homebrew 已安装 (${brew_ver})"
        return 0
    fi

    if [[ -n "$BREW_MIRROR" ]]; then
        # 中国镜像: 用中科大一行式脚本（不依赖 git）
        export HOMEBREW_CORE_GIT_REMOTE="${BREW_MIRROR}/git/homebrew/homebrew-core.git"
        export HOMEBREW_INSTALL_FROM_API=1
        /bin/bash -c "$(curl -fsSL ${CN_BREW_INSTALL_SCRIPT})"
    else
        /bin/bash -c "$(curl -fsSL ${OFFICIAL_BREW_URL})"
    fi

    # Apple Silicon / Intel PATH 配置
    local rc=$(get_shell_rc)
    if [[ $(uname -m) == "arm64" ]]; then
        append_if_missing "$rc" 'eval "$(/opt/homebrew/bin/brew shellenv)"' "/opt/homebrew"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        append_if_missing "$rc" 'eval "$(/usr/local/bin/brew shellenv)"' "/usr/local"
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    verify_install "brew" "brew --version | head -1"
}

# ---- 第 2 层: Python ----
install_python() {
    step "安装 Python"
    local pkg="python"
    [[ -n "$PYTHON_VERSION" ]] && pkg="python@${PYTHON_VERSION}"

    # 检测是否已有真实 Python（非 Xcode CLT stub）
    if brew list "$pkg" &>/dev/null && check_python_real; then
        info "Python 已安装 ($(python3 --version))"
    else
        if has python3 && ! check_python_real; then
            warn "检测到 python3 为 Xcode CLT stub，将通过 Homebrew 安装真实 Python"
        fi
        brew install "$pkg" || { fail "Python 安装失败"; return 1; }
    fi

    verify_install "python3" "python3 --version" || return 1

    # 仅在使用中国镜像时配置 pip
    if $USE_CHINA_MIRROR && has pip3; then
        step "配置 pip 镜像"
        pip3 config set global.index-url "$PIP_MIRROR" 2>/dev/null || true
        pip3 config set global.trusted-host "$(echo $PIP_MIRROR | sed 's|https\?://||;s|/.*||')" 2>/dev/null || true
        info "pip → $PIP_MIRROR"
    fi

    # 安装 uv (包含 uvx)
    if has pip3; then
        if ! has uv; then
            step "安装 uv"
            pip3 install uv || { warn "uv 安装失败"; return 0; }
            verify_install "uv" "uv --version"
        else
            info "uv 已安装 ($(uv --version 2>&1 | head -1))"
        fi
    fi
}

# ---- 第 2 层: Node.js ----
install_nodejs() {
    step "安装 Node.js"
    local pkg="node"
    [[ -n "$NODEJS_VERSION" ]] && pkg="node@${NODEJS_VERSION}"

    if brew list "$pkg" &>/dev/null; then
        info "Node.js 已安装 ($(node --version))"
    else
        brew install "$pkg" || { fail "Node.js 安装失败"; return 1; }
    fi

    verify_install "node" "node --version" || return 1

    # 仅在使用中国镜像时配置 npm registry
    if $USE_CHINA_MIRROR && has npm; then
        step "配置 npm 镜像"
        npm config set registry "$NPM_MIRROR"
        info "npm → $NPM_MIRROR"
    fi

    # 启用 pnpm (corepack)
    # Node.js <=24: corepack 内置; Node.js 25+: 需先 npm install -g corepack
    if ! has pnpm; then
        step "启用 pnpm"
        if ! has corepack; then
            dim "    安装 corepack..."
            npm install -g corepack || { warn "corepack 安装失败"; return 0; }
        fi
        corepack enable pnpm || { warn "pnpm 启用失败"; return 0; }
        verify_install "pnpm" "pnpm --version"
    else
        info "pnpm 已安装 ($(pnpm --version))"
    fi
}

# ---- 第 2 层: Go ----
install_go() {
    step "安装 Go"
    local pkg="go"
    [[ -n "$GO_VERSION" ]] && pkg="go@${GO_VERSION}"

    if brew list "$pkg" &>/dev/null; then
        info "Go 已安装 ($(go version))"
    else
        brew install "$pkg" || { fail "Go 安装失败"; return 1; }
    fi

    verify_install "go" "go version" || return 1

    # 确保 ~/go/bin 在 PATH 中
    local rc=$(get_shell_rc)
    append_if_missing "$rc" 'export PATH="$HOME/go/bin:$PATH"' 'go/bin'
    export PATH="$HOME/go/bin:$PATH"

    if [[ -n "$GO_PROXY" ]]; then
        step "配置 Go 代理"
        go env -w GOPROXY="$GO_PROXY"
        info "GOPROXY → $GO_PROXY"
    fi
}

# ---- 第 2 层: Rust ----
install_rust() {
    step "安装 Rust"

    if has rustc; then
        info "Rust 已安装 ($(rustc --version))"
    else
        if [[ -n "$RUST_MIRROR" ]]; then
            export RUSTUP_DIST_SERVER="$RUST_MIRROR"
            export RUSTUP_UPDATE_ROOT="${RUST_MIRROR}/rustup"
        fi
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || { fail "Rust 安装失败"; return 1; }
        source "$HOME/.cargo/env"
    fi

    verify_install "rustc" "rustc --version" || return 1

    if [[ -n "$RUST_MIRROR" ]]; then
        step "配置 Rust 镜像"
        mkdir -p ~/.cargo
        cat > ~/.cargo/config.toml << EOF
[source.crates-io]
replace-with = 'rsproxy'

[source.rsproxy]
registry = "${RUST_MIRROR}/crates.io-index"
EOF
        info "Cargo → $RUST_MIRROR"
    fi
}

# ---- 第 2 层: CMake ----
install_cmake() {
    step "安装 CMake"

    if has cmake; then
        local cmake_ver=$(cmake --version | head -1 | awk '{print $3}')
        info "CMake 已安装 (${cmake_ver})"
        return 0
    fi

    brew install cmake || { fail "CMake 安装失败"; return 1; }
    verify_install "cmake" "cmake --version | head -1"
}

# ---- 第 3 层: 开发工具 ----
install_kiro() {
    step "安装 Kiro"

    if [[ -d "/Applications/Kiro.app" ]]; then
        info "Kiro 已安装"
        return 0
    fi

    brew install --cask kiro || { fail "Kiro 安装失败"; return 1; }
    info "Kiro 安装完成"
}

install_cursor() {
    step "安装 Cursor"

    if [[ -d "/Applications/Cursor.app" ]]; then
        info "Cursor 已安装"
        return 0
    fi

    brew install --cask cursor || { fail "Cursor 安装失败"; return 1; }
    info "Cursor 安装完成"
}

install_vscode() {
    step "安装 VS Code"

    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        info "VS Code 已安装"
        return 0
    fi

    brew install --cask visual-studio-code || { fail "VS Code 安装失败"; return 1; }
    info "VS Code 安装完成"
}

#===========================================
# 命令: install (安装环境)
#===========================================
cmd_install() {
    parse_install_args "$@"

    # 设置镜像源
    if $USE_CHINA_MIRROR; then
        setup_china_mirror
        local region="中国镜像"
    else
        local region="官方源"
    fi

    show_header "install - 环境安装 [$region]"

    # 代理检测
    local proxy_info=$(get_system_proxy)
    if [[ -n "$proxy_info" ]]; then
        local proxy_source=$(echo "$proxy_info" | cut -d'|' -f1)
        local proxy_value=$(echo "$proxy_info" | cut -d'|' -f2)
        info "检测到代理: $proxy_value ($proxy_source)"
        if $USE_CHINA_MIRROR; then
            warn "已有代理，可能不需要 --china 镜像"
        fi
    fi

    # 网络检测（无代理且未指定镜像时）
    if ! $USE_CHINA_MIRROR && [[ -z "$proxy_info" ]]; then
        check_network
    fi

    # sudo 检测
    check_sudo

    # ── 第 1 层: 基础设施（失败则停止）──
    install_xcode_clt || { fail "Xcode CLT 安装失败，无法继续"; exit 1; }
    install_homebrew  || { fail "Homebrew 安装失败，无法继续"; exit 1; }
    save_mirrors

    if $BREW_ONLY; then
        echo ""
        info "Homebrew 安装完成 (--brew-only)"
        warn "运行 source $(get_shell_rc) 或重开终端生效"
        return 0
    fi

    # ── 第 2 层: 运行时（失败则警告继续）──
    $INSTALL_PYTHON && { install_python || warn "Python 安装未完成"; }
    $INSTALL_NODEJS && { install_nodejs || warn "Node.js 安装未完成"; }
    $INSTALL_CMAKE  && { install_cmake  || warn "CMake 安装未完成"; }
    $INSTALL_GO     && { install_go     || warn "Go 安装未完成"; }
    $INSTALL_RUST   && { install_rust   || warn "Rust 安装未完成"; }

    # ── 第 3 层: 开发工具 ──
    $INSTALL_KIRO   && { install_kiro   || warn "Kiro 安装未完成"; }
    $INSTALL_CURSOR && { install_cursor || warn "Cursor 安装未完成"; }
    $INSTALL_VSCODE && { install_vscode || warn "VS Code 安装未完成"; }

    # 安装摘要
    echo ""
    echo "────────────────────────────────────────"
    printf "${GREEN}安装完成${NC}\n"
    echo ""
    local brew_ver=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "")
    echo "  Homebrew  ${brew_ver}"
    $INSTALL_PYTHON && echo "  Python    $(python3 --version 2>/dev/null | awk '{print $2}')"
    $INSTALL_NODEJS && echo "  Node.js   $(node --version 2>/dev/null)"
    $INSTALL_CMAKE  && echo "  CMake     $(cmake --version 2>/dev/null | head -1 | awk '{print $3}')"
    $INSTALL_GO     && echo "  Go        $(go version 2>/dev/null | awk '{print $3}')"
    $INSTALL_RUST   && echo "  Rust      $(rustc --version 2>/dev/null | awk '{print $2}')"
    $INSTALL_KIRO   && echo "  Kiro      ✓"
    $INSTALL_CURSOR && echo "  Cursor    ✓"
    $INSTALL_VSCODE && echo "  VS Code   ✓"
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
