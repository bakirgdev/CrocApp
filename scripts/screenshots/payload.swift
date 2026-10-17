// Real-content sample files, so the shots show proper file types instead of
// random bytes. Nothing here is committed or shipped; the script builds them
// into a temp dir on every run.
//   payload pdf OUT   a short quarterly report with a bar chart
//   payload jpg OUT   a flat-colour sunrise over a harbour
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

func draw(
    _ text: String, size: CGFloat, bold: Bool = false, at point: CGPoint, in context: CGContext
) {
    let font = CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
    let attributed = NSAttributedString(
        string: text, attributes: [.init(kCTFontAttributeName as String): font])
    context.textPosition = point
    CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
}

func makePDF(to path: String) {
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(URL(fileURLWithPath: path) as CFURL, mediaBox: &box, nil)
    else { fail("cannot write \(path)") }
    let bars: [(String, CGFloat)] = [("Q1", 0.45), ("Q2", 0.62), ("Q3", 0.58), ("Q4", 0.86)]
    let lines = [
        "Revenue grew in every quarter but one, led by the new team plans.",
        "Support response time fell to under four hours.",
        "Next quarter: ship the iPad layout and the shared history view.",
    ]
    for page in 1...3 {
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 0.1, alpha: 1))
        draw("Quarterly Report", size: 30, bold: true, at: CGPoint(x: 56, y: 700), in: context)
        draw("Page \(page) of 3", size: 11, at: CGPoint(x: 56, y: 676), in: context)
        for (i, line) in lines.enumerated() {
            draw(line, size: 13, at: CGPoint(x: 56, y: 630 - CGFloat(i) * 22), in: context)
        }
        for (i, bar) in bars.enumerated() {
            let x = 72 + CGFloat(i) * 120
            context.setFillColor(CGColor(red: 0.12, green: 0.45, blue: 0.36, alpha: 1))
            context.fill(CGRect(x: x, y: 300, width: 80, height: 260 * bar.1))
            context.setFillColor(CGColor(gray: 0.1, alpha: 1))
            draw(bar.0, size: 12, at: CGPoint(x: x + 30, y: 280), in: context)
        }
        context.endPDFPage()
    }
    context.closePDF()
}

func makeJPEG(to path: String) {
    let width = 2400
    let height = 1600
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fail("cannot create a bitmap") }
    let sky = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.98, green: 0.72, blue: 0.45, alpha: 1),
            CGColor(red: 0.35, green: 0.50, blue: 0.78, alpha: 1),
        ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(
        sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])
    context.setFillColor(CGColor(red: 1, green: 0.93, blue: 0.7, alpha: 1))
    context.fillEllipse(in: CGRect(x: 1500, y: 620, width: 340, height: 340))
    let hills: [(CGFloat, CGFloat, CGColor)] = [
        (520, 90, CGColor(red: 0.24, green: 0.33, blue: 0.5, alpha: 1)),
        (380, 70, CGColor(red: 0.13, green: 0.22, blue: 0.38, alpha: 1)),
        (220, 50, CGColor(red: 0.07, green: 0.12, blue: 0.24, alpha: 1)),
    ]
    for (base, amplitude, color) in hills {
        context.setFillColor(color)
        context.move(to: CGPoint(x: 0, y: 0))
        for x in stride(from: 0, through: width, by: 8) {
            let t = CGFloat(x) / 260 + base / 100
            context.addLine(
                to: CGPoint(x: CGFloat(x), y: base + amplitude * sin(t) + 30 * sin(t * 2.7)))
        }
        context.addLine(to: CGPoint(x: width, y: 0))
        context.fillPath()
    }
    guard let image = context.makeImage(),
        let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { fail("cannot write \(path)") }
    CGImageDestinationAddImage(
        dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(path)") }
}

let args = CommandLine.arguments
switch args.count > 2 ? args[1] : "" {
case "pdf": makePDF(to: args[2])
case "jpg": makeJPEG(to: args[2])
default: fail("usage: payload pdf OUT | payload jpg OUT")
}
