#!/bin/bash

# Script to build and package Container Manager as a DMG
# Usage: ./scripts/create-dmg.sh [version]

set -e

# Configuration
APP_NAME="container-manager"
DISPLAY_NAME="Container Manager"
SCHEME_NAME="container-manager"

# Get version from argument or use "dev"
VERSION="${1:-dev-$(date +%Y%m%d-%H%M)}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "🏗️  Building Container Manager..."
echo "Version: $VERSION"
echo ""

# Clean and build
echo "🧹 Cleaning previous builds..."
rm -rf build/
rm -f *.dmg

echo "🔨 Building app..."
xcodebuild clean build \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | xcpretty || xcodebuild clean build \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Find the built app
echo "🔍 Finding built app..."
APP_PATH=$(find ./build -name "${APP_NAME}.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Error: Could not find ${APP_NAME}.app"
  echo "Build output:"
  ls -R ./build/Build/Products/
  exit 1
fi

echo "✅ Found app at: $APP_PATH"

# Create DMG staging directory
echo "📦 Preparing DMG contents..."
rm -rf dmg_contents/
mkdir -p dmg_contents/
cp -R "$APP_PATH" dmg_contents/

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
  echo "⚠️  create-dmg not found. Installing via Homebrew..."
  if command -v brew &> /dev/null; then
    brew install create-dmg
  else
    echo "⚠️  Homebrew not found. Using basic hdiutil instead..."
    hdiutil create -volname "$DISPLAY_NAME" -srcfolder dmg_contents -ov -format UDZO "$DMG_NAME"
    echo "✅ Basic DMG created: $DMG_NAME"
    ls -lh "$DMG_NAME"
    exit 0
  fi
fi

# Create the DMG with create-dmg
echo "🎨 Creating beautiful DMG..."
create-dmg \
  --volname "$DISPLAY_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 175 120 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 425 120 \
  --no-internet-enable \
  "$DMG_NAME" \
  "dmg_contents/" 2>/dev/null || {
    echo "⚠️  create-dmg had issues, falling back to hdiutil..."
    rm -f "$DMG_NAME"
    hdiutil create -volname "$DISPLAY_NAME" -srcfolder dmg_contents -ov -format UDZO "$DMG_NAME"
  }

# Cleanup
echo "🧹 Cleaning up..."
rm -rf dmg_contents/

# Success!
echo ""
echo "✅ DMG created successfully!"
echo "📦 File: $DMG_NAME"
echo "💾 Size: $(du -h "$DMG_NAME" | cut -f1)"
echo ""
echo "To test: open $DMG_NAME"
echo "To distribute: Upload $DMG_NAME to GitHub Releases or your server"
