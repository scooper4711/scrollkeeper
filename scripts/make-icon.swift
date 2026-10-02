// Draws the app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
//
// The artwork is original: a shelf of books and a twenty-sided die. It uses no Paizo logos,
// lettering or artwork.
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

func fillGradient(_ context: CGContext, in path: CGPath, from top: UInt32, to bottom: UInt32) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let colors = [color(top), color(bottom)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
    let bounds = path.boundingBox
    if let gradient {
        context.drawLinearGradient(
            gradient, start: CGPoint(x: bounds.midX, y: bounds.maxY), end: CGPoint(x: bounds.midX, y: bounds.minY),
            options: []
        )
    }
    context.restoreGState()
}

/// A book standing on the shelf: a spine with two gilt bands.
func drawBook(_ context: CGContext, frame: CGRect, top: UInt32, bottom: UInt32, tilt: CGFloat = 0) {
    context.saveGState()
    context.translateBy(x: frame.minX, y: frame.minY)
    context.rotate(by: tilt * .pi / 180)
    let spine = CGRect(origin: .zero, size: frame.size)
    context.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0x000000, alpha: 0.35))
    let path = CGPath(roundedRect: spine, cornerWidth: 14, cornerHeight: 14, transform: nil)
    context.addPath(path)
    context.setFillColor(color(bottom))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    fillGradient(context, in: path, from: top, to: bottom)
    context.setFillColor(color(0xF2D27A, alpha: 0.9))
    for offset in [frame.height * 0.16, frame.height * 0.78] {
        context.fill(CGRect(x: 0, y: offset, width: frame.width, height: 14))
    }
    context.restoreGState()
}

/// A twenty-sided die seen face on: a hexagon with a central triangle.
func drawDie(_ context: CGContext, center: CGPoint, radius: CGFloat) {
    let corners = (0..<6).map { index -> CGPoint in
        let angle = CGFloat(index) * .pi / 3 + .pi / 2
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
    let face = (0..<3).map { index -> CGPoint in
        let angle = CGFloat(index) * 2 * .pi / 3 + .pi / 2
        return CGPoint(x: center.x + radius * 0.56 * cos(angle), y: center.y + radius * 0.56 * sin(angle))
    }
    let outline = CGMutablePath()
    outline.addLines(between: corners)
    outline.closeSubpath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: color(0x000000, alpha: 0.45))
    context.addPath(outline)
    context.setFillColor(color(0xFFFFFF))
    context.fillPath()
    context.restoreGState()
    fillGradient(context, in: outline, from: 0xFFFFFF, to: 0xC9D1F5)

    let triangle = CGMutablePath()
    triangle.addLines(between: face)
    triangle.closeSubpath()
    fillGradient(context, in: triangle, from: 0xFFFFFF, to: 0xE7EBFF)

    context.setStrokeColor(color(0x2A2F6B))
    context.setLineWidth(11)
    context.setLineJoin(.round)
    context.addPath(outline)
    context.addPath(triangle)
    // Each corner of the face joins the three nearest corners of the outline.
    let joins = [(0, [5, 0, 1]), (1, [1, 2, 3]), (2, [3, 4, 5])]
    for (vertex, targets) in joins {
        for target in targets {
            context.move(to: face[vertex])
            context.addLine(to: corners[target])
        }
    }
    context.strokePath()

    let text = NSAttributedString(string: "20", attributes: [
        .font: NSFont.systemFont(ofSize: radius * 0.46, weight: .heavy),
        .foregroundColor: NSColor(cgColor: color(0x2A2F6B)) ?? .black
    ])
    let size = text.size()
    text.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2 - radius * 0.05))
}

func drawIcon() -> NSBitmapImageRep? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext

    // The standard macOS icon shape: 824 points square on a 1024 canvas.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, alpha: 0.35))
    context.addPath(platePath)
    context.setFillColor(color(0x1B1E4B))
    context.fillPath()
    context.restoreGState()
    fillGradient(context, in: platePath, from: 0x3B3F96, to: 0x14163A)

    context.saveGState()
    context.addPath(platePath)
    context.clip()
    let shelfTop: CGFloat = 318
    drawBook(context, frame: CGRect(x: 214, y: shelfTop, width: 104, height: 404), top: 0xD9534F, bottom: 0x9E2B2B)
    drawBook(context, frame: CGRect(x: 328, y: shelfTop, width: 84, height: 350), top: 0xF0B84A, bottom: 0xC27F1E)
    drawBook(context, frame: CGRect(x: 422, y: shelfTop, width: 116, height: 440), top: 0x3FB8A6, bottom: 0x1F7A6E)
    drawBook(context, frame: CGRect(x: 548, y: shelfTop, width: 92, height: 376), top: 0x8E7BE0, bottom: 0x5B46B0)
    drawBook(context, frame: CGRect(x: 664, y: shelfTop, width: 88, height: 392), top: 0xF4EEDC, bottom: 0xCFC5A8, tilt: -13)
    let shelf = CGPath(
        roundedRect: CGRect(x: 170, y: shelfTop - 34, width: 684, height: 34), cornerWidth: 10, cornerHeight: 10,
        transform: nil
    )
    fillGradient(context, in: shelf, from: 0xB98A4E, to: 0x7C5526)
    context.restoreGState()

    drawDie(context, center: CGPoint(x: 690, y: 330), radius: 168)
    graphics.flushGraphics()
    return bitmap
}

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let iconset = root.appending(path: "build/AppIcon.iconset", directoryHint: .isDirectory)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

guard let master = drawIcon(), let png = master.representation(using: .png, properties: [:]) else {
    fatalError("Drawing the icon failed: no bitmap context.")
}
let masterURL = iconset.appending(path: "icon_512x512@2x.png")
try png.write(to: masterURL)

func run(_ tool: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(filePath: tool)
    process.arguments = arguments
    process.standardOutput = Pipe()
    try process.run()
    process.waitUntilExit()
}

for (name, pixels) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128),
    ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512)
] {
    let output = iconset.appending(path: name + ".png").path
    try run("/usr/bin/sips", ["-z", String(pixels), String(pixels), masterURL.path, "--out", output])
}
try FileManager.default.createDirectory(at: root.appending(path: "Resources"), withIntermediateDirectories: true)
try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", root.appending(path: "Resources/AppIcon.icns").path])
print("Wrote Resources/AppIcon.icns")
