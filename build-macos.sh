#!/usr/bin/env bash
# Build Vita3K (Release, Ninja) on macOS and install it to /Applications.
#
#   ./build-macos.sh            build + install + reset Documents permission
#   ./build-macos.sh --no-install   build only
#
# Locally built Vita3K is ad-hoc signed, so macOS treats each build as a new
# app. If its old Documents-folder permission record lingers, file access in
# ~/Documents (where pref-path usually lives) blocks forever and games hang
# at boot. This script resets that record so macOS asks again on first launch.
set -euo pipefail
cd "$(dirname "$0")"

APP_SRC=build/macos-ninja/bin/Release/Vita3K.app
APP_DST=/Applications/Vita3K.app
BACKUP="$HOME/Vita3K-backup.app"
BUNDLE_ID=com.github.Vita3K.Vita3K

brew install cmake ninja molten-vk qt
git submodule update --init --recursive

cmake --preset macos-ninja
cmake --build build/macos-ninja --config Release

# Purpose string for the Documents prompt (Vita3K doesn't ship one).
PLIST="$APP_SRC/Contents/Info.plist"
chmod u+w "$PLIST"
plutil -replace NSDocumentsFolderUsageDescription \
    -string "Vita3K stores games and save data in your Documents folder." "$PLIST"
codesign --force --deep -s - "$APP_SRC"

[[ "${1:-}" == "--no-install" ]] && { echo "Built: $APP_SRC"; exit 0; }

osascript -e 'quit app "Vita3K"' 2>/dev/null || true
sleep 1
if [[ -d "$APP_DST" ]]; then
    rm -rf "$BACKUP"
    mv "$APP_DST" "$BACKUP"
    echo "Previous app backed up to $BACKUP"
fi
ditto "$APP_SRC" "$APP_DST"

tccutil reset SystemPolicyDocumentsFolder "$BUNDLE_ID"

cat <<EOF

Installed $APP_DST
First launch: close the Welcome window, then click Allow when macOS asks
for Documents access. If no prompt appears, enable it manually:
System Settings > Privacy & Security > Files & Folders > Vita3K > Documents
EOF
