#!/bin/bash

# Script to generate app icon from SF Symbol
# Usage: ./scripts/generate-icon.sh

set -e

echo "🎨 Generating Container Manager App Icon..."

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not found"
    exit 1
fi

# Create Python script to generate icon
python3 << 'EOF'
from PIL import Image, ImageDraw, ImageFont
import os

def create_app_icon():
    """
    Creates a simple app icon with a shipping box theme
    """
    # Icon sizes needed for macOS app
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    # Create Assets directory
    assets_dir = "Assets.xcassets/AppIcon.appiconset"
    os.makedirs(assets_dir, exist_ok=True)
    
    # Color scheme - container/shipping theme
    bg_color = (41, 128, 185)  # Nice blue
    box_color = (236, 240, 241)  # Light gray/white
    accent_color = (231, 76, 60)  # Red accent
    
    for size in sizes:
        # Create image with transparency
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.draw(img)
        
        # Draw rounded rectangle background
        padding = size // 10
        draw.rounded_rectangle(
            [(padding, padding), (size - padding, size - padding)],
            radius=size // 8,
            fill=bg_color
        )
        
        # Draw simple box shape
        box_size = size // 2
        box_x = (size - box_size) // 2
        box_y = (size - box_size) // 2
        
        # Box body
        draw.rectangle(
            [(box_x, box_y + box_size // 4), 
             (box_x + box_size, box_y + box_size)],
            fill=box_color
        )
        
        # Box lid
        lid_height = box_size // 4
        draw.polygon(
            [(box_x, box_y + lid_height),
             (box_x + box_size // 2, box_y),
             (box_x + box_size, box_y + lid_height)],
            fill=box_color
        )
        
        # Tape on box
        tape_width = box_size // 10
        draw.rectangle(
            [(box_x + box_size // 2 - tape_width // 2, box_y + lid_height),
             (box_x + box_size // 2 + tape_width // 2, box_y + box_size)],
            fill=accent_color
        )
        
        # Save at different resolutions
        img.save(f"{assets_dir}/icon_{size}x{size}.png")
        if size <= 512:
            img_2x = img.resize((size * 2, size * 2), Image.LANCZOS)
            img_2x.save(f"{assets_dir}/icon_{size}x{size}@2x.png")
    
    print(f"✅ Icons generated in {assets_dir}/")
    print("📦 Icon sizes: " + ", ".join([f"{s}x{s}" for s in sizes]))

if __name__ == "__main__":
    try:
        create_app_icon()
    except ImportError:
        print("❌ PIL (Pillow) not found. Install with: pip3 install Pillow")
        exit(1)

EOF

echo "✅ Icon generation complete!"
echo ""
echo "Next steps:"
echo "1. Open your project in Xcode"
echo "2. Add the generated icons to your asset catalog"
echo "3. Or use the online tools below for more professional icons"
