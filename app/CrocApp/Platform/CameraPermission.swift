#if os(iOS)
import AVFoundation

/// Camera authorization for QR scanning. iOS only -- QRScannerView.swift is
/// `#if os(iOS)` in its entirety and macOS has no camera feature in this app.
enum CameraPermission {
    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Requests access unless already `.denied`/`.restricted` -- re-requesting
    /// those is a silent no-op that just spends a launch for nothing. Returns
    /// whether video capture is authorized after the call.
    @discardableResult
    static func requestIfNeeded() async -> Bool {
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        @unknown default:
            return false
        }
    }
}
#endif
