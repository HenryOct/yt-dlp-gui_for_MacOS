# yt-dlp GUI - macOS Quick Start Guide

🍎 **Optimized for macOS** - Full automation, one-click startup, stable downloads

## 🚀 Quick Start

### 📋 Requirements
- **macOS**: 10.14+ (Monterey 12+ recommended)
- **Python**: 3.8+ (Homebrew Python 3.13 recommended)
- **Shell**: Fish Shell or Bash (both supported)

### ⚡ One-Click Launch

```bash
# Method 1: Fish Shell (recommended)
./run.fish

# Method 2: Bash Shell
./run.sh
```

**What happens automatically**:
1. ✅ **Environment Check**: Detects and creates virtual environment
2. ✅ **Dependency Install**: Auto-installs wxPython + yt-dlp
3. ✅ **GUI Launch**: Opens native macOS interface
4. ✅ **Ready to Use**: No additional configuration needed

## 🎯 Usage Guide

### Basic Download
1. **Enter URL**: Paste YouTube/Bilibili/other video URL
2. **Choose Quality**: Use default "bestvideo+bestaudio/best[ext=mp4]" 
3. **Set Path**: Default is ~/Downloads (can be changed)
4. **Click Download**: Green button to start

### 🏆 Best Practices

#### Highest Success Rate
```
Format: bestvideo+bestaudio/best[ext=mp4]
Cookies: ✅ Enable (Chrome/Safari)
Geo-bypass: ✅ Enable for restricted content
```

#### For Premium Content
- ✅ **Enable Cookies**: Auto-extracts login status
- 🌐 **Supports**: Bilibili VIP, YouTube Premium, etc.
- 🔐 **Privacy**: Uses browser's stored credentials

#### Network Issues
- 🌐 **Proxy Settings**: Built-in HTTP/SOCKS5 support
- 🔄 **Auto-retry**: Handles temporary network errors
- 📊 **Smart Selection**: Falls back to available formats

## 🛠️ Advanced Features

### Format Selection
- **🔍 Check Formats**: See all available qualities before download
- **📺 Custom Formats**: Expert users can specify custom format strings
- **🎵 Audio Only**: Extract audio tracks only
- **💾 Size Control**: Choose quality vs. file size balance

### Automation Features
- **📦 Batch Downloads**: Process playlists automatically
- **🔄 Error Handling**: Continues downloading despite individual failures
- **📝 Progress Logs**: Real-time download status and error details
- **🆙 Auto-updates**: Keep yt-dlp engine current

## 🔧 Technical Details

### Environment Management
- **🐍 Virtual Environment**: Isolated Python dependencies
- **📦 Package Management**: Auto-installs and updates packages
- **🏠 Homebrew Compatible**: Works with Homebrew Python
- **🛡️ Clean Isolation**: Doesn't affect system Python

### Supported Platforms
```
🍎 macOS: Primary target (10.14+)
🎨 GUI: wxPython (native Cocoa)
🐍 Python: 3.8+ (3.13 recommended)
🖥️ Shell: Fish Shell & Bash
```

## ⚠️ Troubleshooting

### Installation Issues

#### Homebrew Python (Recommended)
```bash
# Install/Update Homebrew Python
brew install python
brew upgrade python

# Verify installation
python3 --version
which python3
```

#### Permission Issues
```bash
# If pip permissions fail
python3 -m pip install --user PACKAGE_NAME

# If virtual environment creation fails
sudo chown -R $(whoami) /path/to/project
```

### Runtime Issues

#### GUI Won't Start
1. **Check Dependencies**: Run `./run.fish` again
2. **Python Version**: Ensure Python 3.8+
3. **Virtual Environment**: Delete `venv/` and restart

#### Download Failures
1. **Check URL**: Ensure valid video URL
2. **Enable Cookies**: For login-required content
3. **Use Proxy**: For geo-restricted content
4. **Check Formats**: Use "Check Available Formats" button

#### Network Problems
```bash
# Test basic connectivity
curl -I https://www.youtube.com

# Check proxy settings
echo $HTTP_PROXY $HTTPS_PROXY $ALL_PROXY

# Clear proxy if needed
unset ALL_PROXY HTTP_PROXY HTTPS_PROXY
```

### Performance Optimization

#### For Fast Downloads
- Use stable internet connection
- Enable parallel downloads when possible
- Choose appropriate quality (1080p usually optimal)

#### For Large Playlists
- Enable "Ignore errors and continue"
- Use batch download mode
- Monitor disk space

## 📱 Pro Tips

### Daily Usage
- **🔖 Bookmark URLs**: Save frequently downloaded channels
- **⏰ Off-peak Hours**: Download during low-traffic times
- **💾 Storage Management**: Regular cleanup of download folder

### Content Discovery
- **📺 Playlist Support**: Download entire playlists/channels
- **🔍 Format Preview**: Check video details before downloading
- **📊 Quality Information**: See bitrates, codecs, file sizes

### Privacy & Legal
- **🔐 Respect ToS**: Follow platform terms of service
- **👤 Personal Use**: Ensure downloads are for personal use
- **🌍 Copyright Aware**: Respect content creators' rights

## 📚 References

- **Official yt-dlp**: [GitHub Repository](https://github.com/yt-dlp/yt-dlp)
- **Supported Sites**: [Full List](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)
- **Format Selection**: [Format Documentation](https://github.com/yt-dlp/yt-dlp#format-selection)

---

🎉 **Enjoy hassle-free video downloading on macOS!**

> **Note**: This tool is for educational and personal use only. Please respect copyright laws and platform terms of service.
