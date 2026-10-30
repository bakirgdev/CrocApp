// Writes the favicon set from a 1024px render of the app icon (design/brand.md,
// "Favicon recipe"):
//
//   swift scripts/favicons.swift icon.png assets/favicons
//
// The ICO and the 96px PNG keep the squircle with transparent corners. The
// touch and manifest icons are opaque, because iOS and Android fill
// transparent corners with black: the render is scaled to 1198/1024 over the
// icon's light background gradient, so the corners take the icon's colors.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let args = CommandLine.arguments
let render = NSImage(contentsOfFile: args[1])!, out = args[2]
func draw(_ size: Int, opaque: Bool) -> CGImage {
  let cs = CGColorSpace(name: CGColorSpace.sRGB)!
  let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.interpolationQuality = .high
  let s = CGFloat(size)
  var rect = CGRect(x: 0, y: 0, width: s, height: s)
  if opaque {
    // The light rendition's background gradient, assets/CrocAppIcon.icon/icon.json.
    let g = CGGradient(colorsSpace: cs, colors: [NSColor(srgbRed: 0xE4/255, green: 0xE3/255, blue: 0xA9/255, alpha: 1).cgColor, NSColor(srgbRed: 0xF7/255, green: 0xF6/255, blue: 0xE4/255, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s), options: [])
    let big = s * 1198 / 1024
    rect = CGRect(x: (s - big) / 2, y: (s - big) / 2, width: big, height: big)
  }
  var r = CGRect(origin: .zero, size: render.size)
  ctx.draw(render.cgImage(forProposedRect: &r, context: nil, hints: nil)!, in: rect)
  return ctx.makeImage()!
}
func write(_ imgs: [CGImage], _ name: String, _ type: UTType) {
  let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out + "/" + name) as CFURL, type.identifier as CFString, imgs.count, nil)!
  for i in imgs { CGImageDestinationAddImage(d, i, nil) }
  precondition(CGImageDestinationFinalize(d), "write failed: \(name)")
}
write([draw(96, opaque: false)], "favicon-96x96.png", .png)
write([draw(180, opaque: true)], "apple-touch-icon.png", .png)
write([draw(192, opaque: true)], "web-app-manifest-192x192.png", .png)
write([draw(512, opaque: true)], "web-app-manifest-512x512.png", .png)
write([draw(16, opaque: false), draw(32, opaque: false), draw(48, opaque: false)], "favicon.ico", UTType(filenameExtension: "ico")!)
