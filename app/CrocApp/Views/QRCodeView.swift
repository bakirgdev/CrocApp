import CoreImage.CIFilterBuiltins
import SwiftUI

/// Crisp QR rendering of what the sender shows on screen. The payload is the
/// receive link from `TransferLink.webURL(forCode:)` (`https://crocapp.dev/r/#<code>`),
/// which opens the app through the universal link or the browser receive page.
/// The scanner side accepts that link and the bare code (`TransferLink.parse`).
/// design/components.md → CodePhraseDisplay and QRFrame.
struct QRCodeView: View {
    let content: String
    var label: LocalizedStringKey = "QR code for the code phrase"
    @State private var image: CGImage?

    // White in both themes: scanners need the contrast whatever the appearance
    // (design/implementation.md → Raw colors on web).
    private let frameFill = Color.white

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: ComponentMetrics.qrFrameDefault,
                        height: ComponentMetrics.qrFrameDefault
                    )
                    .padding(Spacing.space4)
                    .background(
                        frameFill,
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(Color.separatorToken, lineWidth: BorderWidth.hairline)
                    )
                    // components.md → CodePhraseDisplay and QRFrame: --shadow-md. SwiftUI's
                    // .shadow() is single-layer where the token is two CSS
                    // layers; .shadowMd() stacks two .shadow() calls to
                    // reproduce both rather than approximate with one.
                    .shadowMd()
                    .accessibilityLabel(label)
            } else {
                // Must be a real view, not the implicit EmptyView: SwiftUI
                // gives EmptyView no identity in the render tree, so the
                // .task below never fired and the QR never appeared at all.
                placeholder
            }
        }
        .task(id: content) { image = Self.generate(content) }
    }

    /// Same footprint and chrome as the rendered QR, so the frame does not
    /// jump when the image lands.
    private var placeholder: some View {
        Color.clear
            .frame(
                width: ComponentMetrics.qrFrameDefault,
                height: ComponentMetrics.qrFrameDefault
            )
            .padding(Spacing.space4)
            .background(
                frameFill,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(Color.separatorToken, lineWidth: BorderWidth.hairline)
            )
            // Same footprint and chrome as the image branch (see doc comment
            // above) — .shadowMd() has to match too, or the frame would jump.
            .shadowMd()
            .accessibilityHidden(true)
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
