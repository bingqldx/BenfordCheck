#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="BenfordCheck"
BUNDLE_ID="com.icecream-mac.BenfordCheck"
MIN_SYSTEM_VERSION="15.0"
APP_VERSION="${APP_VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo v0.0.0)}"
SHORT_VERSION="${APP_VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Assets/AppIconSource.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICON_FILE="$APP_RESOURCES/AppIcon.icns"
SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
codesign --remove-signature "$APP_BINARY" >/dev/null 2>&1 || true

ICON_PLIST_BLOCK=""

if [[ -f "$ICON_SOURCE" ]]; then
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  build_icon_png() {
    local size="$1"
    local name="$2"
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/$name" >/dev/null
  }

  build_icon_png 16 icon_16x16.png
  build_icon_png 32 icon_16x16@2x.png
  build_icon_png 32 icon_32x32.png
  build_icon_png 64 icon_32x32@2x.png
  build_icon_png 128 icon_128x128.png
  build_icon_png 256 icon_128x128@2x.png
  build_icon_png 256 icon_256x256.png
  build_icon_png 512 icon_256x256@2x.png
  build_icon_png 512 icon_512x512.png
  build_icon_png 1024 icon_512x512@2x.png

  iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
  rm -rf "$ICONSET_DIR"

  ICON_PLIST_BLOCK=$(cat <<'PLIST'
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
PLIST
)
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$SHORT_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  $ICON_PLIST_BLOCK
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

sign_app_bundle() {
  if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
  else
    codesign --force --deep --sign - "$APP_BUNDLE"
  fi

  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
}

sign_app_bundle

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --bundle|bundle)
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--bundle]" >&2
    exit 2
    ;;
esac
