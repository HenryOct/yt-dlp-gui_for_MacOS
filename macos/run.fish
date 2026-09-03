#!/opt/homebrew/bin/fish
# yt-dlp GUI startup script (Fish Shell version) - Auto-create virtual environment

# Get project root absolute path
set project_root (dirname (dirname (realpath (status --current-filename))))
set venv_python "$project_root/venv/bin/python"
set venv_pip "$project_root/venv/bin/pip"

# Enter project root directory
cd $project_root

# Check if virtual environment exists
if not test -d venv
    echo "Virtual environment does not exist, creating..."
    python3 -m venv venv
    echo "✓ Virtual environment created successfully"
end

# Clear possible proxy settings (avoid SOCKS errors)
set -e ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

# Check and install dependencies
echo "Checking dependencies..."

# Check wxPython
$venv_python -c "import wx" 2>/dev/null
if test $status -ne 0
    echo "Installing wxPython..."
    $venv_pip install wxPython
end

# Check yt-dlp  
$venv_python -c "import subprocess; subprocess.run(['yt-dlp', '--version'], capture_output=True, check=True)" 2>/dev/null
if test $status -ne 0
    echo "Installing yt-dlp..."
    $venv_pip install yt-dlp
end

echo "Starting yt-dlp GUI (wxPython version)..."
# Enter macos directory and run GUI program
cd $project_root/macos
$venv_python yt_dlp_gui_wx.py
