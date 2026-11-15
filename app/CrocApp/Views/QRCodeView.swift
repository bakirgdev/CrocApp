import CoreImage.CIFilterBuiltins
import SwiftUI

/// Crisp QR rendering of what the sender shows on screen. The payload is the
/// receive link from `TransferLink.webURL(forCode:)` (`https://crocapp.dev/r/#<code>`),
/// which opens the app through the universal link or the browser receive page.
/// The scanner side accepts that link and the bare code (`TransferLink.parse`).
struct QRCodeView: View {
    let content: String
    var label: LocalizedStringKey = "QR code for the code phrase"
    @State private var image: CGImage?

    private static let size: CGFloat = 168

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(label)
            } else {
                // Must be a real view, not the implicit EmptyView: SwiftUI
                // gives EmptyView no identity in the render tree, so the
                // .task below never fired and the QR never appeared at all.
                // Same footprint as the rendered QR, so the frame does not
                // jump when the image lands.
                Color.clear.accessibilityHidden(true)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .padding(12)
        // White in both themes: scanners need the contrast whatever the appearance.
        .background(.white, in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.separator) }
        .task(id: content) { image = Self.generate(content) }
    }

    private static let ciContext = CIContext()

    private static func generate(_ string: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        return ciContext.createCGImage(scaled, from: scaled.extent)
    }
}

#Preview { QRCodeView(content: "https://crocapp.dev/r/#1234-example-code-phrase") }
