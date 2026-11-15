import Foundation
import Observation

/// What the Send screen holds before Send is tapped: the staged files, the
/// typed text and the link and code options. It lives above the tab view
/// (`AppRouter`), so switching tabs or flipping between tab bar and sidebar
/// never loses it, and a drop, a share, a Shortcut or a menu command can fill it
/// while Send is not on screen. Filling it only stages: Send is always the
/// button.
@MainActor
@Observable
final class SendDraft {
    enum Mode: CaseIterable {
        case files
        case text
    }

    /// How long a stored upload stays on the server.
    enum LinkLifetime: Int, CaseIterable {
        case hour = 3_600
        case day = 86_400
        case week = 604_800
    }

    var mode: Mode = .files
    var pickedURLs: [URL] = []
    var text = ""
    var customCode = ""
    var sendAsLink = false
    var linkLifetime = LinkLifetime.day
    var linkDownloads = 1
    /// The request Send started, so a finished transfer empties only the draft it came from.
    @ObservationIgnored var started: TransferRequest?

    /// Empties what `request` sent and puts the options back, once it ended in
    /// done or stored. A failure or a cancel keeps the draft: Try Again reuses it.
    func finish(_ request: TransferRequest?) {
        guard let request, request == started else { return }
        started = nil
        switch request {
        case .sendFiles(let urls, _), .storedSend(let urls, _, _):
            // A file dropped while the transfer ran stays staged for the next one.
            pickedURLs.removeAll { urls.contains($0) }
            for url in urls { SendStaging.discard(url) }
        case .sendText(let sent, _):
            if text == sent { text = "" }
        case .receive, .storedReceive:
            break
        }
        customCode = ""
        sendAsLink = false
        linkLifetime = .day
        linkDownloads = 1
        if text.isEmpty { mode = .files }
    }

    /// Adds the files the draft does not hold yet and shows the Files mode.
    func add(_ urls: [URL]) {
        // The list is keyed by URL, so a repeat inside one batch would collide.
        var new: [URL] = []
        for url in urls where !pickedURLs.contains(url) && !new.contains(url) { new.append(url) }
        guard !new.isEmpty else { return }
        mode = .files
        pickedURLs.append(contentsOf: new)
    }

    /// Appends rather than replaces, so text the user already typed survives.
    func append(text new: String) {
        guard !new.isEmpty else { return }
        mode = .text
        text = text.isEmpty ? new : text + "\n" + new
    }

    /// Takes what was dropped, pasted or picked. Files win over text, because a
    /// copied file often carries its name as text too. Returns whether anything
    /// was added.
    @discardableResult
    func stage(_ payloads: [SendPayload]) -> Bool {
        let intake = SendIntake(payloads)
        let before = pickedURLs.count
        add(intake.files)
        if pickedURLs.count > before { return true }
        guard intake.files.isEmpty, let typed = intake.text(appendedTo: text) else {
            return false
        }
        mode = .text
        text = typed
        return true
    }
}
