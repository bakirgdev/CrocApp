import Foundation
#if os(iOS)
import BackgroundTasks
import UIKit
#endif

// Wraps the active transfer in a BGContinuedProcessingTask so iOS keeps it
// running (briefly, best-effort) after backgrounding; the system shows a
// Live Activity with title/progress/cancel. Also holds the idle-timer lock.
// Every method is a no-op on macOS.
@MainActor
final class BackgroundCoordinator {
#if os(iOS)
    // Wildcard id per transfer (repeated register() of one id is not allowed);
    // static id kept as fallback for early-iOS-26 wildcard matching bugs.
    private static let staticIdentifier = "com.bakirgdev.CrocApp.transfer"
    private static let wildcardPrefix = "com.bakirgdev.CrocApp.transfer."

    private var task: BGContinuedProcessingTask?
    private var staticRegistered = false
    private var title = ""
    private var subtitle = ""
    private var onExpiration: (@MainActor () -> Void)?
#endif

    func transferStarted(title: String, onExpiration: @escaping @MainActor () -> Void) {
#if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        self.title = title
        self.subtitle = "Waiting for connection…"
        self.onExpiration = onExpiration
        let handler: (BGTask) -> Void = { bgTask in
            guard let continued = bgTask as? BGContinuedProcessingTask else {
                bgTask.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in self?.adopt(continued) }
        }
        var identifier = Self.wildcardPrefix + UUID().uuidString
        if !BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main, launchHandler: handler) {
            if !staticRegistered {
                staticRegistered = BGTaskScheduler.shared.register(
                    forTaskWithIdentifier: Self.staticIdentifier, using: .main, launchHandler: handler)
            }
            guard staticRegistered else { return }
            identifier = Self.staticIdentifier
        }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: title, subtitle: subtitle)
        request.strategy = .queue
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Simulator or unsupported device: transfer still runs while foregrounded.
        }
#endif
    }

    func progressChanged(bytesDone: Int64, totalBytes: Int64, fileName: String) {
#if os(iOS)
        guard let task, totalBytes > 0 else { return }
        task.progress.totalUnitCount = totalBytes
        task.progress.completedUnitCount = min(bytesDone, totalBytes)
        if !fileName.isEmpty, fileName != subtitle {
            subtitle = fileName
            task.updateTitle(title, subtitle: fileName)
        }
#endif
    }

    func transferEnded(success: Bool) {
#if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        task?.setTaskCompleted(success: success)
        task = nil
        onExpiration = nil
#endif
    }

#if os(iOS)
    private func adopt(_ continued: BGContinuedProcessingTask) {
        guard onExpiration != nil else {
            // Transfer already finished before the system launched the task.
            continued.setTaskCompleted(success: true)
            return
        }
        task = continued
        continued.progress.totalUnitCount = 1
        continued.progress.completedUnitCount = 0
        continued.expirationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.onExpiration?()
                self.onExpiration = nil
                self.task?.setTaskCompleted(success: false)
                self.task = nil
            }
        }
    }
#endif
}
