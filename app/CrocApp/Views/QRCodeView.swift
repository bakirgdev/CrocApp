import CoreImage.CIFilterBuiltins
import SwiftUI

/// Crisp QR rendering of a transfer code (F6). Content is the deeplink form
/// "croc://<code>" so future F32 deeplinks and other croc GUIs can read it;
/// the scanner side accepts both the bare code and the prefixed form.
struct QRCodeView: View {
    let content: String
    @State private var image: CGImage?

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
                    // design/components.md → CodePhraseDisplay + QRFrame:
                    // white background in BOTH themes — scanners need
                    // contrast regardless of appearance. Deliberate hardcode,
                    // not a token violation.
                    .background(
                        Color.white,
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(Color.separatorToken, lineWidth: BorderWidth.hairline)
                    )
                    // components.md → QRFrame: --shadow-md. SwiftUI's
                    // .shadow() is single-layer where the token is two CSS
                    // layers; .shadowMd() stacks two .shadow() calls to
                    // reproduce both rather than approximate with one.
                    .shadowMd()
                    .accessibilityLabel("QR code for the transfer code")
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
                Color.white,
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

#Preview { QRCodeView(content: "croc://1234-example-code-phrase") }
