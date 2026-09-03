# yt-dlp GUI (wxPython Edition) · wxPython 版本

一个基于 wxPython 的原生 macOS 图形界面，用来调用 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 下载视频。
A native macOS GUI (wxPython) that drives [yt-dlp](https://github.com/yt-dlp/yt-dlp) downloads.

## 文件说明 · Files

| 文件 · File | 说明 · Description |
|---|---|
| `yt_dlp_gui_wx.py` | 主程序，英文界面 · Main app, English UI |
| `yt_dlp_gui_wx_cn.py` | 同一程序，中文界面（功能完全相同）· Same app, Chinese UI (functionally identical) |
| `run.sh` | 启动脚本：自动创建虚拟环境、安装依赖、运行程序 · Launcher script: creates a venv, installs deps, runs the app |

## 运行 · Run

```bash
cd core/
./run.sh
```

首次运行会在项目根目录创建 `venv/`，安装 `wxPython` 和 `yt-dlp`，然后启动图形界面。之后每次运行都会复用同一个虚拟环境。
On first run this creates a `venv/` at the project root, installs `wxPython` and `yt-dlp`, then launches the GUI. Subsequent runs reuse the same environment.

需要系统已安装 Python 3（推荐通过 Homebrew：`brew install python`）。
Requires a system Python 3 (Homebrew recommended: `brew install python`).

中文界面版本可以直接用同一个虚拟环境运行：
The Chinese-UI variant runs with the same environment:

```bash
venv/bin/python core/yt_dlp_gui_wx_cn.py
```

## 功能 · Features

- URL 输入、下载路径选择、格式预设 + 自定义格式字符串、"Check Available Formats"
  URL input, download path picker, quality presets + custom format string, "Check Available Formats"
- 代理设置（HTTP/HTTPS/SOCKS5）、浏览器 Cookies 导入（Chrome/Firefox/Safari/Edge），用于登录态/会员内容
  Proxy settings (HTTP/HTTPS/SOCKS5), browser cookie import (Chrome/Firefox/Safari/Edge) for login-gated content
- 开始/停止下载、实时日志、一键更新 yt-dlp
  Start/stop download, live log, one-click yt-dlp update

## 常见问题 · Troubleshooting

- **`python3` 未找到 / not found**：`brew install python`，然后重试。
- **虚拟环境损坏 / broken venv**：删除项目根目录下的 `venv/` 后重新运行 `./run.sh`。
  Delete the `venv/` directory at the project root, then re-run `./run.sh`.
- **下载失败 / downloads fail**：先用 "Check Available Formats" 确认目标 URL 有可用格式；登录态内容需要在高级设置里勾选浏览器 Cookies。
  Use "Check Available Formats" to confirm the URL has usable formats; enable browser cookies in Advanced Settings for login-gated content.

## 注意 · Note

仅供个人学习和技术研究使用，请遵守各平台服务条款及版权法规。
For personal and educational use only. Please respect each platform's terms of service and applicable copyright law.
