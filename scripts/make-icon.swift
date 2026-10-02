// Draws the app icon and writes Resources/AppIcon.icns for the Mac and the full-bleed
// ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png for the iPad.
// Usage: swift scripts/make-icon.swift
//
// The artwork is original: scrolls and a twenty-sided die. It uses no Paizo logos,
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

/// A rolled-up end of a scroll: a parchment cylinder on a wooden rod with a knob at each side.
func drawRoll(_ context: CGContext, frame: CGRect) {
    let knob = CGSize(width: frame.height * 0.42, height: frame.height * 0.5)
    for x in [frame.minX - knob.width + 6, frame.maxX - 6] {
        let rect = CGRect(x: x, y: frame.midY - knob.height / 2, width: knob.width, height: knob.height)
        fillGradient(
            context, in: CGPath(roundedRect: rect, cornerWidth: 9, cornerHeight: 9, transform: nil),
            from: 0xB07A3E, to: 0x6E4420
        )
    }
    let roll = CGPath(
        roundedRect: frame, cornerWidth: frame.height / 2, cornerHeight: frame.height / 2, transform: nil
    )
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x000000, alpha: 0.3))
    context.addPath(roll)
    context.setFillColor(color(0xD9C28A))
    context.fillPath()
    context.restoreGState()
    fillGradient(context, in: roll, from: 0xFBF1D3, to: 0xCDB278)
}

/// An open scroll: a sheet of parchment with lines of writing between two rolled ends.
func drawOpenScroll(_ context: CGContext, frame: CGRect) {
    let rollHeight: CGFloat = 74
    let sheet = frame.insetBy(dx: 26, dy: rollHeight / 2)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: color(0x000000, alpha: 0.35))
    context.setFillColor(color(0xEFE0B6))
    context.fill(sheet)
    context.restoreGState()
    fillGradient(context, in: CGPath(rect: sheet, transform: nil), from: 0xFAF0D2, to: 0xE6D3A3)

    context.setFillColor(color(0x8A7346, alpha: 0.75))
    let widths: [CGFloat] = [0.78, 0.92, 0.84, 0.9, 0.6]
    for (index, width) in widths.enumerated() {
        let line = CGRect(
            x: sheet.minX + 44, y: sheet.maxY - 92 - CGFloat(index) * 58,
            width: (sheet.width - 88) * width, height: 16
        )
        context.addPath(CGPath(roundedRect: line, cornerWidth: 8, cornerHeight: 8, transform: nil))
        context.fillPath()
    }
    drawRoll(context, frame: CGRect(x: frame.minX, y: frame.maxY - rollHeight, width: frame.width, height: rollHeight))
    drawRoll(context, frame: CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: rollHeight))
}

/// A closed scroll tied with a ribbon, lying at an angle.
func drawClosedScroll(_ context: CGContext, center: CGPoint, length: CGFloat, tilt: CGFloat, ribbon: UInt32) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: tilt * .pi / 180)
    let frame = CGRect(x: -length / 2, y: -40, width: length, height: 80)
    drawRoll(context, frame: frame)
    let band = CGRect(x: -22, y: -40, width: 44, height: 80)
    fillGradient(context, in: CGPath(rect: band, transform: nil), from: ribbon, to: ribbon)
    context.setFillColor(color(0x000000, alpha: 0.18))
    context.fill(CGRect(x: -22, y: -40, width: 44, height: 22))
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

/// The Mac icon is a rounded plate with a margin; iPadOS wants a full square and rounds it itself.
func drawIcon(fullBleed: Bool) -> NSBitmapImageRep? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext

    // The standard macOS icon shape: 824 points square on a 1024 canvas.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)
    if fullBleed {
        let square = CGPath(rect: CGRect(x: 0, y: 0, width: canvas, height: canvas), transform: nil)
        fillGradient(context, in: square, from: 0x3B3F96, to: 0x14163A)
        // Enlarge the artwork about the center so that it fills the square as it fills the plate.
        context.translateBy(x: canvas / 2, y: canvas / 2)
        context.scaleBy(x: canvas / plate.width, y: canvas / plate.height)
        context.translateBy(x: -canvas / 2, y: -canvas / 2)
    } else {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, alpha: 0.35))
        context.addPath(platePath)
        context.setFillColor(color(0x1B1E4B))
        context.fillPath()
        context.restoreGState()
        fillGradient(context, in: platePath, from: 0x3B3F96, to: 0x14163A)
    }

    context.saveGState()
    context.addPath(platePath)
    context.clip()
    drawClosedScroll(context, center: CGPoint(x: 330, y: 300), length: 300, tilt: 12, ribbon: 0xC2413B)
    drawClosedScroll(context, center: CGPoint(x: 356, y: 222), length: 330, tilt: -6, ribbon: 0x2F9E8F)
    drawOpenScroll(context, frame: CGRect(x: 250, y: 330, width: 420, height: 470))
    context.restoreGState()

    drawDie(context, center: CGPoint(x: 690, y: 330), radius: 168)
    graphics.flushGraphics()
    return bitmap
}

/// PNG data without an alpha channel, which is what an iPadOS icon must be.
func opaquePNG(_ bitmap: NSBitmapImageRep) -> Data? {
    guard let image = bitmap.cgImage, let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return context.makeImage().flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
}

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let iconset = root.appending(path: "build/AppIcon.iconset", directoryHint: .isDirectory)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

guard let master = drawIcon(fullBleed: false), let png = master.representation(using: .png, properties: [:]),
      let square = drawIcon(fullBleed: true), let squarePNG = opaquePNG(square)
else {
    fatalError("Drawing the icon failed: no bitmap context.")
}
try squarePNG.write(to: root.appending(path: "ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png"))
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
print("Wrote Resources/AppIcon.icns and the iPad icon")
