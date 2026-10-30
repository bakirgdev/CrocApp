#if os(iOS)
import AVFoundation
import SwiftUI
import Vision
import VisionKit

/// QR scan sheet. Authorization is resolved first (four distinct
/// states -- see below), then DataScannerViewController.isSupported is
/// checked as a separate capability gate: it is false on simulator and
/// unsupported hardware regardless of authorization, so both checks stay.
struct QRScannerSheet: View {
    /// Called once, with the first QR code that is a code phrase or a link.
    /// Anything else keeps the camera running (components.md → ScannerSheet).
    let onScan: (TransferLink) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startFailed = false
    /// A QR code is in view that CrocApp cannot receive.
    @State private var showsRejection = false
    @State private var hasScanned = false
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
                    description: Text("The camera couldn't start. Close this and try again."))
            } else {
                QRScannerView(onScan: scanned, onLost: { showsRejection = false }) {
                    startFailed = true
                }
                .overlay(alignment: .bottom) { guidance }
            }
        } else {
            ContentUnavailableView(
                "Camera scanning isn't available on this device",
                systemImage: "video.slash",
                description: Text("Enter the code phrase instead."))
        }
    }

    private func scanned(_ payload: String) {
        guard !hasScanned else { return }
        guard let link = TransferLink.parse(payload) else {
            showsRejection = true
            return
        }
        hasScanned = true
        onScan(link)
    }

    /// What to do, or why the QR code in view does not work. The two share a
    /// slot, so nothing moves when one replaces the other.
    private var guidance: some View {
        Group {
            if showsRejection {
                StatusBanner(
                    kind: .error,
                    title: String(
                        localized: "That isn't a CrocApp QR code",
                        comment: "Title when a scanned QR code is neither a code phrase nor a link."
                    ),
                    detail: String(
                        localized: "Scan the QR code on the sending device.",
                        comment: "Says what to do after a scanned QR code was not a CrocApp one.")
                )
                .transition(rejectionTransition)
            } else {
                Text("Point the camera at the QR code on the other device.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.space5)
                    .padding(.vertical, Spacing.space4)
                    .glassEffect(
                        .regular, in: .rect(cornerRadius: Radius.md, style: .continuous))
            }
        }
        .padding(Spacing.space5)
        .animation(
            reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: showsRejection)
    }

    /// implementation.md → Materials, motion and haptics, "Insert".
    private var rejectionTransition: AnyTransition {
        reduceMotion
            ? .identity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: -Spacing.space3))
                    .animation(Motion.easeOut(Motion.durationBase)),
                removal: .opacity.animation(Motion.easeStandard(Motion.durationFast)))
    }

    // Settings can fix a denial, so offer the shortcut there -- mirrors the
    // local-network denied banner in TransferStatusView.
    private var deniedView: some View {
        VStack(spacing: Spacing.space4) {
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
            .buttonVariant(.secondary)
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
    /// Nothing is in view any more.
    let onLost: () -> Void
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

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, onLost: onLost) }

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
        let onLost: () -> Void
        init(onScan: @escaping (String) -> Void, onLost: @escaping () -> Void) {
            self.onScan = onScan
            self.onLost = onLost
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScan(payload)
                }
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            if allItems.isEmpty { onLost() }
        }
    }
}
#endif
