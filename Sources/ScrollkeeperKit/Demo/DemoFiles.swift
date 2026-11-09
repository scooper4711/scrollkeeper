import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// What the demo server hands out: the PDFs in `Demo/Files`, written by tabletop-kit's demo library
/// (`make demo-pdfs`), and a cover drawn for each title.
enum DemoFiles {
    /// Where demo downloads come from, and covers.
    static let filesHost = "files.demo.invalid"
    static let coversHost = "covers.demo.invalid"

    /// The address a demo edition's file downloads from.
    static func address(of file: String) -> String {
        "https://\(filesHost)/\(file)"
    }

    /// The bundled PDF named `name`, or nil for a file the folder doesn't have (the ePubs).
    static func bundled(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Files")
    }

    /// A one-page PDF, for a demo file the folder doesn't have.
    static let placeholderPDF = Data("""
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Contents 4 0 R
        /Resources << /Font << /F1 5 0 R >> >> >> endobj
        4 0 obj << /Length 58 >> stream
        BT /F1 18 Tf 40 100 Td (Scrollkeeper demo file) Tj ET
        endstream endobj
        5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
        trailer << /Root 1 0 R >>
        %%EOF
        """.utf8)

    /// A cover for the title with `sku`: its name in white on a band of color picked from the SKU, as a JPEG.
    static func cover(sku: String) -> Data? {
        guard let title = DemoCatalog.titles.first(where: { $0.sku == sku }),
              let context = CGContext(data: nil, width: 300, height: 450, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        let hue = CGFloat(sku.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % 360) / 360
        context.setFillColor(color(hue: hue, brightness: 0.35))
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 450))
        context.setFillColor(color(hue: hue, brightness: 0.65))
        context.fill(CGRect(x: 0, y: 260, width: 300, height: 120))
        draw(title.name, size: 24, in: CGRect(x: 20, y: 265, width: 260, height: 110), context: context)
        draw("DEMO", size: 14, in: CGRect(x: 20, y: 20, width: 260, height: 24), context: context)
        return context.makeImage().flatMap(jpeg)
    }

    private static func color(hue: CGFloat, brightness: CGFloat) -> CGColor {
        // A simple hue wheel, enough to tell covers apart.
        let red = 0.5 + 0.5 * cos(2 * .pi * hue), green = 0.5 + 0.5 * cos(2 * .pi * (hue - 1.0 / 3))
        let blue = 0.5 + 0.5 * cos(2 * .pi * (hue - 2.0 / 3))
        return CGColor(red: red * brightness, green: green * brightness, blue: blue * brightness, alpha: 1)
    }

    private static func draw(_ text: String, size: CGFloat, in frame: CGRect, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .init(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil),
            .init(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
        ]
        let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text,
                                                                                     attributes: attributes))
        CTFrameDraw(CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: frame, transform: nil), nil), context)
    }

    private static func jpeg(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
