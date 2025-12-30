#!/usr/bin/swift

import AppKit
import Foundation

// Script to generate app icon using native macOS APIs
// Usage: swift scripts/create-icon.swift

func createAppIcon() {
    let sizes: [(size: Int, scale: Int)] = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2)
    ]
    
    // Create output directory
    let outputDir = "AppIcon"
    try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    
    for (size, scale) in sizes {
        let pixelSize = size * scale
        
        // Create bitmap rep directly with correct pixel dimensions
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelSize * 4,
            bitsPerPixel: 32
        ) else {
            print("❌ Failed to create bitmap for \(pixelSize)x\(pixelSize)")
            continue
        }
        
        // Create graphics context and draw
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        
        // Background - nice blue gradient
        let gradient = NSGradient(colors: [
            NSColor(red: 0.16, green: 0.50, blue: 0.73, alpha: 1.0),
            NSColor(red: 0.20, green: 0.60, blue: 0.86, alpha: 1.0)
        ])
        
        let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        let path = NSBezierPath(roundedRect: rect, xRadius: CGFloat(pixelSize) / 8, yRadius: CGFloat(pixelSize) / 8)
        gradient?.draw(in: path, angle: -45)
        
        // Draw shipping box using SF Symbol
        if let symbol = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: CGFloat(pixelSize) * 0.6, weight: .regular)
            let configuredSymbol = symbol.withSymbolConfiguration(symbolConfig)
            
            // Center the symbol
            let symbolRect = NSRect(
                x: CGFloat(pixelSize) * 0.2,
                y: CGFloat(pixelSize) * 0.2,
                width: CGFloat(pixelSize) * 0.6,
                height: CGFloat(pixelSize) * 0.6
            )
            
            // Draw white symbol
            NSColor.white.setFill()
            configuredSymbol?.draw(in: symbolRect)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Save as PNG
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let filename: String
            if scale == 1 {
                filename = "\(outputDir)/icon_\(size)x\(size).png"
            } else {
                filename = "\(outputDir)/icon_\(size)x\(size)@\(scale)x.png"
            }
            
            try? pngData.write(to: URL(fileURLWithPath: filename))
            print("✅ Created: \(filename) (\(pixelSize)×\(pixelSize) pixels)")
        }
    }
    
    // Create Contents.json
    createContentsJSON(in: outputDir)
    
    print("\n🎉 App icon set created in \(outputDir)/")
    print("\nTo use:")
    print("1. In Xcode, select Assets.xcassets")
    print("2. Find AppIcon")
    print("3. Drag the PNG files to the appropriate slots")
}

func createContentsJSON(in directory: String) {
    let json = """
    {
      "images" : [
        {
          "filename" : "icon_16x16.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "16x16"
        },
        {
          "filename" : "icon_16x16@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "16x16"
        },
        {
          "filename" : "icon_32x32.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "32x32"
        },
        {
          "filename" : "icon_32x32@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "32x32"
        },
        {
          "filename" : "icon_128x128.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "128x128"
        },
        {
          "filename" : "icon_128x128@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "128x128"
        },
        {
          "filename" : "icon_256x256.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "256x256"
        },
        {
          "filename" : "icon_256x256@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "256x256"
        },
        {
          "filename" : "icon_512x512.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "512x512"
        },
        {
          "filename" : "icon_512x512@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "512x512"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    
    try? json.write(toFile: "\(directory)/Contents.json", atomically: true, encoding: .utf8)
}

// Run the generator
createAppIcon()
