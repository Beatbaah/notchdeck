#!/usr/bin/env bash
# Builds NotchDeck.app into ./build. Run on a Mac with Xcode or the Command Line Tools installed.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="NotchDeck"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS can track permissions (Automation) for the app.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Install:  cp -R \"$APP\" /Applications/ && open \"/Applications/${APP_NAME}.app\""
