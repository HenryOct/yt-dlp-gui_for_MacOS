#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
yt-dlp GUI - A simple and easy-to-use YouTube downloader with graphical interface (wxPython version)
Supports proxy settings and various download options
Built with wxPython, cross-platform compatible (Windows 11, macOS, Linux)
Auto-install and update yt-dlp, optimized log display
"""

import sys
import os
import subprocess
import threading
import queue
import platform
import shutil
import importlib
from pathlib import Path
import time

def check_and_install_dependencies():
    """Check and install necessary dependencies (wxPython version)"""
    # Detect if we're in a virtual environment
    in_venv = hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix)
    
    missing_deps = []
    
    # Check wxPython
    try:
        import wx
        print(f"✅ wxPython found (Python: {sys.executable})")
    except ImportError:
        missing_deps.append('wxPython')
    
    if missing_deps:
        print(f"🔍 Missing required dependencies detected (Python: {sys.executable}):")
        for dep in missing_deps:
            print(f"  ❌ {dep}")
        
        print(f"🐍 Current Python path: {sys.executable}")
        if in_venv:
            print(f"🏠 Virtual environment detected: {sys.prefix}")
        else:
            print(f"🌐 Using system Python")
        
        # Ask user for auto-installation
        try:
            response = input("\nAuto-install missing dependencies? (y/n): ").lower().strip()
            if response in ['y', 'yes']:
                install_dependencies(missing_deps)
            else:
                print("❌ Cannot continue, please install dependencies manually:")
                for dep in missing_deps:
                    print(f"   pip install {dep}")
                sys.exit(1)
        except KeyboardInterrupt:
            print("\n❌ User cancelled installation")
            sys.exit(1)
    
    # Check yt-dlp
    check_ytdlp()

def install_dependencies(deps):
    """Install missing dependencies"""
    for dep in deps:
        print(f"🔧 Installing {dep}...")
        print(f"📍 Using Python: {sys.executable}")
        
        commands = [
            [sys.executable, "-m", "pip", "install", dep],
            [sys.executable, "-m", "pip", "install", "--user", dep]
        ]
        
        success = False
        for i, cmd in enumerate(commands):
            try:
                if i == 1:
                    print("⚠️ Standard installation failed, trying user-level installation...")
                
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
                if result.returncode == 0:
                    success = True
                    print(f"✅ {dep} installed successfully")
                    break
                else:
                    print(f"❌ Command failed: {' '.join(cmd)}")
                    print(f"Error output: {result.stderr}")
            except subprocess.TimeoutExpired:
                print(f"⏰ Installation timeout")
            except Exception as e:
                print(f"❌ Installation error: {e}")
        
        if not success:
            print(f"❌ {dep} auto-installation failed")
            print("Please run the following commands manually:")
            print(f"  {sys.executable} -m pip install {dep}")
            print("Or:")
            print(f"  {sys.executable} -m pip install --user {dep}")

def check_ytdlp():
    """检查yt-dlp是否已安装"""
    # 首先尝试作为Python模块检查
    try:
        import yt_dlp
        # 尝试获取版本
        result = subprocess.run([sys.executable, '-m', 'yt_dlp', '--version'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            version = result.stdout.strip()
            print(f"✅ yt-dlp 已安装: {version}")
            return True
    except ImportError:
        pass
    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
        pass
    
    # 尝试直接命令行检查
    try:
        # 检查是否在虚拟环境中
        venv_yt_dlp = None
        if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
            # 在虚拟环境中，尝试使用虚拟环境的yt-dlp
            venv_path = Path(sys.executable).parent / 'yt-dlp'
            if venv_path.exists():
                venv_yt_dlp = str(venv_path)
        
        cmd = [venv_yt_dlp] if venv_yt_dlp else ['yt-dlp']
        result = subprocess.run(cmd + ['--version'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            version = result.stdout.strip()
            print(f"✅ yt-dlp 已安装: {version}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.SubprocessError):
        pass
    
    print("❌ yt-dlp 未找到，正在安装...")
    install_dependencies(['yt-dlp'])
    return False

# 执行依赖检查
check_and_install_dependencies()

import wx
import wx.lib.scrolledpanel as scrolled


class DownloadWorker:
    """下载工作类，使用threading替代QThread"""
    def __init__(self, command, log_callback, progress_callback, finished_callback):
        self.command = command
        self.log_callback = log_callback
        self.progress_callback = progress_callback
        self.finished_callback = finished_callback
        self.process = None
        self.is_running = True
        self.thread = None
    
    def start(self):
        """启动下载线程"""
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()
    
    def run(self):
        """在后台线程中运行下载"""
        try:
            # 启动进程
            self.process = subprocess.Popen(
                self.command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1
            )
            
            # 读取输出
            while self.is_running and self.process.poll() is None:
                try:
                    line = self.process.stdout.readline()
                    if line:
                        line = line.strip()
                        # 检查是否是进度信息
                        if '[download]' in line and '%' in line:
                            self.progress_callback(line)
                        else:
                            self.log_callback(line, False)
                except Exception as e:
                    self.log_callback(f"读取输出错误: {e}", True)
                    break
            
            # 获取返回码
            if self.process:
                return_code = self.process.wait()
                success = return_code == 0
                if success:
                    self.finished_callback(True, "下载完成!")
                else:
                    self.finished_callback(False, f"下载失败，返回码: {return_code}")
            
        except Exception as e:
            self.finished_callback(False, f"下载出错: {e}")
    
    def stop(self):
        """停止下载"""
        self.is_running = False
        if self.process:
            try:
                self.process.terminate()
                # 等待进程结束
                for _ in range(50):  # 等待5秒
                    if self.process.poll() is not None:
                        break
                    time.sleep(0.1)
                else:
                    # 强制杀死进程
                    self.process.kill()
            except:
                pass


class MainPanel(scrolled.ScrolledPanel):
    """主面板类"""
    def __init__(self, parent):
        super().__init__(parent)
        self.parent = parent
        self.download_worker = None
        self.log_queue = queue.Queue()
        
        self.init_ui()
        self.SetupScrolling()
        
        # 启动日志更新定时器
        self.log_timer = wx.Timer(self)
        self.Bind(wx.EVT_TIMER, self.update_log_display, self.log_timer)
        self.log_timer.Start(100)  # 每100ms检查一次
        
        # 绑定关闭事件
        self.Bind(wx.EVT_CLOSE, self.on_close)
        
        # 显示系统信息
        self.show_system_info()
    
    def init_ui(self):
        """初始化用户界面"""
        # 创建主垂直布局
        main_sizer = wx.BoxSizer(wx.VERTICAL)
        
        # 创建notebook用于分组
        self.notebook = wx.Notebook(self)
        main_sizer.Add(self.notebook, 1, wx.EXPAND | wx.ALL, 10)
        
        # 基本设置页面
        self.basic_panel = wx.Panel(self.notebook)
        self.notebook.AddPage(self.basic_panel, "基本设置")
        self.init_basic_panel()
        
        # 高级设置页面
        self.advanced_panel = wx.Panel(self.notebook)
        self.notebook.AddPage(self.advanced_panel, "高级设置")
        self.init_advanced_panel()
        
        # 日志页面
        self.log_panel = wx.Panel(self.notebook)
        self.notebook.AddPage(self.log_panel, "日志")
        self.init_log_panel()
        
        self.SetSizer(main_sizer)
    
    def init_basic_panel(self):
        """初始化基本设置面板"""
        sizer = wx.BoxSizer(wx.VERTICAL)
        
        # URL输入区域
        url_box = wx.StaticBox(self.basic_panel, label="视频链接")
        url_sizer = wx.StaticBoxSizer(url_box, wx.VERTICAL)
        
        self.url_text = wx.TextCtrl(self.basic_panel, value="请输入YouTube或其他视频网站的链接...", 
                                   style=wx.TE_PROCESS_ENTER)
        url_sizer.Add(self.url_text, 0, wx.EXPAND | wx.ALL, 10)
        sizer.Add(url_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # 输出路径选择
        path_box = wx.StaticBox(self.basic_panel, label="下载路径")
        path_sizer = wx.StaticBoxSizer(path_box, wx.VERTICAL)
        
        path_inner_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        # 设置默认下载路径
        default_path = Path.home() / "Downloads"
        if platform.system() == "Windows":
            alt_path = Path.home() / "下载"
            if alt_path.exists():
                default_path = alt_path
        
        self.path_text = wx.TextCtrl(self.basic_panel, value=str(default_path))
        path_inner_sizer.Add(self.path_text, 1, wx.EXPAND | wx.RIGHT, 10)
        
        self.browse_btn = wx.Button(self.basic_panel, label="浏览")
        self.browse_btn.Bind(wx.EVT_BUTTON, self.on_browse)
        path_inner_sizer.Add(self.browse_btn, 0, wx.ALIGN_CENTER_VERTICAL)
        
        path_sizer.Add(path_inner_sizer, 0, wx.EXPAND | wx.ALL, 10)
        sizer.Add(path_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # 视频质量选择
        quality_box = wx.StaticBox(self.basic_panel, label="视频质量")
        quality_sizer = wx.StaticBoxSizer(quality_box, wx.VERTICAL)
        
        format_inner_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        format_label = wx.StaticText(self.basic_panel, label="格式:")
        format_inner_sizer.Add(format_label, 0, 
                              wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        
        # 格式选项
        format_choices = [
            "bestvideo+bestaudio/best[ext=mp4] (推荐 - 最稳定)",
            "best[ext=mp4] (最佳质量MP4)",
            "best[height<=1080]+bestaudio/best[height<=1080][ext=mp4] (1080p)",
            "best[height<=720][ext=mp4] (720p - 节省空间)",
            "worst[ext=mp4] (最低质量)",
            "bestaudio (仅音频)",
            "自定义格式"
        ]
        
        self.format_choice = wx.Choice(self.basic_panel, choices=format_choices)
        self.format_choice.SetSelection(0)
        format_inner_sizer.Add(self.format_choice, 1, wx.EXPAND | wx.RIGHT, 10)
        
        self.check_format_btn = wx.Button(self.basic_panel, label="检查可用格式")
        self.check_format_btn.Bind(wx.EVT_BUTTON, self.on_check_formats)
        format_inner_sizer.Add(self.check_format_btn, 0, wx.ALIGN_CENTER_VERTICAL)
        
        quality_sizer.Add(format_inner_sizer, 0, wx.EXPAND | wx.ALL, 10)
        
        # 自定义格式输入
        custom_sizer = wx.BoxSizer(wx.HORIZONTAL)
        custom_sizer.Add(wx.StaticText(self.basic_panel, label="自定义:"), 0, 
                        wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        
        self.custom_format_text = wx.TextCtrl(self.basic_panel)
        custom_sizer.Add(self.custom_format_text, 1, wx.EXPAND)
        
        quality_sizer.Add(custom_sizer, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        sizer.Add(quality_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # 下载按钮区域
        button_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        self.download_btn = wx.Button(self.basic_panel, label="开始下载")
        self.download_btn.Bind(wx.EVT_BUTTON, self.on_start_download)
        button_sizer.Add(self.download_btn, 0, wx.RIGHT, 10)
        
        self.stop_btn = wx.Button(self.basic_panel, label="停止下载")
        self.stop_btn.Bind(wx.EVT_BUTTON, self.on_stop_download)
        self.stop_btn.Enable(False)
        button_sizer.Add(self.stop_btn, 0, wx.RIGHT, 10)
        
        button_sizer.AddStretchSpacer()
        
        self.update_btn = wx.Button(self.basic_panel, label="更新yt-dlp")
        self.update_btn.Bind(wx.EVT_BUTTON, self.on_update_ytdlp)
        button_sizer.Add(self.update_btn, 0)
        
        sizer.Add(button_sizer, 0, wx.EXPAND | wx.ALL, 20)
        
        # 进度显示
        progress_box = wx.StaticBox(self.basic_panel, label="下载进度")
        progress_sizer = wx.StaticBoxSizer(progress_box, wx.VERTICAL)
        
        self.progress_text = wx.StaticText(self.basic_panel, label="准备就绪")
        progress_sizer.Add(self.progress_text, 0, wx.EXPAND | wx.ALL, 10)
        
        self.progress_gauge = wx.Gauge(self.basic_panel, style=wx.GA_HORIZONTAL)
        progress_sizer.Add(self.progress_gauge, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        
        sizer.Add(progress_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        self.basic_panel.SetSizer(sizer)
    
    def init_advanced_panel(self):
        """初始化高级设置面板"""
        sizer = wx.BoxSizer(wx.VERTICAL)
        
        # 代理设置
        proxy_box = wx.StaticBox(self.advanced_panel, label="代理设置")
        proxy_sizer = wx.StaticBoxSizer(proxy_box, wx.VERTICAL)
        
        self.use_proxy_check = wx.CheckBox(self.advanced_panel, label="启用代理")
        proxy_sizer.Add(self.use_proxy_check, 0, wx.ALL, 10)
        
        proxy_config_sizer = wx.FlexGridSizer(2, 6, 5, 10)
        proxy_config_sizer.AddGrowableCol(3)
        
        proxy_config_sizer.Add(wx.StaticText(self.advanced_panel, label="类型:"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.proxy_type_choice = wx.Choice(self.advanced_panel, choices=["http", "https", "socks5"])
        self.proxy_type_choice.SetSelection(0)
        proxy_config_sizer.Add(self.proxy_type_choice, 0)
        
        proxy_config_sizer.Add(wx.StaticText(self.advanced_panel, label="地址:"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.proxy_host_text = wx.TextCtrl(self.advanced_panel, value="127.0.0.1")
        proxy_config_sizer.Add(self.proxy_host_text, 1, wx.EXPAND)
        
        proxy_config_sizer.Add(wx.StaticText(self.advanced_panel, label="端口:"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.proxy_port_text = wx.TextCtrl(self.advanced_panel, value="7890")
        proxy_config_sizer.Add(self.proxy_port_text, 0)
        
        proxy_sizer.Add(proxy_config_sizer, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        sizer.Add(proxy_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Cookies设置
        cookies_box = wx.StaticBox(self.advanced_panel, label="浏览器Cookies")
        cookies_sizer = wx.StaticBoxSizer(cookies_box, wx.VERTICAL)
        
        self.use_cookies_check = wx.CheckBox(self.advanced_panel, label="使用浏览器Cookies")
        cookies_sizer.Add(self.use_cookies_check, 0, wx.ALL, 10)
        
        browser_sizer = wx.BoxSizer(wx.HORIZONTAL)
        browser_sizer.Add(wx.StaticText(self.advanced_panel, label="浏览器:"), 0, 
                         wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        
        self.browser_choice = wx.Choice(self.advanced_panel, choices=["chrome", "firefox", "safari", "edge"])
        self.browser_choice.SetSelection(0)
        browser_sizer.Add(self.browser_choice, 0)
        
        cookies_sizer.Add(browser_sizer, 0, wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        sizer.Add(cookies_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        self.advanced_panel.SetSizer(sizer)
    
    def init_log_panel(self):
        """初始化日志面板"""
        sizer = wx.BoxSizer(wx.VERTICAL)
        
        # 控制按钮
        controls_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        self.clear_log_btn = wx.Button(self.log_panel, label="清空日志")
        self.clear_log_btn.Bind(wx.EVT_BUTTON, self.on_clear_log)
        controls_sizer.Add(self.clear_log_btn, 0, wx.RIGHT, 10)
        
        self.auto_scroll_check = wx.CheckBox(self.log_panel, label="自动滚动")
        self.auto_scroll_check.SetValue(True)
        controls_sizer.Add(self.auto_scroll_check, 0)
        
        sizer.Add(controls_sizer, 0, wx.EXPAND | wx.ALL, 10)
        
        # 日志显示区域
        self.log_text = wx.TextCtrl(self.log_panel, style=wx.TE_MULTILINE | wx.TE_READONLY | wx.TE_WORDWRAP)
        self.log_text.SetFont(wx.Font(10, wx.FONTFAMILY_TELETYPE, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL))
        sizer.Add(self.log_text, 1, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        
        self.log_panel.SetSizer(sizer)
    
    def on_close(self, event):
        """处理窗口关闭事件，清理资源"""
        # 停止定时器
        if hasattr(self, 'log_timer') and self.log_timer.IsRunning():
            self.log_timer.Stop()
        
        # 停止下载线程
        if hasattr(self, 'download_worker') and self.download_worker:
            self.download_worker.stop()
        
        # 销毁窗口
        self.Destroy()
    
    def on_browse(self, event):
        """浏览文件夹"""
        dlg = wx.DirDialog(self, "选择下载路径", defaultPath=self.path_text.GetValue())
        if dlg.ShowModal() == wx.ID_OK:
            self.path_text.SetValue(dlg.GetPath())
        dlg.Destroy()
    
    def log_message(self, message, is_error=False):
        """添加日志消息到队列"""
        self.log_queue.put((message, is_error))
    
    def update_log_display(self, event):
        """更新日志显示"""
        try:
            while True:
                message, is_error = self.log_queue.get_nowait()
                
                # 插入消息
                self.log_text.AppendText(message + "\n")
                
                # 如果是错误，可以设置不同颜色
                if is_error:
                    # wxPython设置颜色比较复杂，这里先简单处理
                    pass
                
                # 自动滚动到底部
                if self.auto_scroll_check.GetValue():
                    self.log_text.SetInsertionPointEnd()
                    
        except queue.Empty:
            pass
    
    def on_clear_log(self, event):
        """清空日志"""
        self.log_text.Clear()
    
    def show_system_info(self):
        """显示系统信息"""
        system = platform.system()
        version = platform.version()
        python_version = platform.python_version()
        python_executable = sys.executable
        
        self.log_message(f"🖥️ 系统: {system} {version}")
        self.log_message(f"🐍 Python: {python_version}")
        self.log_message(f"📍 Python路径: {python_executable}")
        
        # 检测Python环境类型
        env_info = self.detect_python_environment()
        if env_info:
            self.log_message(f"🏠 Python环境: {env_info}")
        
        try:
            wx_version = wx.version()
            self.log_message(f"🎨 GUI框架: wxPython {wx_version}")
        except:
            self.log_message(f"🎨 GUI框架: wxPython")
            
        self.log_message("📦 正在检查yt-dlp...")
    
    def detect_python_environment(self):
        """检测Python环境类型"""
        # 检测虚拟环境
        if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
            return "虚拟环境 (venv/virtualenv)"
        
        # 检测Anaconda
        if 'conda' in sys.executable.lower():
            return "Anaconda/Miniconda"
        
        # 检测系统特定路径
        if platform.system() == "Windows":
            if 'windowsapps' in sys.executable.lower():
                return "Microsoft Store版本"
        elif platform.system() == "Darwin":  # macOS
            if '/opt/homebrew' in sys.executable:
                return "Homebrew版本 (Apple Silicon)"
            elif '/usr/local' in sys.executable:
                return "Homebrew版本 (Intel)"
        
        return "系统Python"
    
    def get_ytdlp_path(self):
        """获取正确的yt-dlp路径或命令"""
        # 检查是否在虚拟环境中
        if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
            # 在虚拟环境中，先尝试虚拟环境的yt-dlp可执行文件
            venv_yt_dlp = Path(sys.executable).parent / 'yt-dlp'
            if venv_yt_dlp.exists():
                return str(venv_yt_dlp)
        
        # 如果没有可执行文件，但有yt-dlp模块，返回None表示需要使用模块方式
        try:
            import yt_dlp
            return None  # 表示使用模块方式
        except ImportError:
            pass
        
        # 默认返回系统yt-dlp
        return 'yt-dlp'
    
    def on_check_formats(self, event):
        """检查可用格式"""
        url = self.url_text.GetValue().strip()
        if not url or url == "请输入YouTube或其他视频网站的链接...":
            wx.MessageBox("请先输入视频链接!", "警告", wx.OK | wx.ICON_WARNING)
            return
        
        self.log_message("🔍 正在检查可用格式...")
        
        def check_formats():
            try:
                # 使用正确的yt-dlp路径
                ytdlp_path = self.get_ytdlp_path()
                if ytdlp_path is None:
                    # 使用Python模块方式
                    cmd = [sys.executable, '-m', 'yt_dlp', '--list-formats', url]
                else:
                    # 使用可执行文件方式
                    cmd = [ytdlp_path, '--list-formats', url]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                
                if result.returncode == 0:
                    wx.CallAfter(self.log_message, "📋 可用格式:")
                    for line in result.stdout.split('\n'):
                        if line.strip():
                            wx.CallAfter(self.log_message, line)
                else:
                    wx.CallAfter(self.log_message, f"❌ 检查格式失败: {result.stderr}", True)
            except subprocess.TimeoutExpired:
                wx.CallAfter(self.log_message, "⏰ 检查格式超时", True)
            except Exception as e:
                wx.CallAfter(self.log_message, f"❌ 检查格式出错: {e}", True)
        
        # 在后台线程中运行
        threading.Thread(target=check_formats, daemon=True).start()
    
    def on_start_download(self, event):
        """开始下载"""
        # 获取URL
        url = self.url_text.GetValue().strip()
        if not url or url == "请输入YouTube或其他视频网站的链接...":
            wx.MessageBox("请输入视频链接!", "警告", wx.OK | wx.ICON_WARNING)
            return
        
        # 获取保存路径
        save_path = self.path_text.GetValue().strip()
        if not save_path:
            wx.MessageBox("请选择下载路径!", "警告", wx.OK | wx.ICON_WARNING)
            return
        
        # 确保路径存在
        Path(save_path).mkdir(parents=True, exist_ok=True)
        
        # 构建命令
        # 使用虚拟环境中的 yt-dlp 路径
        ytdlp_path = self.get_ytdlp_path()
        if ytdlp_path is None:
            # 使用Python模块方式
            cmd = [sys.executable, '-m', 'yt_dlp', '--newline']
        else:
            # 使用可执行文件方式
            cmd = [ytdlp_path, '--newline']
        
        # 添加格式选择
        format_selection = self.format_choice.GetStringSelection()
        if format_selection.startswith("自定义"):
            custom_format = self.custom_format_text.GetValue().strip()
            if custom_format:
                cmd.extend(['-f', custom_format])
        else:
            # 提取实际格式字符串
            format_code = format_selection.split('(')[0].strip()
            if format_code:
                cmd.extend(['-f', format_code])
        
        # 添加输出路径
        cmd.extend(['-o', f'{save_path}/%(title)s.%(ext)s'])
        
        # 添加代理设置
        if self.use_proxy_check.GetValue():
            proxy_type = self.proxy_type_choice.GetStringSelection()
            proxy_host = self.proxy_host_text.GetValue().strip()
            proxy_port = self.proxy_port_text.GetValue().strip()
            proxy_url = f"{proxy_type}://{proxy_host}:{proxy_port}"
            cmd.extend(['--proxy', proxy_url])
        
        # 添加Cookies设置
        if self.use_cookies_check.GetValue():
            browser = self.browser_choice.GetStringSelection()
            cmd.extend(['--cookies-from-browser', browser])
        
        # 添加URL
        cmd.append(url)
        
        self.log_message(f"🚀 开始下载: {url}")
        self.log_message(f"💾 保存到: {save_path}")
        self.log_message(f"⚙️ 命令: {' '.join(cmd)}")
        
        # 更新UI状态
        self.download_btn.Enable(False)
        self.stop_btn.Enable(True)
        self.progress_text.SetLabel("正在下载...")
        self.progress_gauge.Pulse()
        
        # 启动下载线程
        self.download_worker = DownloadWorker(
            cmd, 
            self.log_message_threadsafe,
            self.update_progress_threadsafe,
            self.download_finished_threadsafe
        )
        self.download_worker.start()
    
    def on_stop_download(self, event):
        """停止下载"""
        if self.download_worker:
            self.download_worker.stop()
            self.log_message("🛑 正在停止下载...")
    
    def log_message_threadsafe(self, message, is_error=False):
        """线程安全的日志消息"""
        wx.CallAfter(self.log_message, message, is_error)
    
    def update_progress_threadsafe(self, progress_text):
        """线程安全的进度更新"""
        wx.CallAfter(self.progress_text.SetLabel, progress_text)
        wx.CallAfter(self.log_message, progress_text)
    
    def download_finished_threadsafe(self, success, message):
        """线程安全的下载完成回调"""
        def update_ui():
            # 更新UI状态
            self.download_btn.Enable(True)
            self.stop_btn.Enable(False)
            self.progress_gauge.SetValue(0)
            
            if success:
                self.progress_text.SetLabel("下载完成!")
                self.log_message(f"✅ {message}")
                wx.MessageBox(message, "成功", wx.OK | wx.ICON_INFORMATION)
            else:
                self.progress_text.SetLabel("下载失败")
                self.log_message(f"❌ {message}", True)
                wx.MessageBox(message, "错误", wx.OK | wx.ICON_ERROR)
            
            self.download_worker = None
        
        wx.CallAfter(update_ui)
    
    def on_update_ytdlp(self, event):
        """更新yt-dlp"""
        self.log_message("🔄 正在更新yt-dlp...")
        
        def update_worker():
            try:
                cmd = [sys.executable, '-m', 'pip', 'install', '--upgrade', 'yt-dlp']
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
                
                if result.returncode == 0:
                    wx.CallAfter(self.log_message, "✅ yt-dlp 更新成功!")
                else:
                    wx.CallAfter(self.log_message, f"❌ yt-dlp 更新失败: {result.stderr}", True)
            except subprocess.TimeoutExpired:
                wx.CallAfter(self.log_message, "⏰ 更新超时", True)
            except Exception as e:
                wx.CallAfter(self.log_message, f"❌ 更新出错: {e}", True)
        
        threading.Thread(target=update_worker, daemon=True).start()


class MainFrame(wx.Frame):
    """主窗口类"""
    def __init__(self):
        super().__init__(None, title="yt-dlp GUI 下载器 - 跨平台视频下载工具 (wxPython版)")
        
        # 设置窗口大小
        self.SetSize((900, 800))
        self.Center()
        
        # 创建主面板
        self.panel = MainPanel(self)
        
        # 创建菜单栏
        self.create_menu_bar()
        
        # 创建状态栏
        self.CreateStatusBar()
        self.SetStatusText("准备就绪")
        
        # 绑定关闭事件
        self.Bind(wx.EVT_CLOSE, self.on_close)
    
    def create_menu_bar(self):
        """创建菜单栏"""
        menubar = wx.MenuBar()
        
        # 文件菜单
        file_menu = wx.Menu()
        exit_item = file_menu.Append(wx.ID_EXIT, "退出\tCtrl+Q")
        self.Bind(wx.EVT_MENU, self.on_exit, exit_item)
        
        # 帮助菜单
        help_menu = wx.Menu()
        about_item = help_menu.Append(wx.ID_ABOUT, "关于")
        self.Bind(wx.EVT_MENU, self.on_about, about_item)
        
        menubar.Append(file_menu, "文件")
        menubar.Append(help_menu, "帮助")
        
        self.SetMenuBar(menubar)
    
    def on_exit(self, event):
        """退出程序"""
        self.Close()
    
    def on_close(self, event):
        """处理主窗口关闭事件"""
        # 通知面板进行清理
        if hasattr(self, 'panel'):
            self.panel.on_close(event)
        
        # 销毁窗口
        self.Destroy()
    
    def on_about(self, event):
        """关于对话框"""
        info = wx.adv.AboutDialogInfo()
        info.SetName("yt-dlp GUI")
        info.SetVersion("2.0 (wxPython版)")
        info.SetDescription("一个简单易用的YouTube下载工具图形界面\n使用wxPython构建，跨平台兼容")
        info.SetWebSite("https://github.com/yt-dlp/yt-dlp")
        
        wx.adv.AboutBox(info)


class YtDlpApp(wx.App):
    """应用程序类"""
    def OnInit(self):
        frame = MainFrame()
        frame.Show()
        return True


def main():
    """主函数"""
    app = YtDlpApp()
    app.MainLoop()


if __name__ == "__main__":
    main()
