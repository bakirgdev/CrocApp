#if os(macOS)
import Observation
import ServiceManagement

/// The slice of `SMAppService` the Open at login toggle uses, so tests can
/// stand in for the system.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Open at login (R26): the toggle shows what the system reports, never a
/// stored copy of what we asked for, because the user can change it in System
/// Settings > General > Login Items at any time.
@MainActor
@Observable
final class LoginItem {
    private let service: any LoginItemService
    private(set) var status: SMAppService.Status
    private(set) var errorMessage: String?

    init(service: any LoginItemService = SMAppService.mainApp) {
        self.service = service
        status = service.status
    }

    /// Registered, whether or not the user has approved it yet.
    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    var needsApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = service.status
    }

    func setRegistered(_ on: Bool) {
        errorMessage = nil
        do {
            if on { try service.register() } else { try service.unregister() }
        } catch {
            errorMessage = "Couldn't change Open at login: \(error.localizedDescription)"
        }
        refresh()
    }
}
#endif
