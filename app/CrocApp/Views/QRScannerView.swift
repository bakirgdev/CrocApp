#if os(iOS)
import SwiftUI
import Vision
import VisionKit

/// QR scan sheet (F6). DataScannerViewController.isSupported is false on
/// simulator and unsupported hardware -- show a fallback instead of crashing.
struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported {
                    if startFailed {
                        ContentUnavailableView("Camera unavailable",
                                               systemImage: "video.slash",
                                               description: Text("Check camera permission in Settings."))
                    } else {
                        QRScannerView(onScan: onScan) { startFailed = true }
                    }
                } else {
                    ContentUnavailableView("Camera scanning isn't available on this device",
                                           systemImage: "qrcode.viewfinder")
                }
            }
            .navigationTitle("Scan Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onStartFailure: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if !controller.isScanning {
            do {
                try controller.startScanning()
            } catch {
                DispatchQueue.main.async { onStartFailure() }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScan(payload)
                    return
                }
            }
        }
    }
}
#endif
