#!/usr/bin/env bash
# Writes Casks/openwith-app.rb on the Homebrew tap, pointing at the dmg the
# release published. Requires HOMEBREW_TAP_TOKEN (same secret dist uses for
# the CLI formula).
#
# Usage: scripts/update-cask.sh [output-dir]   (default: dist)
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-dist}"
TAP="${TAP:-jmarette/homebrew-tap}"
: "${HOMEBREW_TAP_TOKEN:?HOMEBREW_TAP_TOKEN is required}"

VERSION=$(sed -n 's/^version = "\(.*\)"$/\1/p' dist-workspace.toml | head -1)
SHA=$(cut -d' ' -f1 "$OUT/OpenWith-$VERSION.dmg.sha256")

TAP_DIR=$(mktemp -d)
trap 'rm -rf "$TAP_DIR"' EXIT
git clone --depth 1 "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${TAP}.git" "$TAP_DIR"

mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/openwith-app.rb" <<EOF
cask "openwith-app" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/jmarette/openwith/releases/download/v#{version}/OpenWith-#{version}.dmg"
  name "OpenWith"
  desc "GUI for managing macOS default applications"
  homepage "https://github.com/jmarette/openwith"

  depends_on macos: ">= :sequoia"

  app "OpenWith.app"

  caveats <<~EOS
    OpenWith.app is not notarized (the project has no Apple Developer
    account). On first launch macOS will refuse to open it; either
    right-click the app in Finder and choose Open, or clear the quarantine
    attribute:

      xattr -dr com.apple.quarantine /Applications/OpenWith.app
  EOS
end
EOF

cd "$TAP_DIR"
git add Casks/openwith-app.rb
if git diff --cached --quiet; then
  echo "cask already up to date"
  exit 0
fi
git -c user.name="github-actions[bot]" \
  -c user.email="github-actions[bot]@users.noreply.github.com" \
  commit -m "openwith-app $VERSION"
git push
echo "cask openwith-app $VERSION pushed to $TAP"
