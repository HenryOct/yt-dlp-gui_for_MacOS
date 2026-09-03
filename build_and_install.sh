#!/bin/bash
# Builds a Release .app for yt-dlp GUI, ad-hoc signs it (no paid Apple
# Developer account required — this only needs to run on this Mac), and
# installs it into /Applications. Re-run any time after changing the Swift
# source to rebuild and reinstall.
set -euo pipefail

cd "$(dirname "$0")/macos-swift"

if [ ! -f "YTDlpGUI.xcodeproj/project.pbxproj" ]; then
  echo "YTDlpGUI.xcodeproj is missing. If you edited project.yml, regenerate it with:" >&2
  echo "  brew install xcodegen && xcodegen generate" >&2
  exit 1
fi

BUILD_DIR="$(pwd)/build"
rm -rf "$BUILD_DIR"

echo "==> Building Release configuration..."
xcodebuild -project YTDlpGUI.xcodeproj -scheme YTDlpGUI -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  build

APP_SRC="$BUILD_DIR/Build/Products/Release/yt-dlp GUI.app"
APP_DEST="/Applications/yt-dlp GUI.app"

if [ ! -d "$APP_SRC" ]; then
  echo "Build did not produce an app bundle at: $APP_SRC" >&2
  exit 1
fi

echo "==> Installing to $APP_DEST ..."
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

echo "==> Ad-hoc signing..."
codesign --force --deep --sign - "$APP_DEST"

echo "==> Done. Launch it from /Applications, Spotlight, or:"
echo "    open \"$APP_DEST\""
