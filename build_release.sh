#!/bin/bash
#
# build_release.sh — builds a signed, distributable PunctoDock.app and zips it.
#
# Output:
#   dist/PunctoDock.app   the built app
#   dist/PunctoDock.zip   ready to attach to a GitHub Release / hand to a user
#
# Requirements: full Xcode (not just Command Line Tools). The script points
# DEVELOPER_DIR at /Applications/Xcode.app automatically if needed.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Build OUTSIDE the project tree. This repo may live in an iCloud-synced folder
# (~/Documents), where the file provider stamps com.apple.FinderInfo onto build
# products — which codesign rejects ("resource fork ... detritus not allowed").
# A scratch dir under the system temp area is never file-provider managed.
BUILD_DIR="${TMPDIR:-/tmp}/PunctoDock-release-build"
DIST="$ROOT/dist"
APP_NAME="PunctoDock"

# Use full Xcode for xcodebuild (Command Line Tools alone cannot build .app targets).
if ! xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

echo "→ Ensuring stable signing identity ..."
./setup_signing.sh >/dev/null

echo "→ Regenerating Xcode project ..."
python3 generate_xcodeproj.py >/dev/null

echo "→ Building Release ..."
rm -rf "$BUILD_DIR"
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build >/dev/null

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP" ]; then
    echo "✗ Build did not produce $APP" >&2
    exit 1
fi

echo "→ Packaging ..."
rm -rf "$DIST"
mkdir -p "$DIST"
# Zip straight from the clean (non-synced) build dir so the archived bundle keeps its
# valid signature and no FinderInfo detritus.
( cd "$(dirname "$APP")" && ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$DIST/$APP_NAME.zip" )
# Also drop an unzipped copy in dist for convenience; strip the FinderInfo the synced
# folder will add so the copy still verifies.
cp -R "$APP" "$DIST/$APP_NAME.app"
xattr -cr "$DIST/$APP_NAME.app" 2>/dev/null || true

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo '?')"
echo ""
echo "✓ Built $APP_NAME $VERSION"
echo "  App:  $DIST/$APP_NAME.app"
echo "  Zip:  $DIST/$APP_NAME.zip  ($(du -h "$DIST/$APP_NAME.zip" | cut -f1))"
echo ""
echo "Verify signature:"
codesign -dvvv "$DIST/$APP_NAME.app" 2>&1 | grep -E 'Authority|Signature=' || true
echo ""
echo "To publish (only when you choose to): attach dist/$APP_NAME.zip to a GitHub Release."
