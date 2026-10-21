#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
set -eu
cd "$(dirname "$0")/.."
BUILD_MODE="${BUILD_MODE:-release}"
BUILD_ROOT="${BUILD_ROOT:-$PWD/.build}"
MODULE_CACHE="${MODULE_CACHE:-$BUILD_ROOT/ModuleCache}"
mkdir -p "$MODULE_CACHE"
xcrun swift build --disable-sandbox -c "$BUILD_MODE" --scratch-path "$BUILD_ROOT" -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE"
BIN_DIR=$(xcrun swift build --disable-sandbox -c "$BUILD_MODE" --scratch-path "$BUILD_ROOT" --show-bin-path)
APP="$PWD/build/MiLightBar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MiLightBar" "$APP/Contents/MacOS/MiLightBar"
xcrun swift -module-cache-path "$MODULE_CACHE" scripts/generate-icon.swift "$PWD/build/icon"
iconutil -c icns "$PWD/build/icon/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$PWD/build/icon/AppIcon-1024.png" "$APP/Contents/Resources/AppIcon-1024.png"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MiLightBar</string>
<key>CFBundleIdentifier</key><string>com.zlinwei.MiLightBar</string>
<key>CFBundleName</key><string>MiLightBar</string>
<key>CFBundleDisplayName</key><string>米家挂灯</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.2</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf '\nApp: %s\n' "$APP"
