# macOS 启动指南

## 🚀 快速启动

### 方式1：虚拟环境启动（推荐开发者）
```bash
# Fish Shell 用户
./run.fish

# Bash Shell 用户  
./run.sh
```

### 方式2：直接启动（推荐新手）
```bash
# Fish Shell 用户（使用系统Python）
./run_direct.fish

# Bash Shell 用户（使用系统Python）
./run_direct.sh
```

## 🛠️ 文件说明

| 文件 | 功能 | 适合人群 |
|------|------|----------|
| `run.fish` | 自动创建虚拟环境，Fish Shell | Fish用户+开发者 |
| `run.sh` | 自动创建虚拟环境，Bash Shell | Bash用户+开发者 |
| `run_direct.fish` | 使用系统Python，Fish Shell | Fish用户+新手 |
| `run_direct.sh` | 使用系统Python，Bash Shell | Bash用户+新手 |

## 📋 首次使用

1. **给脚本添加执行权限**（如果需要）：
   ```bash
   chmod +x run.fish run.sh run_direct.fish run_direct.sh
   ```

2. **选择合适的启动方式**：
   - 不确定用哪个？试试 `./run_direct.sh`
   - 想要虚拟环境？使用 `./run.fish` 或 `./run.sh`

## 🔧 常见问题

### Python命令未找到
```bash
# 如果提示 "python: command not found"
# 方法1：安装Python
brew install python

# 方法2：使用python3
# 编辑脚本，将 python 改为 python3
```

### 权限问题
```bash
# 如果提示权限错误
chmod +x 脚本名字
```

### Fish Shell vs Bash
- **Fish Shell用户**：使用 `.fish` 结尾的脚本
- **Bash Shell用户**：使用 `.sh` 结尾的脚本
- **不确定？** 大多数macOS用户可以使用 `.sh` 脚本

## 🎯 推荐使用

- **首次使用**：`./run_direct.sh`
- **开发环境**：`./run.fish` 或 `./run.sh`
- **Fish Shell爱好者**：`./run.fish`

## 📁 返回主程序

所有脚本都会自动运行主目录中的 `yt_dlp_gui.py`，无需手动切换目录。
