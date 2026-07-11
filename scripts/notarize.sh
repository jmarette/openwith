#!/usr/bin/env bash
# Notarizes and staples the packaged artifacts. This is the future hook for
# the day an Apple Developer account exists — CI skips it while the secrets
# are absent, and it turns on with zero restructuring once they are set:
#
#   SIGN_IDENTITY     "Developer ID Application: …" (used by package-app.sh)
#   APPLE_API_KEY     base64 of the App Store Connect API .p8 key
#   APPLE_API_KEY_ID  the key id
#   APPLE_API_ISSUER  the issuer id
#
# Note: ad-hoc-signed artifacts cannot be notarized; package-app.sh must have
# run with a real SIGN_IDENTITY for this to succeed.
#
# Usage: scripts/notarize.sh [output-dir]   (default: dist)
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-dist}"
: "${APPLE_API_KEY:?APPLE_API_KEY (base64 .p8) is required}"
: "${APPLE_API_KEY_ID:?APPLE_API_KEY_ID is required}"
: "${APPLE_API_ISSUER:?APPLE_API_ISSUER is required}"

KEY_FILE=$(mktemp -t apple-api-key).p8
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$APPLE_API_KEY" | base64 -d > "$KEY_FILE"

for artifact in "$OUT"/OpenWith-*.dmg "$OUT"/OpenWith-Pane-*.zip; do
  [[ -e "$artifact" ]] || continue
  xcrun notarytool submit "$artifact" \
    --key "$KEY_FILE" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" \
    --wait
  # Zips cannot be stapled; dmgs can.
  if [[ "$artifact" == *.dmg ]]; then
    xcrun stapler staple "$artifact"
  fi
done

echo "notarization done"
