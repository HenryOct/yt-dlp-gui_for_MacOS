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
    """Check if yt-dlp is installed"""
    # First try to check as Python module
    try:
        import yt_dlp
        # Try to get version
        result = subprocess.run([sys.executable, '-m', 'yt_dlp', '--version'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            version = result.stdout.strip()
            print(f"✅ yt-dlp installed: {version}")
            return True
    except ImportError:
        pass
    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
        pass
    
    # Try direct command line check
    try:
        # Check if in virtual environment
        venv_yt_dlp = None
        if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
            # In virtual environment, try to use venv yt-dlp
            venv_path = Path(sys.executable).parent / 'yt-dlp'
            if venv_path.exists():
                venv_yt_dlp = str(venv_path)
        
        cmd = [venv_yt_dlp] if venv_yt_dlp else ['yt-dlp']
        result = subprocess.run(cmd + ['--version'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            version = result.stdout.strip()
            print(f"✅ yt-dlp installed: {version}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.SubprocessError):
        pass
    
    print("❌ yt-dlp not found, installing...")
    install_dependencies(['yt-dlp'])
    return False

# Execute dependency check
check_and_install_dependencies()

import wx
import wx.lib.scrolledpanel as scrolled


class DownloadWorker:
    """Download worker class using threading instead of QThread"""
    def __init__(self, command, log_callback, progress_callback, finished_callback):
        self.command = command
        self.log_callback = log_callback
        self.progress_callback = progress_callback
        self.finished_callback = finished_callback
        self.process = None
        self.is_running = True
        self.thread = None
    
    def start(self):
        """Start download thread"""
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()
    
    def run(self):
        """Run download in background thread"""
        try:
            # Start process
            self.process = subprocess.Popen(
                self.command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1
            )
            
            # Read output
            while self.is_running and self.process.poll() is None:
                try:
                    line = self.process.stdout.readline()
                    if line:
                        line = line.strip()
                        # Check if it's progress information
                        if '[download]' in line and '%' in line:
                            self.progress_callback(line)
                        else:
                            self.log_callback(line, False)
                except Exception as e:
                    self.log_callback(f"Output reading error: {e}", True)
                    break
            
            # Get return code
            if self.process:
                return_code = self.process.wait()
                success = return_code == 0
                if success:
                    self.finished_callback(True, "Download completed!")
                else:
                    self.finished_callback(False, f"Download failed, return code: {return_code}")
            
        except Exception as e:
            self.finished_callback(False, f"Download error: {e}")
    
    def stop(self):
        """Stop download"""
        self.is_running = False
        if self.process:
            try:
                self.process.terminate()
                # Wait for process to end
                for _ in range(50):  # Wait 5 seconds
                    if self.process.poll() is not None:
                        break
                    time.sleep(0.1)
                else:
                    # Force kill process
                    self.process.kill()
            except:
                pass


class MainPanel(scrolled.ScrolledPanel):
    """Main panel class"""
    def __init__(self, parent):
        super().__init__(parent)
        self.parent = parent
        self.download_worker = None
        self.log_queue = queue.Queue()
        
        self.init_ui()
        self.SetupScrolling()
        
        # Start log update timer
        self.log_timer = wx.Timer(self)
        self.Bind(wx.EVT_TIMER, self.update_log_display, self.log_timer)
        self.log_timer.Start(100)  # Check every 100ms
        
        # Bind close event
        self.Bind(wx.EVT_CLOSE, self.on_close)
        
        # Show system information
        self.show_system_info()
    
    def init_ui(self):
        """Initialize user interface"""
        # Create main vertical layout
        main_sizer = wx.BoxSizer(wx.VERTICAL)
        
        # Create notebook for grouping
        self.notebook = wx.Notebook(self)
        main_sizer.Add(self.notebook, 1, wx.EXPAND | wx.ALL, 10)
        
        # Basic settings page
        self.basic_panel = wx.Panel(self.notebook)
        self.notebook.AddPage(self.basic_panel, "Basic Settings")
        self.init_basic_panel()
        
        # Advanced settings page
        self.advanced_panel = wx.Panel(self.notebook)
        self.notebook.AddPage(self.advanced_panel, "Advanced Settings")
        self.init_advanced_panel()
        
        # Log page
        self.log_panel = wx.Panel(self.notebook)
        self.notebook.AddPage(self.log_panel, "Log")
        self.init_log_panel()
        
        self.SetSizer(main_sizer)
    
    def init_basic_panel(self):
        """Initialize basic settings panel"""
        sizer = wx.BoxSizer(wx.VERTICAL)
        
        # URL input area
        url_box = wx.StaticBox(self.basic_panel, label="Video URL")
        url_sizer = wx.StaticBoxSizer(url_box, wx.VERTICAL)
        
        self.url_text = wx.TextCtrl(self.basic_panel, value="Enter YouTube or other video website URL...", 
                                   style=wx.TE_PROCESS_ENTER)
        url_sizer.Add(self.url_text, 0, wx.EXPAND | wx.ALL, 10)
        sizer.Add(url_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Output path selection
        path_box = wx.StaticBox(self.basic_panel, label="Download Path")
        path_sizer = wx.StaticBoxSizer(path_box, wx.VERTICAL)
        
        path_inner_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        # Set default download path
        default_path = Path.home() / "Downloads"
        if platform.system() == "Windows":
            alt_path = Path.home() / "Downloads"
            if alt_path.exists():
                default_path = alt_path
        
        self.path_text = wx.TextCtrl(self.basic_panel, value=str(default_path))
        path_inner_sizer.Add(self.path_text, 1, wx.EXPAND | wx.RIGHT, 10)
        
        self.browse_btn = wx.Button(self.basic_panel, label="Browse")
        self.browse_btn.Bind(wx.EVT_BUTTON, self.on_browse)
        path_inner_sizer.Add(self.browse_btn, 0, wx.ALIGN_CENTER_VERTICAL)
        
        path_sizer.Add(path_inner_sizer, 0, wx.EXPAND | wx.ALL, 10)
        sizer.Add(path_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Video quality selection
        quality_box = wx.StaticBox(self.basic_panel, label="Video Quality")
        quality_sizer = wx.StaticBoxSizer(quality_box, wx.VERTICAL)
        
        format_inner_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        format_label = wx.StaticText(self.basic_panel, label="Format:")
        format_inner_sizer.Add(format_label, 0, 
                              wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        
        # Format options
        format_choices = [
            "bestvideo+bestaudio/best[ext=mp4] (Recommended - Most Stable)",
            "best[ext=mp4] (Best Quality MP4)",
            "best[height<=1080]+bestaudio/best[height<=1080][ext=mp4] (1080p)",
            "best[height<=720][ext=mp4] (720p - Space Saving)",
            "worst[ext=mp4] (Lowest Quality)",
            "bestaudio (Audio Only)",
            "Custom Format"
        ]
        
        self.format_choice = wx.Choice(self.basic_panel, choices=format_choices)
        self.format_choice.SetSelection(0)
        format_inner_sizer.Add(self.format_choice, 1, wx.EXPAND | wx.RIGHT, 10)
        
        self.check_format_btn = wx.Button(self.basic_panel, label="Check Available Formats")
        self.check_format_btn.Bind(wx.EVT_BUTTON, self.on_check_formats)
        format_inner_sizer.Add(self.check_format_btn, 0, wx.ALIGN_CENTER_VERTICAL)
        
        quality_sizer.Add(format_inner_sizer, 0, wx.EXPAND | wx.ALL, 10)
        
        # Custom format input
        custom_sizer = wx.BoxSizer(wx.HORIZONTAL)
        custom_sizer.Add(wx.StaticText(self.basic_panel, label="Custom:"), 0, 
                        wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        
        self.custom_format_text = wx.TextCtrl(self.basic_panel)
        custom_sizer.Add(self.custom_format_text, 1, wx.EXPAND)
        
        quality_sizer.Add(custom_sizer, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        sizer.Add(quality_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Download button area
        button_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        self.download_btn = wx.Button(self.basic_panel, label="Start Download")
        self.download_btn.Bind(wx.EVT_BUTTON, self.on_start_download)
        button_sizer.Add(self.download_btn, 0, wx.RIGHT, 10)
        
        self.stop_btn = wx.Button(self.basic_panel, label="Stop Download")
        self.stop_btn.Bind(wx.EVT_BUTTON, self.on_stop_download)
        self.stop_btn.Enable(False)
        button_sizer.Add(self.stop_btn, 0, wx.RIGHT, 10)
        
        button_sizer.AddStretchSpacer()
        
        self.update_btn = wx.Button(self.basic_panel, label="Update yt-dlp")
        self.update_btn.Bind(wx.EVT_BUTTON, self.on_update_ytdlp)
        button_sizer.Add(self.update_btn, 0)
        
        sizer.Add(button_sizer, 0, wx.EXPAND | wx.ALL, 20)
        
        # Progress display
        progress_box = wx.StaticBox(self.basic_panel, label="Download Progress")
        progress_sizer = wx.StaticBoxSizer(progress_box, wx.VERTICAL)
        
        self.progress_text = wx.StaticText(self.basic_panel, label="Ready")
        progress_sizer.Add(self.progress_text, 0, wx.EXPAND | wx.ALL, 10)
        
        self.progress_gauge = wx.Gauge(self.basic_panel, style=wx.GA_HORIZONTAL)
        progress_sizer.Add(self.progress_gauge, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        
        sizer.Add(progress_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        self.basic_panel.SetSizer(sizer)
    
    def init_advanced_panel(self):
        """Initialize advanced settings panel"""
        sizer = wx.BoxSizer(wx.VERTICAL)
        
        # Proxy settings
        proxy_box = wx.StaticBox(self.advanced_panel, label="Proxy Settings")
        proxy_sizer = wx.StaticBoxSizer(proxy_box, wx.VERTICAL)
        
        self.use_proxy_check = wx.CheckBox(self.advanced_panel, label="Enable Proxy")
        proxy_sizer.Add(self.use_proxy_check, 0, wx.ALL, 10)
        
        proxy_config_sizer = wx.FlexGridSizer(2, 6, 5, 10)
        proxy_config_sizer.AddGrowableCol(3)
        
        proxy_config_sizer.Add(wx.StaticText(self.advanced_panel, label="Type:"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.proxy_type_choice = wx.Choice(self.advanced_panel, choices=["http", "https", "socks5"])
        self.proxy_type_choice.SetSelection(0)
        proxy_config_sizer.Add(self.proxy_type_choice, 0)
        
        proxy_config_sizer.Add(wx.StaticText(self.advanced_panel, label="Host:"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.proxy_host_text = wx.TextCtrl(self.advanced_panel, value="127.0.0.1")
        proxy_config_sizer.Add(self.proxy_host_text, 1, wx.EXPAND)
        
        proxy_config_sizer.Add(wx.StaticText(self.advanced_panel, label="Port:"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.proxy_port_text = wx.TextCtrl(self.advanced_panel, value="7890")
        proxy_config_sizer.Add(self.proxy_port_text, 0)
        
        proxy_sizer.Add(proxy_config_sizer, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        sizer.Add(proxy_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Cookies settings
        cookies_box = wx.StaticBox(self.advanced_panel, label="Browser Cookies")
        cookies_sizer = wx.StaticBoxSizer(cookies_box, wx.VERTICAL)
        
        self.use_cookies_check = wx.CheckBox(self.advanced_panel, label="Use Browser Cookies")
        cookies_sizer.Add(self.use_cookies_check, 0, wx.ALL, 10)
        
        browser_sizer = wx.BoxSizer(wx.HORIZONTAL)
        browser_sizer.Add(wx.StaticText(self.advanced_panel, label="Browser:"), 0, 
                         wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        
        self.browser_choice = wx.Choice(self.advanced_panel, choices=["chrome", "firefox", "safari", "edge"])
        self.browser_choice.SetSelection(0)
        browser_sizer.Add(self.browser_choice, 0)
        
        cookies_sizer.Add(browser_sizer, 0, wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        sizer.Add(cookies_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        self.advanced_panel.SetSizer(sizer)
    
    def init_log_panel(self):
        """Initialize log panel"""
        sizer = wx.BoxSizer(wx.VERTICAL)
        
        # Control buttons
        controls_sizer = wx.BoxSizer(wx.HORIZONTAL)
        
        self.clear_log_btn = wx.Button(self.log_panel, label="Clear Log")
        self.clear_log_btn.Bind(wx.EVT_BUTTON, self.on_clear_log)
        controls_sizer.Add(self.clear_log_btn, 0, wx.RIGHT, 10)
        
        self.auto_scroll_check = wx.CheckBox(self.log_panel, label="Auto Scroll")
        self.auto_scroll_check.SetValue(True)
        controls_sizer.Add(self.auto_scroll_check, 0)
        
        sizer.Add(controls_sizer, 0, wx.EXPAND | wx.ALL, 10)
        
        # Log display area
        self.log_text = wx.TextCtrl(self.log_panel, style=wx.TE_MULTILINE | wx.TE_READONLY | wx.TE_WORDWRAP)
        self.log_text.SetFont(wx.Font(10, wx.FONTFAMILY_TELETYPE, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL))
        sizer.Add(self.log_text, 1, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        
        self.log_panel.SetSizer(sizer)
    
    def on_close(self, event):
        """Handle window close event, cleanup resources"""
        # Stop timer
        if hasattr(self, 'log_timer') and self.log_timer.IsRunning():
            self.log_timer.Stop()
        
        # Stop download thread
        if hasattr(self, 'download_worker') and self.download_worker:
            self.download_worker.stop()
        
        # Destroy window
        self.Destroy()
    
    def on_browse(self, event):
        """Browse folder"""
        dlg = wx.DirDialog(self, "Select Download Path", defaultPath=self.path_text.GetValue())
        if dlg.ShowModal() == wx.ID_OK:
            self.path_text.SetValue(dlg.GetPath())
        dlg.Destroy()
    
    def log_message(self, message, is_error=False):
        """Add log message to queue"""
        self.log_queue.put((message, is_error))
    
    def update_log_display(self, event):
        """Update log display"""
        try:
            while True:
                message, is_error = self.log_queue.get_nowait()
                
                # Insert message
                self.log_text.AppendText(message + "\n")
                
                # Auto scroll to bottom
                if self.auto_scroll_check.GetValue():
                    self.log_text.SetInsertionPointEnd()
                    
        except queue.Empty:
            pass
    
    def on_clear_log(self, event):
        """Clear log"""
        self.log_text.Clear()
    
    def show_system_info(self):
        """Show system information"""
        system = platform.system()
        version = platform.version()
        python_version = platform.python_version()
        python_executable = sys.executable
        
        self.log_message(f"🖥️ System: {system} {version}")
        self.log_message(f"🐍 Python: {python_version}")
        self.log_message(f"📍 Python Path: {python_executable}")
        
        # Detect Python environment type
        env_info = self.detect_python_environment()
        if env_info:
            self.log_message(f"🏠 Python Environment: {env_info}")
        
        try:
            wx_version = wx.version()
            self.log_message(f"🎨 GUI Framework: wxPython {wx_version}")
        except:
            self.log_message(f"🎨 GUI Framework: wxPython")
            
        self.log_message("📦 Checking yt-dlp...")
    
    def detect_python_environment(self):
        """Detect Python environment type"""
        # Detect virtual environment
        if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
            return "Virtual Environment (venv/virtualenv)"
        
        # Detect Anaconda
        if 'conda' in sys.executable.lower():
            return "Anaconda/Miniconda"
        
        # Detect system specific paths
        if platform.system() == "Windows":
            if 'windowsapps' in sys.executable.lower():
                return "Microsoft Store Version"
        elif platform.system() == "Darwin":  # macOS
            if '/opt/homebrew' in sys.executable:
                return "Homebrew Version (Apple Silicon)"
            elif '/usr/local' in sys.executable:
                return "Homebrew Version (Intel)"
        
        return "System Python"
    
    def get_ytdlp_path(self):
        """Get correct yt-dlp path or command"""
        # Check if in virtual environment
        if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
            # In virtual environment, try venv yt-dlp executable first
            venv_yt_dlp = Path(sys.executable).parent / 'yt-dlp'
            if venv_yt_dlp.exists():
                return str(venv_yt_dlp)
        
        # If no executable but has yt-dlp module, return None to indicate module usage
        try:
            import yt_dlp
            return None  # Indicates using module method
        except ImportError:
            pass
        
        # Default return system yt-dlp
        return 'yt-dlp'
    
    def on_check_formats(self, event):
        """Check available formats"""
        url = self.url_text.GetValue().strip()
        if not url or url == "Enter YouTube or other video website URL...":
            wx.MessageBox("Please enter video URL first!", "Warning", wx.OK | wx.ICON_WARNING)
            return
        
        self.log_message("🔍 Checking available formats...")
        
        def check_formats():
            try:
                # Use correct yt-dlp path
                ytdlp_path = self.get_ytdlp_path()
                if ytdlp_path is None:
                    # Use Python module method
                    cmd = [sys.executable, '-m', 'yt_dlp', '--list-formats', url]
                else:
                    # Use executable method
                    cmd = [ytdlp_path, '--list-formats', url]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                
                if result.returncode == 0:
                    wx.CallAfter(self.log_message, "📋 Available formats:")
                    for line in result.stdout.split('\n'):
                        if line.strip():
                            wx.CallAfter(self.log_message, line)
                else:
                    wx.CallAfter(self.log_message, f"❌ Format check failed: {result.stderr}", True)
            except subprocess.TimeoutExpired:
                wx.CallAfter(self.log_message, "⏰ Format check timeout", True)
            except Exception as e:
                wx.CallAfter(self.log_message, f"❌ Format check error: {e}", True)
        
        # Run in background thread
        threading.Thread(target=check_formats, daemon=True).start()
    
    def on_start_download(self, event):
        """Start download"""
        # Get URL
        url = self.url_text.GetValue().strip()
        if not url or url == "Enter YouTube or other video website URL...":
            wx.MessageBox("Please enter video URL!", "Warning", wx.OK | wx.ICON_WARNING)
            return
        
        # Get save path
        save_path = self.path_text.GetValue().strip()
        if not save_path:
            wx.MessageBox("Please select download path!", "Warning", wx.OK | wx.ICON_WARNING)
            return
        
        # Ensure path exists
        Path(save_path).mkdir(parents=True, exist_ok=True)
        
        # Build command
        # Use correct yt-dlp path
        ytdlp_path = self.get_ytdlp_path()
        if ytdlp_path is None:
            # Use Python module method
            cmd = [sys.executable, '-m', 'yt_dlp', '--newline']
        else:
            # Use executable method
            cmd = [ytdlp_path, '--newline']
        
        # Add format selection
        format_selection = self.format_choice.GetStringSelection()
        if format_selection.startswith("Custom"):
            custom_format = self.custom_format_text.GetValue().strip()
            if custom_format:
                cmd.extend(['-f', custom_format])
        else:
            # Extract actual format string
            format_code = format_selection.split('(')[0].strip()
            if format_code:
                cmd.extend(['-f', format_code])
        
        # Add output path
        cmd.extend(['-o', f'{save_path}/%(title)s.%(ext)s'])
        
        # Add proxy settings
        if self.use_proxy_check.GetValue():
            proxy_type = self.proxy_type_choice.GetStringSelection()
            proxy_host = self.proxy_host_text.GetValue().strip()
            proxy_port = self.proxy_port_text.GetValue().strip()
            proxy_url = f"{proxy_type}://{proxy_host}:{proxy_port}"
            cmd.extend(['--proxy', proxy_url])
        
        # Add Cookies settings
        if self.use_cookies_check.GetValue():
            browser = self.browser_choice.GetStringSelection()
            cmd.extend(['--cookies-from-browser', browser])
        
        # Add JavaScript runtime
        cmd.extend(['--js-runtimes', 'node'])
        
        # Add URL
        cmd.append(url)
        
        self.log_message(f"🚀 Starting download: {url}")
        self.log_message(f"💾 Save to: {save_path}")
        self.log_message(f"⚙️ Command: {' '.join(cmd)}")
        
        # Update UI state
        self.download_btn.Enable(False)
        self.stop_btn.Enable(True)
        self.progress_text.SetLabel("Downloading...")
        self.progress_gauge.Pulse()
        
        # Start download thread
        self.download_worker = DownloadWorker(
            cmd, 
            self.log_message_threadsafe,
            self.update_progress_threadsafe,
            self.download_finished_threadsafe
        )
        self.download_worker.start()
    
    def on_stop_download(self, event):
        """Stop download"""
        if self.download_worker:
            self.download_worker.stop()
            self.log_message("🛑 Stopping download...")
    
    def log_message_threadsafe(self, message, is_error=False):
        """Thread-safe log message"""
        wx.CallAfter(self.log_message, message, is_error)
    
    def update_progress_threadsafe(self, progress_text):
        """Thread-safe progress update"""
        wx.CallAfter(self.progress_text.SetLabel, progress_text)
        wx.CallAfter(self.log_message, progress_text)
    
    def download_finished_threadsafe(self, success, message):
        """Thread-safe download completion callback"""
        def update_ui():
            # Update UI state
            self.download_btn.Enable(True)
            self.stop_btn.Enable(False)
            self.progress_gauge.SetValue(0)
            
            if success:
                self.progress_text.SetLabel("Download completed!")
                self.log_message(f"✅ {message}")
                wx.MessageBox(message, "Success", wx.OK | wx.ICON_INFORMATION)
            else:
                self.progress_text.SetLabel("Download failed")
                self.log_message(f"❌ {message}", True)
                wx.MessageBox(message, "Error", wx.OK | wx.ICON_ERROR)
            
            self.download_worker = None
        
        wx.CallAfter(update_ui)
    
    def on_update_ytdlp(self, event):
        """Update yt-dlp"""
        self.log_message("🔄 Updating yt-dlp and yt-dlp[default]...")
        
        def update_worker():
            try:
                cmd1 = [sys.executable, '-m', 'pip', 'install', '-U', 'yt-dlp']
                cmd2 = [sys.executable, '-m', 'pip', 'install', '-U', 'yt-dlp[default]']
                result1 = subprocess.run(cmd1, capture_output=True, text=True, timeout=60)
                result2 = subprocess.run(cmd2, capture_output=True, text=True, timeout=60) 
                
                if result1.returncode == 0 and result2.returncode == 0:
                    wx.CallAfter(self.log_message, "✅ yt-dlp and yt-dlp[default] updated successfully!")
                elif result1.returncode == 0 and result2.returncode != 0:
                    wx.CallAfter(self.log_message, f"❌ yt-dlp[default] update failed: {result2.stderr}", True)
                elif result1.returncode != 0 and result2.returncode == 0:
                    wx.CallAfter(self.log_message, f"❌ yt-dlp update failed: {result1.stderr}", True)
                else:
                    wx.CallAfter(self.log_message, f"❌ yt-dlp update failed: {result1.stderr}", True)
                    wx.CallAfter(self.log_message, f"❌ yt-dlp[default] update failed: {result2.stderr}", True)
            except subprocess.TimeoutExpired:
                wx.CallAfter(self.log_message, "⏰ Update timeout", True)
            except Exception as e:
                wx.CallAfter(self.log_message, f"❌ Update error: {e}", True)
        
        threading.Thread(target=update_worker, daemon=True).start()


class MainFrame(wx.Frame):
    """Main window class"""
    def __init__(self):
        super().__init__(None, title="yt-dlp GUI Downloader - Cross-platform Video Download Tool (wxPython Version)")
        
        # Set window size
        self.SetSize((900, 800))
        self.Center()
        
        # Create main panel
        self.panel = MainPanel(self)
        
        # Create menu bar
        self.create_menu_bar()
        
        # Create status bar
        self.CreateStatusBar()
        self.SetStatusText("Ready")
        
        # Bind close event
        self.Bind(wx.EVT_CLOSE, self.on_close)
    
    def create_menu_bar(self):
        """Create menu bar"""
        menubar = wx.MenuBar()
        
        # File menu
        file_menu = wx.Menu()
        exit_item = file_menu.Append(wx.ID_EXIT, "Exit\tCtrl+Q")
        self.Bind(wx.EVT_MENU, self.on_exit, exit_item)
        
        # Help menu
        help_menu = wx.Menu()
        about_item = help_menu.Append(wx.ID_ABOUT, "About")
        self.Bind(wx.EVT_MENU, self.on_about, about_item)
        
        menubar.Append(file_menu, "File")
        menubar.Append(help_menu, "Help")
        
        self.SetMenuBar(menubar)
    
    def on_exit(self, event):
        """Exit program"""
        self.Close()
    
    def on_close(self, event):
        """Handle main window close event"""
        # Notify panel to cleanup
        if hasattr(self, 'panel'):
            self.panel.on_close(event)
        
        # Destroy window
        self.Destroy()
    
    def on_about(self, event):
        """About dialog"""
        info = wx.adv.AboutDialogInfo()
        info.SetName("yt-dlp GUI")
        info.SetVersion("2.0 (wxPython Version)")
        info.SetDescription("A simple and easy-to-use YouTube downloader with graphical interface\nBuilt with wxPython, cross-platform compatible")
        info.SetWebSite("https://github.com/yt-dlp/yt-dlp")
        
        wx.adv.AboutBox(info)


class YtDlpApp(wx.App):
    """Application class"""
    def OnInit(self):
        frame = MainFrame()
        frame.Show()
        return True


def main():
    """Main function"""
    app = YtDlpApp()
    app.MainLoop()


if __name__ == "__main__":
    main()
