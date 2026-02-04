# devbox

Mac 开发环境一键初始化脚本，专为 AI/Vibe Coding 新手设计。

自动安装 Homebrew、Python、Node.js 等开发工具，国内用户自动配置清华/淘宝镜像源。

---

## 一键安装

打开终端，复制粘贴以下命令：

**国内用户（推荐）**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/chinaiyn/devbox/master/devbox-mac.sh)" -- install --china --vibecoding
```

**海外用户**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/chinaiyn/devbox/master/devbox-mac.sh)" -- install --vibecoding
```

> 这会安装 Homebrew + Python + Node.js，国内用户自动配置镜像加速。

---

## 这是什么？

如果你是编程新手，想要开始 AI 编程或 Vibe Coding，你需要先安装一些开发工具。

这个脚本帮你自动完成这些事情：

| 工具 | 用途 |
|------|------|
| Homebrew | Mac 软件包管理器，用来安装其他工具 |
| Python | AI 和数据科学的主流语言 |
| Node.js | 前端开发和很多 AI 工具需要它 |
| Go | 高性能后端开发（可选） |
| Rust | 系统级编程语言（可选） |

---

## 使用方法

### 检查当前环境

```bash
./devbox-mac.sh status
```

输出示例：
```
devbox v0.1
https://github.com/chinaiyn/devbox
────────────────────────────────────────
status - 环境检查

系统信息
────────────────────────────────────────
  macOS      15.7.3
  芯片       arm64
  Shell      zsh

基础工具
────────────────────────────────────────
✓ Homebrew 5.0.13
✓ Xcode CLI Tools

编程语言
────────────────────────────────────────
✓ Python 3.13.5
✓ Node.js v22.14.0
```

### 安装选项

| 选项 | 说明 |
|------|------|
| `--china` 或 `-c` | 使用国内镜像源（清华/淘宝） |
| `--vibecoding` | 安装 Python + Node.js（推荐新手） |
| `--python` | 只安装 Python |
| `--nodejs` | 只安装 Node.js |
| `--python=3.12` | 安装指定版本的 Python |
| `--nodejs=20` | 安装指定版本的 Node.js |
| `--go` | 安装 Go 语言 |
| `--rust` | 安装 Rust 语言 |
| `--brew-only` | 只安装 Homebrew |

### 更多示例

```bash
# 只安装 Python
./devbox-mac.sh install --china --python

# 安装指定版本
./devbox-mac.sh install --china --python=3.12 --nodejs=24

# 只安装 Homebrew
./devbox-mac.sh install --china --brew-only

# 安装全部语言
./devbox-mac.sh install --china --python --nodejs --go --rust
```

---

## 国内镜像

脚本会自动配置以下镜像源：

| 工具 | 镜像源 |
|------|--------|
| Homebrew | 清华大学 TUNA |
| pip (Python) | 清华大学 PyPI |
| npm (Node.js) | 淘宝 npmmirror |
| Go modules | goproxy.cn |
| Rust crates | rsproxy.cn |

---

## 常见问题

**Q: 安装后命令找不到？**

运行以下命令，或者重新打开终端：
```bash
source ~/.zshrc
```

**Q: 需要输入密码？**

安装 Homebrew 和 Xcode 命令行工具时需要管理员密码，这是正常的。

**Q: 支持 Intel Mac 吗？**

支持。脚本会自动检测芯片类型并配置正确的路径。

---

## License

MIT
