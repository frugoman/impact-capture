#!/bin/bash
# Builds a Developer ID signed, notarized, stapled Impact Capture.dmg ready to share.
#
# One-time setup:
#   1. Xcode › Settings › Accounts › your team › Manage Certificates › + › Developer ID Application
#   2. Create an app-specific password at https://account.apple.com, then store it:
#        xcrun notarytool store-credentials impact-capture --apple-id <you@example.com> --team-id <TEAMID>
#
# Usage: TEAM_ID=<TEAMID> scripts/release.sh
set -euo pipefail

cd "$(dirname "$0")/.."

TEAM_ID="${TEAM_ID:?Set TEAM_ID to your Apple Developer team id}"
PROFILE="${NOTARY_PROFILE:-impact-capture}"
BUILD="build/release"
ARCHIVE="$BUILD/ImpactCapture.xcarchive"
EXPORT="$BUILD/export"
VERSION="$(grep -m1 'MARKETING_VERSION' project.yml | sed -E 's/.*"(.*)".*/\1/')"
DMG="$BUILD/Impact-Capture-$VERSION.dmg"

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "No Developer ID Application certificate found. See the setup steps at the top of this script." >&2
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
xcodegen generate --quiet

echo "==> Archiving $VERSION"
xcodebuild archive \
  -project ImpactCapture.xcodeproj \
  -scheme ImpactCapture \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -derivedDataPath "$BUILD/DerivedData" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  -quiet

cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
PLIST

echo "==> Exporting"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" -exportOptionsPlist "$BUILD/ExportOptions.plist" -quiet

echo "==> Building DMG"
STAGING="$BUILD/dmg"
mkdir -p "$STAGING"
cp -R "$EXPORT/ImpactCapture.app" "$STAGING/Impact Capture.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Impact Capture" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "Developer ID Application" --timestamp "$DMG"

echo "==> Notarizing (this takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Done: $DMG"
