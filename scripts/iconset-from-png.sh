#!/bin/bash

# Generate macOS app icon set from a single 1024x1024 PNG
# Usage: ./scripts/iconset-from-png.sh path/to/icon-1024.png

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-1024x1024.png>"
    echo ""
    echo "Example: $0 ~/Desktop/my-icon.png"
    echo ""
    echo "This script will create all required icon sizes for a macOS app."
    exit 1
fi

SOURCE_IMAGE="$1"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: File not found: $SOURCE_IMAGE"
    exit 1
fi

# Verify it's actually 1024x1024 (or at least square)
WIDTH=$(sips -g pixelWidth "$SOURCE_IMAGE" | tail -1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight "$SOURCE_IMAGE" | tail -1 | awk '{print $2}')

if [ "$WIDTH" != "$HEIGHT" ]; then
    echo "⚠️  Warning: Image is not square (${WIDTH}x${HEIGHT})"
    echo "   App icons should be square. Continue anyway? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        exit 1
    fi
fi

if [ "$WIDTH" -lt 1024 ]; then
    echo "⚠️  Warning: Image is smaller than 1024x1024 (${WIDTH}x${HEIGHT})"
    echo "   Icons will be upscaled and may look blurry. Continue? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        exit 1
    fi
fi

echo "🎨 Creating macOS app icon set from: $SOURCE_IMAGE"
echo "   Source size: ${WIDTH}x${HEIGHT}"
echo ""

# Create iconset directory
ICONSET_DIR="AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Array of sizes needed for macOS
declare -a SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

echo "📦 Generating icon sizes..."
for size_info in "${SIZES[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    echo "   Creating ${size}x${size} → $filename"
    sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$ICONSET_DIR/$filename" > /dev/null 2>&1
done

echo "✅ Icon set created in $ICONSET_DIR/"
echo ""

# Create ICNS file
echo "🔧 Creating ICNS file..."
iconutil -c icns "$ICONSET_DIR" -o AppIcon.icns

if [ -f "AppIcon.icns" ]; then
    echo "✅ ICNS file created: AppIcon.icns"
    ICNS_SIZE=$(du -h AppIcon.icns | cut -f1)
    echo "   File size: $ICNS_SIZE"
else
    echo "⚠️  ICNS creation failed (you can still use the PNG files)"
fi

echo ""
echo "📋 Next steps:"
echo ""
echo "Option 1: Use Asset Catalog (Recommended)"
echo "   1. Open your project in Xcode"
echo "   2. Select Assets.xcassets"
echo "   3. Find AppIcon"
echo "   4. Drag PNG files from $ICONSET_DIR/ to appropriate slots"
echo ""
echo "Option 2: Use ICNS file"
echo "   1. Add AppIcon.icns to your Xcode project"
echo "   2. Target → General → App Icon → Select AppIcon.icns"
echo ""
echo "🎉 Done!"
