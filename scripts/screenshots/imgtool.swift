// App Store images: `flatten` redraws a simulator screenshot into a context
// with no alpha channel; `compose` centres window captures, 1x and side by
// side if several, on a flat gradient canvas, which is how the Mac store size
// (16:10) is reached without stretching a 560x700 window. Both write PNGs
// without alpha, because App Store Connect rejects an alpha channel and
// flattening over a colour alone would keep one.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

func load(_ path: String) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(src, 0, nil)
    else { fail("cannot read \(path)") }
    return image
}

func save(_ context: CGContext, _ path: String) {
    guard let image = context.makeImage(),
        let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("cannot write \(path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(path)") }
}

// noneSkipLast is what leaves the PNG with no alpha channel.
func opaqueContext(_ width: Int, _ height: Int, _ space: CGColorSpace) -> CGContext {
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fail("cannot create a \(width)x\(height) bitmap") }
    context.interpolationQuality = .none
    return context
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "flatten" where args.count == 4:  // flatten IN OUT
    let image = load(args[2])
    let context = opaqueContext(
        image.width, image.height, image.colorSpace ?? CGColorSpaceCreateDeviceRGB())
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(rect)
    context.draw(image, in: rect)
    save(context, args[3])
case "compose" where args.count > 5:  // compose OUT WIDTH HEIGHT IMG...
    guard let width = Int(args[3]), let height = Int(args[4]) else { fail("bad canvas size") }
    let images = args[5...].map(load)
    let gap = 120
    let total = images.reduce(0) { $0 + $1.width } + gap * (images.count - 1)
    guard total <= width, images.allSatisfy({ $0.height <= height }) else {
        fail("images do not fit a \(width)x\(height) canvas")
    }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = opaqueContext(width, height, space)
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.89, green: 0.92, blue: 0.97, alpha: 1),
            CGColor(red: 0.74, green: 0.80, blue: 0.91, alpha: 1),
        ] as CFArray,
        locations: [0, 1])!
    context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
    var x = (width - total) / 2
    for image in images {
        let rect = CGRect(
            x: x, y: (height - image.height) / 2, width: image.width, height: image.height)
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -24), blur: 70,
            color: CGColor(gray: 0, alpha: 0.35))
        context.draw(image, in: rect)
        context.restoreGState()
        x += image.width + gap
    }
    save(context, args[2])
default:
    fail("usage: imgtool flatten IN OUT | compose OUT WIDTH HEIGHT IMG...")
}
