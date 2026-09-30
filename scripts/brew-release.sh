#!/bin/bash
# Builds Impact Capture, publishes it as a GitHub release, and updates the Homebrew cask in frugoman/homebrew-tap.
#
# The app is signed with the project's Apple Development identity but not notarized, so the cask drops the
# quarantine flag after install. For a notarized DMG, use scripts/release.sh instead.
#
# Usage: scripts/brew-release.sh   (releases the MARKETING_VERSION in project.yml)
set -euo pipefail

cd "$(dirname "$0")/.."

REPO=frugoman/impact-capture
TAP=frugoman/homebrew-tap
BUILD="build/brew"
VERSION="$(grep -m1 'MARKETING_VERSION' project.yml | sed -E 's/.*"(.*)".*/\1/')"
ZIP="$BUILD/Impact-Capture-$VERSION.zip"

if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
  echo "v$VERSION is already released. Bump MARKETING_VERSION in project.yml first." >&2
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
xcodegen generate --quiet

echo "==> Building $VERSION"
xcodebuild build \
  -project ImpactCapture.xcodeproj \
  -scheme ImpactCapture \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD/DerivedData" \
  -quiet

cp -R "$BUILD/DerivedData/Build/Products/Release/ImpactCapture.app" "$BUILD/Impact Capture.app"
ditto -c -k --keepParent "$BUILD/Impact Capture.app" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

echo "==> Publishing GitHub release v$VERSION"
gh release create "v$VERSION" "$ZIP" --repo "$REPO" --title "Impact Capture $VERSION" --generate-notes

echo "==> Updating the cask in $TAP"
TMP=$(mktemp -d)
gh repo clone "$TAP" "$TMP" -- --quiet
mkdir -p "$TMP/Casks"
cat > "$TMP/Casks/impact-capture.rb" <<CASK
cask "impact-capture" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$REPO/releases/download/v#{version}/Impact-Capture-#{version}.zip"
  name "Impact Capture"
  desc "Menu bar app that captures the work that never makes it into a commit"
  homepage "https://github.com/$REPO"

  depends_on macos: :sequoia

  app "Impact Capture.app"

  # The app is not notarized, so drop the quarantine flag to let Gatekeeper open it.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Impact Capture.app"],
                          writable_paths: ["Impact Capture.app"], writable_base: :appdir
  end

  uninstall quit: "com.nicolasfrugoni.ImpactCapture"

  # Your captures folder is yours and is never removed.
  zap trash: "~/Library/Preferences/com.nicolasfrugoni.ImpactCapture.plist"

  caveats <<~EOS
    Open Impact Capture from /Applications to pick a captures folder and set your shortcuts.
  EOS
end
CASK
git -C "$TMP" add Casks/impact-capture.rb
git -C "$TMP" commit -m "impact-capture $VERSION" --quiet
git -C "$TMP" push --quiet
rm -rf "$TMP"

echo "==> Released $VERSION. Install with: brew install --cask frugoman/tap/impact-capture"
