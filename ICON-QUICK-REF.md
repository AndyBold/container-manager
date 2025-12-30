# App Icon Quick Reference

## 🚀 Fastest Method

### Option A: Generate from SF Symbol
```bash
swift scripts/create-icon.swift
```
This creates a blue icon with a shipping box symbol.

### Option B: Use Your Own 1024x1024 PNG
```bash
chmod +x scripts/iconset-from-png.sh
./scripts/iconset-from-png.sh path/to/your-icon-1024.png
```

Then drag the generated icons to Xcode's Assets.xcassets → AppIcon.

## 🎨 Free Online Tools

1. **icon.kitchen** - Upload 1024px PNG, get icon set
2. **appiconizer.com** - Generate all sizes automatically
3. **cloudconvert.com** - Convert PNG to ICNS

## 📐 Design Specs

- **Size:** 1024x1024 pixels minimum
- **Format:** PNG with transparency
- **Colors:** 2-3 colors work best
- **Style:** Simple, recognizable at small sizes

## ✅ Adding to Xcode

1. Assets.xcassets → AppIcon
2. Drag PNG files to size slots
3. Build (⌘B)
4. Done!

## 🐛 Icon Not Showing?

```bash
# Clean and rebuild
⌘⇧K in Xcode

# Clear icon cache
sudo rm -rf /Library/Caches/com.apple.iconservices.store
killall Finder
```

## 📚 Full Documentation

See: [CREATING-APP-ICON.md](CREATING-APP-ICON.md)
