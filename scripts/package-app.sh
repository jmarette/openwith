#!/usr/bin/env bash
# Builds, signs and packages OpenWith.app and OpenWithPane.prefPane:
#   dist/OpenWith-<version>.dmg        (the app, with an /Applications shortcut)
#   dist/OpenWith-Pane-<version>.zip   (the PrefPane)
# plus .sha256 files for each.
#
# Signing: ad-hoc ("-") by default — no Apple Developer account. The day a
# Developer ID exists, export SIGN_IDENTITY="Developer ID Application: …"
# and (optionally) wire the notarize step; nothing else changes.
#
# Usage: scripts/package-app.sh [output-dir]   (default: dist)
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-dist}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
VERSION=$(sed -n 's/^version = "\(.*\)"$/\1/p' dist-workspace.toml | head -1)

if [[ ! -d Apps ]]; then
  echo "Apps/ does not exist yet; nothing to package." >&2
  exit 0
fi

DERIVED=build/DerivedData
PRODUCTS="$DERIVED/Build/Products/Release"
mkdir -p "$OUT"

for scheme in OpenWithApp OpenWithPane; do
  xcodebuild \
    -project Apps/OpenWith.xcodeproj \
    -scheme "$scheme" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build | tail -2
done

codesign --force --deep --sign "$SIGN_IDENTITY" "$PRODUCTS/OpenWith.app"
codesign --force --deep --sign "$SIGN_IDENTITY" "$PRODUCTS/OpenWithPane.prefPane"

# App → dmg with an /Applications shortcut.
DMG="$OUT/OpenWith-$VERSION.dmg"
STAGING=$(mktemp -d)
cp -R "$PRODUCTS/OpenWith.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "OpenWith" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGING"

# PrefPane → zip.
ZIP="$OUT/OpenWith-Pane-$VERSION.zip"
ditto -c -k --keepParent "$PRODUCTS/OpenWithPane.prefPane" "$ZIP"

for artifact in "$DMG" "$ZIP"; do
  (cd "$(dirname "$artifact")" && shasum -a 256 "$(basename "$artifact")" > "$(basename "$artifact").sha256")
done

echo "packaged:"
ls -lh "$OUT"/OpenWith-*
