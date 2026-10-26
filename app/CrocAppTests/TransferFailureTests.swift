import CrocKit
import Testing

@testable import CrocApp

/// The failure each engine code and each controller-side reason ends in: its
/// remedy, whether the user caused it, and the copy rules of
/// design/content.md → Errors. Copy itself is pinned only where a script
/// matches it.
@MainActor @Suite struct TransferFailureTests {
    private func failure(
        _ code: EngineFailure.Code, _ situation: TransferFailure.Situation = .init(),
        message: String = "croc text"
    ) -> TransferFailure {
        TransferFailure(EngineFailure(code: code, message: message), situation: situation)
    }

    /// design/components.md → StatusBlock: worth another try, a setting is the
    /// cause, or retrying would not help.
    private nonisolated static let remedies: [(EngineFailure.Code, TransferFailure.Remedy?)] = [
        (.peerVersion, nil),
        (.relayUnreachable, .tryAgain),
        (.noPublicRelay, .tryAgain),
        (.declined, nil),
        (.refused, nil),
        (.roomFull, nil),
        (.badPassword, .openSettings(.general)),
        (.wrongCode, nil),
        (.cancelled, nil),
        (.connectionLost, .tryAgain),
        (.storeLimit, nil),
        (.storeExpired, nil),
        (.invalidSetting, .openSettings(.advanced)),
        (.transferActive, .tryAgain),
        (.engineStuck, nil),
        (.joinedEarly, nil),
        (.other, .tryAgain),
    ]

    @Test(arguments: remedies)
    func remedyPerCode(code: EngineFailure.Code, remedy: TransferFailure.Remedy?) {
        #expect(failure(code).remedy == remedy)
        #expect(!failure(code).endedByUser, "no cancel or decline was tapped")
    }

    @Test func everyCodeHasARemedy() {
        #expect(Set(Self.remedies.map(\.0)) == Set(EngineFailure.Code.allCases))
    }

    /// A cancel or decline the user made is not a failure: a title alone,
    /// Done alone, and no haptic.
    @Test(arguments: EngineFailure.Code.allCases.filter { $0 != .engineStuck })
    func theUsersOwnCancelOrDeclineIsNotAFailure(code: EngineFailure.Code) {
        let cancelled = failure(code, .init(cancelRequested: true, declineRequested: true))
        #expect(cancelled == .cancelledByUser)
        let declined = failure(code, .init(declineRequested: true))
        #expect(declined == .declinedByUser)
        for ended in [cancelled, declined] {
            #expect(ended.endedByUser)
            #expect(ended.detail == nil)
            #expect(ended.remedy == nil)
        }
    }

    /// A stuck engine refuses every later start, so a Cancel tap must not hide it.
    @Test func aStuckEngineOutranksEverything() {
        let s = TransferFailure.Situation(
            isStored: true, cancelRequested: true, declineRequested: true,
            backgroundExpired: true, blockedAutoAccept: true, autoAcceptActive: true,
            bytesMoved: true)
        #expect(failure(.engineStuck, s) == .engineStuck)
        #expect(!failure(.engineStuck, s).endedByUser)
        #expect(failure(.engineStuck).remedy == nil)
    }

    @Test func controllerReasonsOutrankTheCancelInThisOrder() {
        var s = TransferFailure.Situation(
            cancelRequested: true, backgroundExpired: true, blockedAutoAccept: true,
            autoAcceptActive: true)
        #expect(failure(.cancelled, s) == .blockedAutoAccept)
        s.blockedAutoAccept = false
        #expect(failure(.cancelled, s) == .backgroundExpired(stored: false, direction: .send))
        #expect(!failure(.cancelled, s).endedByUser, "iOS cancelled it, not the user")
        s.backgroundExpired = false
        #expect(failure(.refused, s) == .cancelledByUser, "a Cancel tap is not the --ask case")
        s.cancelRequested = false
        #expect(failure(.refused, s) == .autoAcceptCannotConfirm)
        #expect(failure(.declined, s) != .autoAcceptCannotConfirm, "only croc's local refusal")
        #expect(failure(.refused, .init()) != .autoAcceptCannotConfirm, "only under auto-accept")
    }

    @Test(arguments: [
        (false, TransferController.Direction.send), (false, .receive), (true, .send),
        (true, .receive),
    ])
    func aBackgroundExpiryIsWorthAnotherTry(stored: Bool, direction: TransferController.Direction) {
        let expired = failure(
            .cancelled,
            .init(direction: direction, isStored: stored, backgroundExpired: true))
        #expect(expired.remedy == .tryAgain)
        #expect(
            (expired.detail == TransferFailure.resumeHint) == !stored,
            "a stored transfer cannot resume")
    }

    @Test func storedExpiriesNameTheirDirection() {
        #expect(
            TransferFailure.backgroundExpired(stored: true, direction: .send)
                != TransferFailure.backgroundExpired(stored: true, direction: .receive))
    }

    /// A store call reports a network failure as `relayUnreachable` or
    /// `connectionLost`; no relay or other device is involved.
    @Test(arguments: [EngineFailure.Code.relayUnreachable, .connectionLost])
    func storedNetworkFailureNamesTheLinkServer(code: EngineFailure.Code) {
        let stored = failure(code, .init(isStored: true))
        #expect(stored.title.contains("link server"))
        #expect(stored != failure(code))
        #expect(stored.remedy == .tryAgain)
    }

    @Test func storedKeepsStoreCodesAndTheUsersCancel() {
        #expect(failure(.storeExpired, .init(isStored: true)) == failure(.storeExpired))
        #expect(
            failure(.relayUnreachable, .init(isStored: true, cancelRequested: true))
                == .cancelledByUser)
    }

    /// scripts/verify-app-mac.sh matches "error <title>" for a revoked link.
    @Test func anExpiredLinkKeepsTheTitleTheMacHarnessMatches() {
        let expired = failure(.storeExpired, .init(direction: .receive, isStored: true))
        #expect(expired.title == "This link no longer works")
        #expect(expired.text.hasPrefix("This link no longer works. "))
    }

    @Test(arguments: [EngineFailure.Code.connectionLost, .other, .declined])
    func theResumeHintNeedsBytesAndALiveTransfer(code: EngineFailure.Code) {
        #expect(failure(code, .init(bytesMoved: true)).detail == TransferFailure.resumeHint)
        #expect(failure(code).detail != TransferFailure.resumeHint)
        #expect(
            failure(code, .init(isStored: true, bytesMoved: true)).detail
                != TransferFailure.resumeHint, "a stored transfer cannot resume")
        #expect(
            failure(code, .init(bytesMoved: true)).remedy == failure(code).remedy,
            "the hint changes the words, not the action")
    }

    @Test func aDeclineToldToTheSenderAndTheReceiverDiffers() {
        #expect(
            failure(.declined, .init(direction: .send)).detail
                != failure(.declined, .init(direction: .receive)).detail)
    }

    @Test func textJoinsTitleAndDetail() {
        let one = TransferFailure(title: "Title", detail: "Do this.", remedy: nil)
        #expect(one.text == "Title. Do this.")
        #expect(TransferFailure.cancelledByUser.text == TransferFailure.cancelledByUser.title)
    }

    /// Every failure the app can show, in every situation that changes its words.
    private var everyFailure: [TransferFailure] {
        let situations: [TransferFailure.Situation] = [
            .init(), .init(direction: .receive), .init(isStored: true),
            .init(direction: .receive, isStored: true), .init(bytesMoved: true),
            .init(autoAcceptActive: true),
        ]
        let fromCodes = EngineFailure.Code.allCases.flatMap { code in
            situations.map { failure(code, $0) }
        }
        return fromCodes + [
            .cancelledByUser, .declinedByUser, .engineStuck, .blockedAutoAccept,
            .autoAcceptCannotConfirm,
            .backgroundExpired(stored: false, direction: .send),
            .backgroundExpired(stored: true, direction: .send),
            .backgroundExpired(stored: true, direction: .receive),
        ]
    }

    /// design/content.md → Errors: a title of six words at most with no
    /// period, and a detail of one sentence with one.
    @Test func everyFailureFollowsTheCopyRules() {
        for f in everyFailure {
            let words = f.title.split(whereSeparator: \.isWhitespace)
            #expect(words.count <= 6, "\(f.title)")
            #expect(!f.title.hasSuffix("."), "\(f.title)")
            #expect(!f.title.lowercased().contains("invalid"), "\(f.title)")
            #expect(
                f.title.first?.isUppercase == true || f.title.hasPrefix("iOS "), "\(f.title)")
            if let detail = f.detail {
                #expect(detail.hasSuffix("."), "\(detail)")
                #expect(!detail.dropLast().contains(". "), "one sentence: \(detail)")
            }
            if f.endedByUser { #expect(f.detail == nil) }
        }
    }

    @Test(arguments: ["", "room full", "panic: runtime error\ngoroutine 1 [running]:"])
    func neverEchoesEngineText(text: String) {
        for code in EngineFailure.Code.allCases {
            let f = failure(code, message: text + " marker-7f3")
            #expect(!f.text.contains("marker-7f3"), "\(code)")
        }
    }
}
