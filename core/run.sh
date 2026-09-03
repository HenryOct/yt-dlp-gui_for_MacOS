#!/bin/bash
# yt-dlp GUI startup script (Bash version) - Auto-create virtual environment

# Get project root absolute path
PROJECT_ROOT="$(realpath "$(dirname "$(dirname "$0")")")"
VENV_PYTHON="$PROJECT_ROOT/venv/bin/python"
VENV_PIP="$PROJECT_ROOT/venv/bin/pip"

# Enter project root directory
cd "$PROJECT_ROOT"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment does not exist, creating..."
    python3.13 -m venv venv
    echo "✓ Virtual environment created successfully"
fi

# Clear possible proxy settings (avoid SOCKS errors)
unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

# Check and install dependencies
echo "Checking dependencies..."

# Check wxPython
"$VENV_PYTHON" -c "import wx" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Installing wxPython..."
    "$VENV_PIP" install wxPython
fi

# Check yt-dlp
"$VENV_PYTHON" -c "import subprocess; subprocess.run(['yt-dlp', '--version'], capture_output=True, check=True)" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Installing yt-dlp..."
    "$VENV_PIP" install yt-dlp
fi

echo "Starting yt-dlp GUI (wxPython version)..."
# Enter core directory and run GUI program
cd "$PROJECT_ROOT/core"
"$VENV_PYTHON" yt_dlp_gui_wx.py
