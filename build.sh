#!/bin/bash
# 一键构建 喵时 MeowTimer.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/MeowTimer.app"
ARCH="$(uname -m)"
SDKROOT="$(xcrun --show-sdk-path --sdk macosx)"

echo "==> 清理旧构建"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> 编译 Swift 源码（$(swiftc --version | head -1)）"
xcrun swiftc \
  -O \
  -swift-version 5 \
  -target "${ARCH}-apple-macos14.0" \
  -sdk "$SDKROOT" \
  -module-cache-path "$ROOT/.modulecache" \
  -disable-sandbox \
  -framework AppKit -framework SwiftUI -framework Combine -framework Carbon \
  "$ROOT/Sources/"*.swift \
  -o "$APP/Contents/MacOS/MeowTimer"

echo "==> 组装 .app"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [ -f "$ROOT/Resources/MeowTimer.icns" ]; then
  cp "$ROOT/Resources/MeowTimer.icns" "$APP/Contents/Resources/MeowTimer.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string MeowTimer" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> 自签名（ad-hoc）"
codesign --force --sign - --timestamp=none "$APP"

echo "==> 完成: $APP"
du -sh "$APP" | awk '{print "    体积: "$1}'
