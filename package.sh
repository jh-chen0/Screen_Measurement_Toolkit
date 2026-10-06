#!/bin/bash
# Build and package the current sources, including MIT and upstream attribution.
set -euo pipefail
cd "$(dirname "$0")"
[[ "${1:-}" == "--skip-build" ]] || ./build.sh
APP="build/Screen Measurement Toolkit.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
DIST="build/dist"
mkdir -p "$DIST"
codesign --verify --deep --strict "$APP"
lipo "$APP/Contents/MacOS/ScreenMeasurementToolkit" -verify_arch arm64 x86_64
ZIP="$DIST/Screen-Measurement-Toolkit-$VERSION-macOS.zip"
DMG="$DIST/Screen-Measurement-Toolkit-$VERSION-macOS.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
STAGE=$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Screen Measurement Toolkit.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE.txt"
cp NOTICE "$STAGE/NOTICE.txt"
cp docs/USER_GUIDE.zh-CN.md "$STAGE/使用说明.md"
hdiutil create -volname "Screen Measurement Toolkit" -fs HFS+ -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [[ "${CODESIGN_IDENTITY:--}" != "-" ]]; then
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" --identifier "$BUNDLE_ID.dmg" "$DMG"
  codesign --verify --strict "$DMG"
fi
hdiutil verify "$DMG"
python3 Tools/export-source.py --version "$VERSION"
(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" "Screen-Measurement-Toolkit-$VERSION-Source.zip") > "$DIST/SHA256SUMS.txt"
echo "Packaged $DMG and $ZIP"
