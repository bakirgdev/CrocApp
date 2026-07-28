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
                    .accessibilityLabel("QR code for the transfer code")
            }
        }
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

#Preview { QRCodeView(content: "croc://1234-example-code-phrase") }
