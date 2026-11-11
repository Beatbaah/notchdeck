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
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with a stable identity when this Mac has one, so the Automation
# permission (Music/Spotify) survives rebuilds. Without one, sign ad hoc;
# macOS may then ask again after each rebuild. Override with
# NOTCHDECK_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)".
IDENTITY="${NOTCHDECK_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | head -1)"
fi
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP"
  echo "Signed with: $IDENTITY"
else
  codesign --force --sign - "$APP"
  echo "Signed ad hoc (no Apple Development identity found)"
fi

echo "Built $APP"
echo "Install:  cp -R \"$APP\" /Applications/ && open \"/Applications/${APP_NAME}.app\""
