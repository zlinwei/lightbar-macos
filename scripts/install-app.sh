#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
set -eu
cd "$(dirname "$0")/.."
SOURCE="$PWD/build/MiLightBar.app"
DESTINATION="/Applications/MiLightBar.app"
[ -d "$SOURCE" ] || { echo '请先运行 scripts/build-app.sh'; exit 1; }
codesign --verify --deep --strict "$SOURCE"
if [ -e "$DESTINATION" ]; then
    ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist")
    [ "$ID" = 'com.zlinwei.MiLightBar' ] || { echo '目标位置是其他应用，已停止。'; exit 1; }
fi
STAGING=$(mktemp -d /Applications/.MiLightBar-install.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
/usr/bin/ditto "$SOURCE" "$STAGING/MiLightBar.app"
codesign --verify --deep --strict "$STAGING/MiLightBar.app"
if [ -e "$DESTINATION" ]; then
    BACKUPS="$HOME/Library/Application Support/MiLightBar/AppBackups"
    mkdir -p "$BACKUPS"
    BACKUP=$(mktemp -d "$BACKUPS/previous.XXXXXX")
    mv "$DESTINATION" "$BACKUP/MiLightBar.app"
    if ! mv "$STAGING/MiLightBar.app" "$DESTINATION"; then
        mv "$BACKUP/MiLightBar.app" "$DESTINATION"
        exit 1
    fi
    printf 'Previous app: %s\n' "$BACKUP/MiLightBar.app"
else
    mv "$STAGING/MiLightBar.app" "$DESTINATION"
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
printf 'Installed: %s\n' "$DESTINATION"
