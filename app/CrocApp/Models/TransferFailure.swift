import CrocKit

/// Why a transfer ended without its result: the words the failure screen
/// shows (design/content.md → Errors) and the action it offers
/// (design/components.md → StatusBlock). All failure copy lives in this file.
struct TransferFailure: Equatable {
    enum Remedy: Equatable {
        /// The same inputs could now succeed: Try Again, then Done.
        case tryAgain
        /// A setting is the cause: Open Settings, then Done.
        case openSettings(SettingsPlace)
    }

    /// What happened: sentence case, six words at most, no period.
    let title: String
    /// What to do, one sentence. nil for the user's own cancel or decline,
    /// which is not a failure.
    let detail: String?
    /// nil when retrying would not help: the user must change something, or
    /// the other device said no. Done alone.
    let remedy: Remedy?
    /// The user's own Cancel or Decline ended the transfer, so it ends
    /// silently (design/motion.md → Haptics and sound). A background expiry or
    /// the auto-accept block also cancels, but the user tapped nothing.
    var endedByUser = false

    /// Title and detail on one line, for a surface that takes one string
    /// (Shortcuts, the verify harness).
    var text: String {
        guard let detail else { return title }
        return "\(title). \(detail)"
    }
}

/// Where the fix for a failure lives.
enum SettingsPlace: Equatable {
    /// CrocApp's Settings: the relay, Local Network Only, Auto-Accept Transfers.
    case general
    /// CrocApp's Advanced settings.
    case advanced
    /// The system's Local Network permission for CrocApp.
    case localNetworkAccess
}

extension TransferFailure {
    /// What the controller knew when the transfer ended. Each of these
    /// outranks the engine's code.
    struct Situation {
        var direction: TransferController.Direction = .send
        var isStored = false
        var cancelRequested = false
        var declineRequested = false
        /// iOS ended the background task, which cancelled the transfer.
        var backgroundExpired = false
        /// Auto-accept cancelled an offer that holds an unsafe name.
        var blockedAutoAccept = false
        var autoAcceptActive = false
        /// Payload bytes moved, so starting again can resume.
        var bytesMoved = false
    }

    /// Precedence, highest first: a stuck engine, the auto-accept block, a
    /// background expiry, auto-accept meeting a sender's `--ask`, the user's
    /// own cancel or decline, then the engine's code.
    ///
    /// Never echoes `failure.message`: croc adds new error text every release,
    /// and a recovered Go panic arrives with a full stack trace attached.
    init(_ failure: EngineFailure, situation s: Situation) {
        if failure.code == .engineStuck {
            // Only a relaunch frees the engine, so this outranks every other
            // reason, a Cancel tap included.
            self = .engineStuck
        } else if s.blockedAutoAccept {
            self = .blockedAutoAccept
        } else if s.backgroundExpired {
            self = .backgroundExpired(stored: s.isStored, direction: s.direction)
        } else if s.autoAcceptActive, !s.cancelRequested, failure.code == .refused {
            // This side's prompt refused without anyone answering it. croc
            // forces the receiver prompt whenever the remote sender ran
            // --ask, regardless of NoPrompt; engine auto-accept has already
            // closed the prompt pipe, so GetInput hits EOF. While
            // autoAcceptActive is true respond() is never called, so
            // declineRequested cannot be set, and the condition excludes a
            // cancel -- what is left can only be this.
            self = .autoAcceptCannotConfirm
        } else if s.cancelRequested {
            self = .cancelledByUser
        } else if s.declineRequested {
            self = .declinedByUser
        } else {
            let copy = Self.copy(for: failure.code, stored: s.isStored, direction: s.direction)
            // A stored transfer cannot resume; it starts over.
            if s.bytesMoved && !s.isStored {
                self = TransferFailure(
                    title: copy.title, detail: Self.resumeHint, remedy: copy.remedy)
            } else {
                self = copy
            }
        }
    }

    static let cancelledByUser = TransferFailure(
        title: "Transfer cancelled", detail: nil, remedy: nil, endedByUser: true)

    static let declinedByUser = TransferFailure(
        title: "You declined the transfer", detail: nil, remedy: nil, endedByUser: true)

    /// The engine kept a cancelled transfer running and refuses every start
    /// until the app is relaunched.
    static let engineStuck = TransferFailure(
        title: "The cancelled transfer didn't stop",
        detail: "Quit and reopen CrocApp to transfer again.", remedy: nil)

    /// Used from both `.done` and `.failed`: a blocked transfer can terminate
    /// either way depending on whether the cancel beat the last event.
    static let blockedAutoAccept = TransferFailure(
        title: "Unsafe file names were blocked",
        detail: "Auto-accept cancelled the transfer, so ask the sender to rename the files.",
        remedy: nil)

    static let autoAcceptCannotConfirm = TransferFailure(
        title: "Auto-accept can't answer this sender",
        detail:
            "Turn off Auto-Accept Transfers in Settings and try again, or ask the sender to resend without their confirmation option.",
        remedy: .openSettings(.general))

    /// Keep Both saves a partly received file as a new copy, so only Replace
    /// resumes it.
    static let resumeHint =
        "Start the same transfer again; replacing the partly received files resumes it."

    /// A stored transfer cannot resume (concern 4), so it says to start over.
    static func backgroundExpired(
        stored: Bool, direction: TransferController.Direction
    ) -> TransferFailure {
        switch (stored, direction) {
        case (false, _):
            TransferFailure(title: "iOS paused the transfer", detail: resumeHint, remedy: .tryAgain)
        case (true, .send):
            TransferFailure(
                title: "Sending was interrupted",
                detail: "iOS stopped it in the background, so keep CrocApp open and try again.",
                remedy: .tryAgain)
        case (true, .receive):
            TransferFailure(
                title: "Receiving was interrupted",
                detail:
                    "iOS stopped it in the background, so keep CrocApp open and open the link again.",
                remedy: .tryAgain)
        }
    }

    /// `stored` words network failures for the link server (a store call
    /// reports them as `relayUnreachable` or `connectionLost`) instead of a
    /// relay or the other device.
    private static func copy(
        for code: EngineFailure.Code, stored: Bool, direction: TransferController.Direction
    ) -> TransferFailure {
        if stored, code == .relayUnreachable || code == .connectionLost {
            return TransferFailure(
                title: "Couldn't reach the link server",
                detail: "Check your internet connection and try again.", remedy: .tryAgain)
        }
        switch code {
        case .peerVersion:
            return TransferFailure(
                title: "The other device's croc is outdated",
                detail: "Both sides need croc 11 or newer, so update croc there.", remedy: nil)
        case .relayUnreachable:
            return TransferFailure(
                title: "Couldn't reach the relay", detail: "Check your internet connection.",
                remedy: .tryAgain)
        case .noPublicRelay:
            return TransferFailure(
                title: "No public relay answered",
                detail:
                    "Check your internet connection, or turn on Local Network Only in Settings if both devices are on the same network.",
                remedy: .tryAgain)
        case .declined:
            // A peer's cancel arrives the same way.
            return TransferFailure(
                title: "The other device declined or cancelled",
                detail: direction == .receive
                    ? "Ask them to send it again." : "Check with them before you send it again.",
                remedy: nil)
        case .refused:
            // This side's own prompt said no without a Decline tap (an EOF).
            return TransferFailure(title: "You declined the transfer", detail: nil, remedy: nil)
        case .roomFull:
            return TransferFailure(
                title: "That code is already in use", detail: "Try a different code.",
                remedy: nil)
        case .badPassword:
            return TransferFailure(
                title: "The relay rejected its password",
                detail: "Check the relay password in Settings.", remedy: .openSettings(.general))
        case .wrongCode:
            return TransferFailure(
                title: "The code phrases don't match",
                detail: "Check the code phrase on both devices.", remedy: nil)
        case .cancelled:
            return TransferFailure(title: "Transfer cancelled", detail: nil, remedy: nil)
        case .connectionLost:
            return TransferFailure(
                title: "Lost connection to the other device",
                detail: "Check your internet connection.", remedy: .tryAgain)
        case .storeLimit:
            // Over the server's size, file count or download limit, or too
            // many sends made recently.
            return TransferFailure(
                title: "The link server refused this send",
                detail:
                    "Send fewer or smaller files, allow fewer downloads, or wait a while before sending again.",
                remedy: nil)
        case .storeExpired:
            // scripts/verify-app-mac.sh matches this title.
            return TransferFailure(
                title: "This link no longer works",
                detail:
                    "It expired, was revoked or has no downloads left, so ask the sender for a new link.",
                remedy: nil)
        case .invalidSetting:
            return TransferFailure(
                title: "An Advanced setting can't be used",
                detail:
                    "Check the proxies, addresses, ports and send speed limit in Settings > Advanced.",
                remedy: .openSettings(.advanced))
        case .transferActive:
            return TransferFailure(
                title: "Another transfer is still running",
                detail: "Wait for it to end, then try again.", remedy: .tryAgain)
        case .engineStuck:
            return .engineStuck
        case .joinedEarly:
            // The receiver joined first, or a slow link made croc's probe reply
            // late. The sender has failed too by then, and a generated code
            // changes when it starts again, so the same code may not work.
            return TransferFailure(
                title: "The other device wasn't ready",
                detail:
                    "Start the send there first, or use a faster connection, then enter the code again.",
                remedy: nil)
        case .other:
            return TransferFailure(
                title: "The transfer failed", detail: "Check your connection and try again.",
                remedy: .tryAgain)
        }
    }
}
