// Draws the social cards from the mascot (design/brand.md, "Assets"):
//
//   swift scripts/social-cards.swift assets/mascot.png web/landing/assets/img/og.jpg assets/github-social-preview.png
//
// og.jpg is 1200x630 in light values and serves the landing page and the docs
// site. The GitHub social preview is 1280x640 in dark values with the repo
// address. Colors are the olive tokens of design/tokens.css and the icon's
// khaki and deep-olive backgrounds (assets/CrocAppIcon.icon/icon.json); change
// them there first. The system font stands in for SF Pro, which is the web's
// --font-sans on Apple devices.
import AppKit
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

struct Palette {
  let top: Int, bottom: Int, ink: Int, secondary: Int, accent: Int
}
// secondary and accent clear 4.5:1 on their background in both cards.
let light = Palette(top: 0xE4E3A9, bottom: 0xF7F6E4, ink: 0x28350D, secondary: 0x4B5A22, accent: 0x5C6B2E)
let dark = Palette(top: 0x28350D, bottom: 0x1B2409, ink: 0xF7F6E4, secondary: 0xD3DDB4, accent: 0xA3B86A)

func render(_ w: Int, _ h: Int, _ p: Palette, url: String, mascot: NSImage) -> CGImage {
  let cs = CGColorSpace(name: CGColorSpace.sRGB)!
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  ctx.translateBy(x: 0, y: CGFloat(h))
  ctx.scaleBy(x: 1, y: -1)
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
  let s = CGFloat(w) / 1200, H = CGFloat(h)
  let g = CGGradient(colorsSpace: cs, colors: [color(p.top).cgColor, color(p.bottom).cgColor] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: H), options: [])

  func text(_ str: String, size: CGFloat, weight: NSFont.Weight, _ hex: Int, x: CGFloat, y: CGFloat, kern: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: size * s, weight: weight), .foregroundColor: color(hex), .kern: kern * s,
    ]
    NSAttributedString(string: str, attributes: attrs).draw(at: CGPoint(x: x * s, y: y * s))
  }

  // Lucide "lock" (ISC), the accent glyph of the web, drawn at 40px.
  ctx.saveGState()
  ctx.translateBy(x: 72 * s, y: (H - 630 * s) / 2 + 70 * s)
  ctx.scaleBy(x: 40 * s / 24, y: 40 * s / 24)
  ctx.setStrokeColor(color(p.accent).cgColor)
  ctx.setLineWidth(2)
  ctx.setLineCap(.round)
  ctx.setLineJoin(.round)
  ctx.addPath(CGPath(roundedRect: CGRect(x: 3, y: 11, width: 18, height: 11), cornerWidth: 2, cornerHeight: 2, transform: nil))
  let shackle = CGMutablePath()
  shackle.move(to: CGPoint(x: 7, y: 11))
  shackle.addLine(to: CGPoint(x: 7, y: 7))
  shackle.addArc(center: CGPoint(x: 12, y: 7), radius: 5, startAngle: .pi, endAngle: 0, clockwise: false)
  shackle.addLine(to: CGPoint(x: 17, y: 11))
  ctx.addPath(shackle)
  ctx.strokePath()
  ctx.restoreGState()

  let top = (H - 630 * s) / 2 / s
  text("CrocApp", size: 32, weight: .bold, p.ink, x: 124, y: top + 70)
  text("Send files with", size: 96, weight: .bold, p.ink, x: 72, y: top + 196, kern: -2.5)
  text("a code phrase", size: 96, weight: .bold, p.ink, x: 72, y: top + 296, kern: -2.5)
  text("Encrypted end-to-end", size: 36, weight: .regular, p.secondary, x: 74, y: top + 420)
  text(url, size: 30, weight: .semibold, p.accent, x: 72, y: top + 532)

  let m = 470 * s
  mascot.draw(in: CGRect(x: CGFloat(w) - m - 28 * s, y: (H - m) / 2 + 16 * s, width: m, height: m), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
  return ctx.makeImage()!
}

func write(_ img: CGImage, _ path: String, _ type: UTType, quality: Double? = nil) {
  let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, type.identifier as CFString, 1, nil)!
  var opts: [CFString: Any] = [:]
  if let quality { opts[kCGImageDestinationLossyCompressionQuality] = quality }
  CGImageDestinationAddImage(d, img, opts as CFDictionary)
  precondition(CGImageDestinationFinalize(d), "write failed: \(path)")
}

let args = CommandLine.arguments
precondition(args.count == 4, "usage: social-cards.swift mascot.png og.jpg github-social-preview.png")
let mascot = NSImage(contentsOfFile: args[1])!
write(render(1200, 630, light, url: "crocapp.dev", mascot: mascot), args[2], .jpeg, quality: 0.86)
write(render(1280, 640, dark, url: "github.com/bakirgdev/CrocApp", mascot: mascot), args[3], .png)
