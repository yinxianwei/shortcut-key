#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
swift build -c release --arch arm64
bin_path="$(swift build -c release --arch arm64 --show-bin-path)"

app="${PWD}/dist/ShortcutKey.app"
rm -rf "${app}"
mkdir -p "${app}/Contents/MacOS"
mkdir -p "${app}/Contents/Resources"
cp Resources/Info.plist "${app}/Contents/Info.plist"
cp Resources/AppIconCompact.icns "${app}/Contents/Resources/AppIconCompact.icns"
cp "${bin_path}/ShortcutKey" "${app}/Contents/MacOS/ShortcutKey"
codesign --force --deep --sign - "${app}"
echo "Built ${app}"
