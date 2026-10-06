#!/bin/bash
# Build the native or universal Screen Measurement Toolkit application.
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Screen Measurement Toolkit.app"
EXECUTABLE="ScreenMeasurementToolkit"
VERSION=${APP_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "APP_VERSION must be numeric major.minor.patch" >&2
  exit 1
fi
mkdir -p build
if [[ ! -f Resources/AppIcon.icns || Resources/AppIcon-1024.png -nt Resources/AppIcon.icns || Tools/make-icon.swift -nt Resources/AppIcon.icns ]]; then
  swift Tools/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi
swift build -c release
BINARIES=(".build/release/$EXECUTABLE")
if [[ "${1:-}" != "--fast" ]]; then
  HOST_ARCH=$(uname -m)
  OTHER_ARCH=$([[ "$HOST_ARCH" == "arm64" ]] && echo x86_64 || echo arm64)
  swift build -c release --triple "$OTHER_ARCH-apple-macosx13.0" --scratch-path ".build-$OTHER_ARCH"
  BINARIES+=(".build-$OTHER_ARCH/release/$EXECUTABLE")
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/AppIcon.svg Resources/StatusIcon.png Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp NOTICE "$APP/Contents/Resources/NOTICE.txt"
cp docs/USER_GUIDE.zh-CN.md "$APP/Contents/Resources/USER_GUIDE.zh-CN.md"
lipo -create -output "$APP/Contents/MacOS/$EXECUTABLE" "${BINARIES[@]}"
printf 'APPL????' > "$APP/Contents/PkgInfo"
SIGNING_OPTIONS=(--force --options runtime --sign "${CODESIGN_IDENTITY:--}")
if [[ "${CODESIGN_IDENTITY:--}" != "-" ]]; then SIGNING_OPTIONS+=(--timestamp); fi
codesign "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP — $VERSION — $(lipo -archs "$APP/Contents/MacOS/$EXECUTABLE")"
