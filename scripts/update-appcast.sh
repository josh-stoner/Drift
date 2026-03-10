#!/usr/bin/env bash
# update-appcast.sh — Generate appcast.xml for Sparkle auto-update.
# Usage: ./scripts/update-appcast.sh <version> <signature> [download-url]
# Example: ./scripts/update-appcast.sh 1.0.0 "$(cat release/signature-v1.0.0.txt)"

set -euo pipefail

VERSION="${1:?Usage: update-appcast.sh <version> <signature> [download-url]}"
SIGNATURE="${2:?Missing signature}"
DOWNLOAD_URL="${3:-https://github.com/josh-stoner/Drift/releases/download/v${VERSION}/Drift-v${VERSION}.zip}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ZIP_PATH="$PROJECT_DIR/release/Drift-v${VERSION}.zip"

# Get file size
if [ -f "$ZIP_PATH" ]; then
  FILE_SIZE=$(stat -f%z "$ZIP_PATH")
else
  echo "WARNING: $ZIP_PATH not found — using placeholder size"
  FILE_SIZE="0"
fi

# Extract EdDSA signature and length from Sparkle sign_update output
# Format: sparkle:edSignature="..." length="..."
EDSIG=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$EDSIG" ]; then
  # Fallback: treat entire signature as the EdDSA value
  EDSIG="$SIGNATURE"
  LENGTH="$FILE_SIZE"
fi

cat > "$PROJECT_DIR/appcast.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Drift Updates</title>
    <description>Behavioral pattern awareness for focused work.</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$(date -R)</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="$DOWNLOAD_URL"
        sparkle:edSignature="$EDSIG"
        length="$LENGTH"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "==> appcast.xml updated for v$VERSION"
echo "    Upload appcast.xml to your GitHub release."
