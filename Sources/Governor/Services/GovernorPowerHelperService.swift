import Foundation
import GovernorHelperSupport
import ServiceManagement

enum GovernorPowerHelperServiceStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

enum GovernorPowerHelperInstallationError: Error, Equatable, Sendable {
    case requiresApproval
    case unavailableInCurrentBuild
    case helperNotFound
    case registrationFailed
}

/// The ad-hoc package exists only for manual app installation. Apple does not
/// permit it to register the bundled root LaunchDaemon, so do not send users to
/// Login Items for a helper that can never appear there.
private enum GovernorPowerHelperBuildCapability {
    static let registrationSupportedInfoKey = "GovernorPersistentHelperRegistrationSupported"

    static var currentBundleSupportsPersistentHelper: Bool {
        Bundle.main.object(forInfoDictionaryKey: registrationSupportedInfoKey) as? Bool == true
    }
}

@MainActor
protocol GovernorPowerHelperServiceManaging: Sendable {
    var status: GovernorPowerHelperServiceStatus { get }
    func register() throws
}

@MainActor
private final class SystemGovernorPowerHelperService: GovernorPowerHelperServiceManaging {
    private let service = SMAppService.daemon(
        plistName: GovernorPowerHelperContract.daemonPlistName
    )

    var status: GovernorPowerHelperServiceStatus {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func register() throws {
        try service.register()
    }
}

/// Owns the one-time Service Management registration state machine.
///
/// It does not invoke an authorization API on every enable. After an admin has
/// approved the daemon once in System Settings, every future app process only
/// observes `.enabled` and connects to the existing root helper.
@MainActor
final class GovernorPowerHelperInstaller: GovernorPowerHelperServiceManaging {
    private let service: any GovernorPowerHelperServiceManaging
    private let supportsPersistentHelper: Bool

    static let system = GovernorPowerHelperInstaller(
        service: SystemGovernorPowerHelperService(),
        supportsPersistentHelper: GovernorPowerHelperBuildCapability.currentBundleSupportsPersistentHelper
    )

    init(
        service: any GovernorPowerHelperServiceManaging,
        supportsPersistentHelper: Bool = true
    ) {
        self.service = service
        self.supportsPersistentHelper = supportsPersistentHelper
    }

    var status: GovernorPowerHelperServiceStatus { service.status }

    static var currentBuildSupportsPersistentHelper: Bool {
        GovernorPowerHelperBuildCapability.currentBundleSupportsPersistentHelper
    }

    func register() throws {
        try service.register()
    }

    func ensureAvailable() throws {
        guard supportsPersistentHelper else {
            throw GovernorPowerHelperInstallationError.unavailableInCurrentBuild
        }

        switch service.status {
        case .enabled:
            return

        case .requiresApproval:
            throw GovernorPowerHelperInstallationError.requiresApproval

        case .notFound:
            throw GovernorPowerHelperInstallationError.helperNotFound

        case .notRegistered:
            do {
                try service.register()
            } catch {
                if service.status == .enabled {
                    return
                }
                throw errorForCurrentStatus()
            }

            guard service.status == .enabled else {
                throw errorForCurrentStatus()
            }
        }
    }

    static func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func errorForCurrentStatus() -> GovernorPowerHelperInstallationError {
        switch service.status {
        case .requiresApproval: .requiresApproval
        case .notFound: .helperNotFound
        case .enabled: .registrationFailed
        case .notRegistered: .registrationFailed
        }
    }
}
