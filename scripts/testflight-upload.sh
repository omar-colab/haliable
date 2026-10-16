#!/usr/bin/env bash
# Archive Haliable, export an App Store IPA, and upload it to TestFlight.
#
#   ./scripts/testflight-upload.sh
#
# No Xcode GUI and no fastlane. All six build configs already use
# CODE_SIGN_STYLE = Automatic, so `-allowProvisioningUpdates` plus an App Store
# Connect API key lets xcodebuild create the distribution certificate and the
# provisioning profile itself, on this machine, unattended.
#
# The API key must have the **Admin** role. App Manager and Developer can upload
# builds but cannot create signing certificates, which is the point of this script.
#
# Credentials come from the environment or from .env.asc (git-ignored):
#   ASC_KEY_ID      defaults to the id in the .p8 filename
#   ASC_ISSUER_ID   required — the UUID above the table on the API Keys page
#   ASC_KEY_PATH    defaults to ~/.appstoreconnect/private_keys/AuthKey_<id>.p8
#
# The .p8 itself is never printed, copied into the repo, or passed on a command
# line that would show up in `ps`.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

[ -f .env.asc ] && . ./.env.asc

KEY_DIR="$HOME/.appstoreconnect/private_keys"
ASC_KEY_PATH="${ASC_KEY_PATH:-$(ls "$KEY_DIR"/AuthKey_*.p8 2>/dev/null | head -1)}"
[ -n "${ASC_KEY_PATH:-}" ] && [ -f "$ASC_KEY_PATH" ] || {
  echo "No .p8 found in $KEY_DIR — see the header."; exit 1; }
ASC_KEY_ID="${ASC_KEY_ID:-$(basename "$ASC_KEY_PATH" .p8 | sed 's/^AuthKey_//')}"
[ -n "${ASC_ISSUER_ID:-}" ] || {
  echo "ASC_ISSUER_ID is not set. It is the UUID shown ABOVE the table on"
  echo "App Store Connect -> Users and Access -> Integrations, not the Key ID."
  exit 1; }

AUTH=(-authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID"
      -allowProvisioningUpdates)

OUT="${OUT:-build/testflight}"
ARCHIVE="$OUT/Haliable.xcarchive"
rm -rf "$OUT"; mkdir -p "$OUT"

# Every upload needs a build number App Store Connect has not seen before.
# agvtool is what fastlane's increment_build_number calls underneath, and it
# needs VERSIONING_SYSTEM = apple-generic, which the project now sets.
xcrun agvtool next-version -all >/dev/null
echo "Version $(xcrun agvtool what-marketing-version -terse1) build $(xcrun agvtool what-version -terse)"

echo "==> Archiving (creates the certificate and profile on first run)…"
xcodebuild archive \
  -scheme Haliable \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  "${AUTH[@]}" | tail -5

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>uploadSymbols</key><true/>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>UX6CT4G932</string>
  <key>provisioningProfiles</key>
  <dict><key>app.haliable.ios</key><string>Haliable App Store</string></dict>
</dict>
</plist>
PLIST

echo "==> Exporting the IPA…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$OUT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  "${AUTH[@]}" | tail -5

IPA=$(ls "$OUT"/*.ipa | head -1)
echo "==> Validating $IPA"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | tail -10

echo "==> Uploading to App Store Connect…"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | tail -10

echo
echo "Uploaded. Apple takes ~5-15 minutes to process the build."
echo "It then appears under TestFlight -> iOS builds. Internal testing needs NO"
echo "Apple review, so you can install it on your phone as soon as it processes."
