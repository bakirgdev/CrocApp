#if os(iOS)
import AVFoundation
import SwiftUI
import Vision
import VisionKit

/// QR scan sheet (F6). Authorization is resolved first (four distinct
/// states -- see below), then DataScannerViewController.isSupported is
/// checked as a separate capability gate: it is false on simulator and
/// unsupported hardware regardless of authorization, so both checks stay.
struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startFailed = false
    @State private var authStatus: AVAuthorizationStatus = CameraPermission.status

    var body: some View {
        NavigationStack {
            Group {
                switch authStatus {
                case .authorized:
                    capabilityGatedScanner
                case .notDetermined:
                    ProgressView()
                        .task {
                            let granted = await CameraPermission.requestIfNeeded()
                            authStatus = granted ? .authorized : CameraPermission.status
                        }
                case .denied:
                    deniedView
                case .restricted:
                    restrictedView
                @unknown default:
                    restrictedView
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

    @ViewBuilder
    private var capabilityGatedScanner: some View {
        if DataScannerViewController.isSupported {
            if startFailed {
                ContentUnavailableView(
                    "Camera unavailable",
                    systemImage: "video.slash",
                    description: Text("Check camera permission in Settings."))
            } else {
                QRScannerView(onScan: onScan) { startFailed = true }
            }
        } else {
            ContentUnavailableView(
                "Camera scanning isn't available on this device",
                systemImage: "qrcode.viewfinder")
        }
    }

    // Settings can fix a denial, so offer the shortcut there -- mirrors the
    // local-network denied banner in TransferStatusView.
    private var deniedView: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "Camera access denied",
                systemImage: "video.slash",
                description: Text("Allow camera access in Settings to scan QR codes.")
            )
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    // Restricted (parental controls / MDM) can't be fixed from Settings, so
    // no Open Settings button here -- different copy, not just missing button.
    private var restrictedView: some View {
        ContentUnavailableView(
            "Camera access restricted",
            systemImage: "video.slash",
            description: Text(
                "Camera access is restricted on this device and can't be changed here.")
        )
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

    // ReceiveView presents this as an interactively-dismissible sheet, so
    // updateUIViewController's startScanning may not be the last word --
    // stop explicitly when SwiftUI tears the controller down.
    static func dismantleUIViewController(
        _ controller: DataScannerViewController, coordinator: Coordinator
    ) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
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
