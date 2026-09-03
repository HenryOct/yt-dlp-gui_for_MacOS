# yt-dlp GUI (SwiftUI Edition)

原 wxPython 界面（[../core/](../core/)）的 SwiftUI 重构版本，功能和行为与原版保持一致，仅替换了 GUI 技术栈，让界面更贴近原生 macOS 观感。

## 功能对照

与 `core/yt_dlp_gui_wx.py` 完全对齐：

- **一键安装引导**：首次启动（或环境损坏时）会显示一个简单的安装引导页——检测环境 → 选择软件包源 → 自动创建专属虚拟环境（`~/Library/Application Support/<bundle id>/venv`）并安装 yt-dlp，全程无需用户操作终端；已经装好的老用户再次打开不会看到这个引导页，直接进主界面。仅当系统完全没有 Python 3 时才会在引导页报错并停止（不会尝试自动安装 Python 本身）
- **软件包源选择**：引导页会让用户选"默认 PyPI 源"或"清华大学镜像源"（适合中国大陆网络环境）。⚠️ 该选择**只作用于当次安装**——以 `-i <url>` 参数的形式仅附加在这几条 `pip install` 命令上，不写入任何 pip 配置文件、不设置环境变量、不做任何全局修改
- **调用方式不变**：仍然通过 `Process` 调用 venv 里的 `python3 -m pip` 和 `yt-dlp`（或 `python3 -m yt_dlp`），不引入独立二进制，但改为使用应用专属 venv 而非系统 Python，避免污染系统环境
- **Basic Settings**：URL 输入、下载路径（默认 `~/Downloads`）、6 种预设格式 + 自定义格式、开始/停止/更新按钮、进度条（含播放列表下载时的整体进度与当前项数提示）、"Check Available Formats"
- **Advanced Settings**：代理设置（http/https/socks5 + host/port）、浏览器 Cookies 导入（chrome/firefox/safari/edge）
- **Log**：实时日志流（用 SwiftUI `@Published` 直接驱动，替代原版的 queue+100ms 轮询）；Update/Check Formats 的结果也会以状态提示的形式直接显示在 Basic Settings 页面

## 运行环境

- macOS 13.0+
- 系统已装 Python 3（Homebrew/系统自带均可）——如果完全没装，应用启动时会弹窗提示并停在这一步，不会自动安装 Python
- 首次启动后，应用会自动创建独立 venv 并安装 yt-dlp，不需要用户手动操作

## 安装为独立 App（推荐给非开发者使用）

一键构建 Release 版 `.app` 并安装到 `/Applications`，之后无需 Xcode，双击图标或 Spotlight 搜索即可打开。脚本位于仓库根目录：

```bash
cd ..
./build_and_install.sh
```

该脚本会：编译 Release 版本 → ad-hoc 签名（不需要付费 Apple Developer 账号，仅限本机运行）→ 安装到 `/Applications/yt-dlp GUI.app`。修改 Swift 源码后重新运行该脚本即可更新已安装的 App。

## 开发调试

### 用 Xcode 打开

```bash
open YTDlpGUI.xcodeproj
```

然后 `Cmd+R` 运行。

### 用命令行构建（Debug）

```bash
xcodebuild -project YTDlpGUI.xcodeproj -scheme YTDlpGUI -configuration Debug build
```

## 项目结构

项目文件（`YTDlpGUI.xcodeproj`）由 [project.yml](project.yml) 通过 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成。如果修改了 `project.yml` 或增删了源码目录结构，重新生成：

```bash
brew install xcodegen  # 如果尚未安装
xcodegen generate
```

```
macos-swift/
├── project.yml                     # XcodeGen 项目描述
├── YTDlpGUI.xcodeproj               # 生成的 Xcode 项目（由 project.yml 生成，可重新生成）
└── YTDlpGUI/
    ├── YTDlpGUIApp.swift            # App 入口 + 菜单栏
    ├── Assets.xcassets/             # App 图标占位
    ├── Models/
    │   ├── DownloadOptions.swift    # 下载参数状态 + 命令行参数拼接
    │   ├── PythonEnvironment.swift  # Python/venv 探测、yt-dlp 路径解析
    │   ├── PackageSource.swift      # 安装引导页的 pip 源选项（默认/清华镜像）
    │   └── LogStore.swift           # 日志状态
    ├── Services/
    │   ├── DependencyManager.swift  # 依赖检测（快速） + 实际安装（venv+yt-dlp）
    │   ├── DownloadRunner.swift     # 下载子进程管理（启动/流式日志/停止）
    │   ├── FormatChecker.swift      # "Check Available Formats"
    │   └── YtDlpUpdater.swift       # "Update yt-dlp"
    └── Views/
        ├── ContentView.swift        # 顶层容器：安装引导 ↔ 主界面 TabView 切换
        ├── OnboardingView.swift     # 首次运行安装引导页
        ├── BasicSettingsView.swift
        ├── AdvancedSettingsView.swift
        └── LogView.swift
```

## 与原版的差异

- 未持久化设置（代理/cookies/路径每次重启需要重新填写），与原版行为一致
- 未沙盒化（App Sandbox 关闭），因为需要自由调用系统 `python3`/`pip`/`yt-dlp` 子进程，与原版无沙盒限制一致
- **不复用系统 Python 环境**：原版直接用系统/用户 Python 的 site-packages（或已激活的 venv），SwiftUI 版改为始终使用应用专属 venv（`~/Library/Application Support/<bundle id>/venv`），实现完全自包含、一键安装、不污染系统环境
- 原 Python 版本（`core/`）保留不动，两者独立运行，互不影响

## 卸载

```bash
rm -rf "/Applications/yt-dlp GUI.app"
rm -rf "$HOME/Library/Application Support/com.henrywan.ytdlpgui.YTDlpGUI"   # 专属 venv 及数据
```

## 注意

本工具仅供个人学习和技术研究使用，请遵守各平台服务条款及版权法规。
