#!/usr/bin/env bash
# Builds the universal (arm64 + x86_64) openwith CLI, ad-hoc signs it, and
# stages it where dist (cargo-dist) generic mode expects the binaries listed
# in dist.toml: the package root.
#
# Also usable standalone: scripts/build-universal.sh
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64 --product openwith

BIN=.build/apple/Products/Release/openwith

# No Apple Developer account: ad-hoc sign so arm64 machines will run it.
codesign --force --sign - "$BIN"

cp "$BIN" openwith
echo "built $(lipo -archs openwith 2>/dev/null || echo '?'): ./openwith"
