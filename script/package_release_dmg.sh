#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BenfordCheck"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGE_DIR="$DIST_DIR/release-stage"
RELEASE_DIR="$DIST_DIR/releases"

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)}"
VERSION_LABEL="${VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
VOLUME_NAME="$APP_NAME $VERSION_LABEL"

mkdir -p "$RELEASE_DIR"

APP_VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" "$ROOT_DIR/script/build_and_run.sh" --bundle

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict "$APP_BUNDLE"
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

ditto "$APP_BUNDLE" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

cat >"$STAGE_DIR/README.txt" <<TXT
$APP_NAME $VERSION_LABEL

Install:
1. Open $APP_NAME.app from this DMG.
2. Drag $APP_NAME.app into Applications.

Notes:
- This build is unsigned and not notarized unless a signing identity was provided.
- Unsigned builds may trigger Gatekeeper warnings on other Macs.
TXT

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

echo "$DMG_PATH"
