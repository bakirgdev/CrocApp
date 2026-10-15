import Foundation
import Testing

@testable import CrocApp

#if os(macOS)
import ServiceManagement
#endif

@Suite struct ShowInMenuBarSettingTests {
    @Test func onByDefaultAndPersistsOff() throws {
        let name = "CrocAppTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let secrets = FakeSecretStore()
        #expect(AppSettings(defaults: defaults, secrets: secrets).showInMenuBar)
        AppSettings(defaults: defaults, secrets: secrets).showInMenuBar = false
        #expect(!AppSettings(defaults: defaults, secrets: secrets).showInMenuBar)
    }
}

@Suite struct ReceivedFileLocatorTests {
    @Test func copyNamesFollowKeepBoth() {
        #expect(ReceivedFileLocator.isCopy("a.txt", stem: "a", suffix: ".txt"))
        #expect(ReceivedFileLocator.isCopy("a (1).txt", stem: "a", suffix: ".txt"))
        #expect(ReceivedFileLocator.isCopy("a (12).txt", stem: "a", suffix: ".txt"))
        #expect(!ReceivedFileLocator.isCopy("a (x).txt", stem: "a", suffix: ".txt"))
        #expect(!ReceivedFileLocator.isCopy("ab.txt", stem: "a", suffix: ".txt"))
        #expect(!ReceivedFileLocator.isCopy("a.txt.bak", stem: "a", suffix: ".txt"))
        #expect(ReceivedFileLocator.isCopy("README", stem: "README", suffix: ""))
        #expect(ReceivedFileLocator.isCopy("README (2)", stem: "README", suffix: ""))
    }

    @Test func prefersTheNewKeepBothCopyOverTheOldFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let old = dir.appendingPathComponent("a.txt")
        try Data("old".utf8).write(to: old)
        Thread.sleep(forTimeInterval: 0.05)
        let started = Date()
        let copy = dir.appendingPathComponent("a (1).txt")
        try Data("new".utf8).write(to: copy)
        let found = ReceivedFileLocator.locate(names: ["a.txt"], in: dir, since: started)
        #expect(found.map(\.lastPathComponent) == ["a (1).txt"])
    }

    @Test func aSecondOfferedNameIsNotTakenAsACopyOfTheFirst() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let started = Date()
        try Data("1".utf8).write(to: dir.appendingPathComponent("a.txt"))
        Thread.sleep(forTimeInterval: 0.05)
        try Data("2".utf8).write(to: dir.appendingPathComponent("a (1).txt"))
        let found = ReceivedFileLocator.locate(
            names: ["a.txt", "a (1).txt"], in: dir, since: started)
        #expect(found.map(\.lastPathComponent) == ["a.txt", "a (1).txt"])
    }

    @Test func fallsBackToTheNamedFileAfterAReplace() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("x".utf8).write(to: dir.appendingPathComponent("sub/b.txt"))
        let found = ReceivedFileLocator.locate(
            names: ["sub/b.txt", "missing.txt"], in: dir, since: Date().addingTimeInterval(60))
        #expect(found.map(\.lastPathComponent) == ["b.txt"])
    }
}

#if os(macOS)
@MainActor
@Suite struct LoginItemTests {
    final class FakeService: LoginItemService {
        var status: SMAppService.Status = .notRegistered
        var failure: Error?
        func register() throws {
            if let failure { throw failure }
            status = .enabled
        }
        func unregister() throws {
            if let failure { throw failure }
            status = .notRegistered
        }
    }

    struct Boom: Error {}

    @Test func toggleFollowsTheSystemStatus() {
        let service = FakeService()
        let item = LoginItem(service: service)
        #expect(!item.isRegistered)
        item.setRegistered(true)
        #expect(item.isRegistered && !item.needsApproval)
        item.setRegistered(false)
        #expect(!item.isRegistered)
    }

    @Test func approvalPendingCountsAsRegisteredAndNeedsApproval() {
        let service = FakeService()
        service.status = .requiresApproval
        let item = LoginItem(service: service)
        #expect(item.isRegistered && item.needsApproval)
    }

    @Test func refreshPicksUpAChangeMadeInSystemSettings() {
        let service = FakeService()
        let item = LoginItem(service: service)
        service.status = .enabled
        #expect(!item.isRegistered)
        item.refresh()
        #expect(item.isRegistered)
    }

    @Test func aFailedRegisterShowsAnErrorAndKeepsTheRealStatus() {
        let service = FakeService()
        service.failure = Boom()
        let item = LoginItem(service: service)
        item.setRegistered(true)
        #expect(item.errorMessage != nil)
        #expect(!item.isRegistered)
    }
}

@MainActor
@Suite struct MenuBarQuickSendTests {
    private func makeController() -> TransferController {
        TransferController(
            settings: AppSettings(
                defaults: UserDefaults(suiteName: "CrocAppTests.\(UUID().uuidString)")!,
                secrets: FakeSecretStore()),
            vault: StoredTransferVault(secrets: MemorySecretStore()))
    }

    @Test func sendRefusesAnythingButFiles() {
        let controller = makeController()
        let quickSend = MenuBarQuickSend(controller: controller)
        #expect(!quickSend.send(urls: []))
        #expect(!quickSend.send(urls: [URL(string: "https://example.com/a")!]))
        #expect(!controller.isActive)
    }
}
#endif
