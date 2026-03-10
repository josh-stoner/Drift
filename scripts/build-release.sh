#!/usr/bin/env bash
# build-release.sh — Archive, package, and sign a Drift release.
# Usage: ./scripts/build-release.sh [version]
# Requires: Xcode CLI tools, XcodeGen

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="${1:-$(grep 'MARKETING_VERSION' "$PROJECT_DIR/project.yml" | head -1 | awk -F'"' '{print $2}')}"
BUILD_DIR="$PROJECT_DIR/release"
APP_NAME="Drift"

echo "==> Building $APP_NAME v$VERSION"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Regenerate project
cd "$PROJECT_DIR"
xcodegen generate --spec project.yml

# Resolve SPM packages
xcodebuild -resolvePackageDependencies \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -clonedSourcePackagesDirPath "$BUILD_DIR/.spm"

# Archive
echo "==> Archiving..."
xcodebuild archive \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  -clonedSourcePackagesDirPath "$BUILD_DIR/.spm" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME=YES \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  | tail -5

# Export app from archive
APP_PATH="$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Archive failed — $APP_PATH not found"
  exit 1
fi

# Copy to release dir
cp -R "$APP_PATH" "$BUILD_DIR/$APP_NAME.app"

# Create zip for GitHub release
echo "==> Packaging..."
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME-v$VERSION.zip"

echo "==> Built: $BUILD_DIR/$APP_NAME-v$VERSION.zip"
echo "==> Done. Next: sign with Sparkle and create appcast."

# Sign with Sparkle if key exists
SPARKLE_SIGN="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
if [ ! -f "$SPARKLE_SIGN" ]; then
  # Try SPM derived data path
  SPARKLE_SIGN=$(find "$BUILD_DIR/.spm" -name "sign_update" -type f 2>/dev/null | head -1)
fi

if [ -n "$SPARKLE_SIGN" ] && [ -f "$SPARKLE_SIGN" ]; then
  echo "==> Signing with Sparkle EdDSA..."
  SIGNATURE=$("$SPARKLE_SIGN" "$APP_NAME-v$VERSION.zip" 2>&1)
  echo "$SIGNATURE"
  echo "$SIGNATURE" > "$BUILD_DIR/signature-v$VERSION.txt"
  echo "==> Signature saved to $BUILD_DIR/signature-v$VERSION.txt"
else
  echo "==> Sparkle sign_update not found — skip Sparkle signing."
  echo "    Run 'xcodebuild -resolvePackageDependencies' first, then sign manually."
fi

echo ""
echo "Release artifact: $BUILD_DIR/$APP_NAME-v$VERSION.zip"
echo "Upload to GitHub release and update appcast.xml"
