#!/usr/bin/env bash
# Builds, signs, notarises and publishes a NotchDeck release on GitHub.
#
#   ./release.sh 1.0.0            build, sign with Developer ID, notarise, staple, tag, publish
#   ./release.sh 1.0.0 --no-publish   everything except the tag and GitHub release
#   ./release.sh 1.0.0 --local        sign with any identity (Apple Development is fine), no
#                                     notarising or publishing: to try the hardened runtime here
#
# One-time setup (see README → Releasing):
#   - a "Developer ID Application" certificate in your keychain (Xcode → Settings → Accounts)
#   - notarisation credentials saved as a keychain profile:
#       xcrun notarytool store-credentials notchdeck --apple-id <email> --team-id <TEAMID>
#   - gh logged in (gh auth login)
# Overrides: NOTCHDECK_RELEASE_IDENTITY, NOTCHDECK_NOTARY_PROFILE (default "notchdeck").
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "error: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

VERSION="${1:-}"
MODE="${2:-publish}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: ./release.sh <version like 1.0.0> [--no-publish|--local]"
case "$MODE" in publish|--no-publish|--local) ;; *) die "unknown option: $MODE" ;; esac

APP="build/NotchDeck.app"
ZIP="dist/NotchDeck-$VERSION.zip"
TAG="v$VERSION"
PROFILE="${NOTCHDECK_NOTARY_PROFILE:-notchdeck}"
identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

# ---- Checks first, so nothing is half done.
step "Checking setup"
if [ "$MODE" = "--local" ]; then
  IDENTITY="${NOTCHDECK_RELEASE_IDENTITY:-$(sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' <<<"$identities" | head -1)}"
  [ -n "$IDENTITY" ] || IDENTITY="$(sed -n 's/.*"\(Apple Development: .*\)"/\1/p' <<<"$identities" | head -1)"
  [ -n "$IDENTITY" ] || die "no signing certificate found"
else
  IDENTITY="${NOTCHDECK_RELEASE_IDENTITY:-$(sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' <<<"$identities" | head -1)}"
  [ -n "$IDENTITY" ] || die "no \"Developer ID Application\" certificate. Create one in Xcode → Settings → Accounts → (your paid team) → Manage Certificates → + (needs a paid Apple Developer Program membership)."
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || die "no notarisation credentials in keychain profile \"$PROFILE\". Run: xcrun notarytool store-credentials $PROFILE --apple-id <email> --team-id <TEAMID>"
fi
if [ "$MODE" = "publish" ]; then
  [ -z "$(git status --porcelain)" ] || die "uncommitted changes; commit them first so the release matches a commit"
  git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"
  gh auth status >/dev/null 2>&1 || die "gh isn't logged in (gh auth login)"
fi
echo "Signing as: $IDENTITY"

# ---- Build (build.sh makes the .app), stamp the version, re-sign for release.
step "Building $VERSION"
./build.sh >/dev/null
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(git rev-list --count HEAD)" "$APP/Contents/Info.plist"

step "Signing (hardened runtime)"
codesign --force --options runtime --timestamp --entitlements Support/NotchDeck.entitlements --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "automation.apple-events" || die "entitlements missing from the signature"

if [ "$MODE" = "--local" ]; then
  echo
  echo "Signed $APP with the hardened runtime (not notarised)."
  echo "Try it:  cp -R \"$APP\" /Applications/ && open /Applications/NotchDeck.app"
  exit 0
fi

# ---- Notarise: Apple scans the app; stapling attaches the ticket so it opens offline too.
step "Notarising (usually a few minutes)"
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
result="$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait --output-format json)"
status="$(plutil -extract status raw - <<<"$result" 2>/dev/null || true)"
if [ "$status" != "Accepted" ]; then
  id="$(plutil -extract id raw - <<<"$result" 2>/dev/null || true)"
  echo "$result" >&2
  [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2 || true
  die "notarisation status: ${status:-unknown}"
fi

step "Stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"   # zip again so the download carries the ticket
shasum -a 256 "$ZIP"

if [ "$MODE" = "--no-publish" ]; then
  echo; echo "Notarised: $ZIP (not published)"
  exit 0
fi

# ---- Publish.
step "Publishing $TAG on GitHub"
git tag -a "$TAG" -m "NotchDeck $VERSION"
git push origin "$TAG"
gh release create "$TAG" "$ZIP" --title "NotchDeck $VERSION" --generate-notes \
  --notes "Download NotchDeck-$VERSION.zip, unzip it and move NotchDeck.app to Applications. Requires macOS 13 or later."
echo; echo "Released $TAG."
