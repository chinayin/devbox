# devbox

零基础？一行命令搞定 AI 编程环境，专为 AI/Vibe Coding 新手设计。

Mac / Windows 自动安装包管理器和开发工具，国内用户自动配置镜像源加速。

---

## 一键安装

### macOS

打开终端，复制粘贴以下命令：

**国内用户（推荐）**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/chinayin/devbox/master/devbox-mac.sh)" -- install --china --vibecoding
```

**海外用户**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/chinayin/devbox/master/devbox-mac.sh)" -- install --vibecoding
```

### Windows

打开 PowerShell，复制粘贴以下命令：

**国内用户（推荐）**
```powershell
irm https://raw.githubusercontent.com/chinayin/devbox/master/devbox-win.ps1 -OutFile devbox-win.ps1; .\devbox-win.ps1 install -China -VibeCoding
```

**海外用户**
```powershell
irm https://raw.githubusercontent.com/chinayin/devbox/master/devbox-win.ps1 -OutFile devbox-win.ps1; .\devbox-win.ps1 install -VibeCoding
```

> 这会安装包管理器 + Python + Node.js，国内用户自动配置镜像加速。

---

## 这是什么？

如果你是编程新手，想要开始 AI 编程或 Vibe Coding，你需要先安装一些开发工具。

这个脚本帮你自动完成这些事情：

| 工具 | macOS | Windows | 用途 |
|------|-------|---------|------|
| 包管理器 | Homebrew | Scoop | 用来安装其他工具 |
| Python | ✓ | ✓ | AI 和数据科学的主流语言 |
| Node.js | ✓ | ✓ | 前端开发和很多 AI 工具需要它 |
| Go | ✓ | ✓ | 高性能后端开发（可选） |
| Rust | ✓ | ✓ | 系统级编程语言（可选） |

---

## 使用方法

### 检查当前环境

```bash
# macOS
./devbox-mac.sh status

# Windows
.\devbox-win.ps1 status
```

### 安装选项

| macOS | Windows | 说明 |
|-------|---------|------|
| `--china` / `-c` | `-China` / `-c` | 使用国内镜像源 |
| `--vibecoding` | `-VibeCoding` | 安装 Python + Node.js（推荐新手） |
| `--python` | `-Python` | 安装 Python |
| `--nodejs` | `-NodeJS` | 安装 Node.js |
| `--python=3.12` | `-PythonVersion 3.12` | 指定 Python 版本 |
| `--nodejs=20` | `-NodeJSVersion 20` | 指定 Node.js 版本 |
| `--go` | `-Go` | 安装 Go 语言 |
| `--rust` | `-Rust` | 安装 Rust 语言 |
| `--brew-only` | `-ScoopOnly` | 只安装包管理器 |

### 更多示例

**macOS**
```bash
./devbox-mac.sh install --china --python              # 只安装 Python
./devbox-mac.sh install --china --python=3.12         # 指定版本
./devbox-mac.sh install --china --brew-only           # 只装 Homebrew
./devbox-mac.sh install --china --python --nodejs --go --rust  # 全部安装
```

**Windows**
```powershell
.\devbox-win.ps1 install -China -Python               # 只安装 Python
.\devbox-win.ps1 install -China -PythonVersion 3.12   # 指定版本
.\devbox-win.ps1 install -China -ScoopOnly            # 只装 Scoop
.\devbox-win.ps1 install -China -Python -NodeJS -Go -Rust  # 全部安装
```

---

## 国内镜像

脚本会自动配置以下镜像源：

| 工具 | macOS 镜像 | Windows 镜像 |
|------|-----------|--------------|
| 包管理器 | 清华大学 TUNA | Gitee |
| pip (Python) | 清华大学 PyPI | 清华大学 PyPI |
| npm (Node.js) | 淘宝 npmmirror | 淘宝 npmmirror |
| Go modules | goproxy.cn | goproxy.cn |
| Rust crates | rsproxy.cn | rsproxy.cn |

---

## 常见问题

**Q: macOS 安装后命令找不到？**

运行以下命令，或者重新打开终端：
```bash
source ~/.zshrc
```

**Q: Windows 提示脚本无法运行？**

以管理员身份运行 PowerShell，执行：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Q: macOS 需要输入密码？**

安装 Homebrew 和 Xcode 命令行工具时需要管理员密码，这是正常的。

**Q: Windows 需要管理员权限吗？**

不需要。Scoop 安装在用户目录，无需管理员权限。

---

## License

MIT
