#!/usr/bin/swift

import AppKit

// --- Configuration ---
let iconSize: CGFloat = 1024
let cornerRadiusFraction: CGFloat = 0.22
let backgroundColor = NSColor(red: 30.0/255, green: 30.0/255, blue: 60.0/255, alpha: 1.0)
let moonColor = NSColor(red: 255.0/255, green: 220.0/255, blue: 150.0/255, alpha: 1.0)

let outputPath = "/Volumes/Data/Code/nightcoder/AppIcon.icns"
let iconsetPath = "/Volumes/Data/Code/nightcoder/AppIcon.iconset"

// --- Drawing ---

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current else {
        fatalError("Failed to get graphics context")
    }
    context.imageInterpolation = .high
    context.shouldAntialias = true

    // Background rounded rect
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * cornerRadiusFraction
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    backgroundColor.setFill()
    bgPath.fill()

    // Crescent moon via clipping: draw circle, clip out the bite
    let moonRadius = size * 0.30
    let centerX = size / 2
    let centerY = size / 2

    // The bite circle: shifted upper-right to carve the crescent
    let biteRadius = moonRadius * 0.82
    let offsetX = moonRadius * 0.55
    let offsetY = moonRadius * 0.30
    let biteRect = NSRect(
        x: centerX - biteRadius + offsetX,
        y: centerY - biteRadius + offsetY,
        width: biteRadius * 2,
        height: biteRadius * 2
    )

    context.saveGraphicsState()

    // Clip to background shape
    bgPath.addClip()

    // Create a clip that excludes the bite circle:
    // Fill the entire rect, then subtract the bite using even-odd
    let clipPath = NSBezierPath(rect: rect)
    clipPath.windingRule = .evenOdd
    clipPath.append(NSBezierPath(ovalIn: biteRect))
    clipPath.addClip()

    // Now draw the full moon circle — the clip removes the bite
    let moonRect = NSRect(
        x: centerX - moonRadius,
        y: centerY - moonRadius,
        width: moonRadius * 2,
        height: moonRadius * 2
    )
    moonColor.setFill()
    NSBezierPath(ovalIn: moonRect).fill()

    context.restoreGraphicsState()

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return bitmap.representation(using: .png, properties: [:])
}

// --- Generate iconset ---

let fileManager = FileManager.default

// Create iconset directory
try? fileManager.removeItem(atPath: iconsetPath)
try fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Required icon sizes: (filename point size, actual pixel size)
let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16",        16),
    ("icon_16x16@2x",     32),
    ("icon_32x32",        32),
    ("icon_32x32@2x",     64),
    ("icon_128x128",      128),
    ("icon_128x128@2x",   256),
    ("icon_256x256",      256),
    ("icon_256x256@2x",   512),
    ("icon_512x512",      512),
    ("icon_512x512@2x",   1024),
]

print("Generating icon variants...")

for entry in iconSizes {
    let image = drawIcon(size: CGFloat(entry.pixels))
    guard let data = pngData(from: image) else {
        fatalError("Failed to create PNG data for \(entry.name)")
    }
    let filePath = "\(iconsetPath)/\(entry.name).png"
    try data.write(to: URL(fileURLWithPath: filePath))
    print("  \(entry.name).png (\(entry.pixels)x\(entry.pixels))")
}

// --- Convert to .icns using iconutil ---

print("Converting to .icns...")

// Remove existing .icns if present
try? fileManager.removeItem(atPath: outputPath)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]

let pipe = Pipe()
process.standardError = pipe

try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
    fatalError("iconutil failed: \(errorString)")
}

// --- Cleanup ---
try fileManager.removeItem(atPath: iconsetPath)

print("Done! Icon saved to \(outputPath)")
