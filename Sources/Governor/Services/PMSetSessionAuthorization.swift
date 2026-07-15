import Darwin
import Foundation
import GovernorHelperSupport
import Security

enum SessionAuthorizationError: Error, Equatable, LocalizedError, Sendable {
    case authorizationNotRequested
    case authorizationFailed(OSStatus)
    case deprecatedExecutorUnavailable
    case privilegedLaunchFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .authorizationNotRequested:
            "Administrator authorization has not been granted for this Governor session."
        case let .authorizationFailed(status):
            "Administrator authorization failed (OSStatus \(status))."
        case .deprecatedExecutorUnavailable:
            "The session authorization API is unavailable on this macOS version."
        case let .privilegedLaunchFailed(status):
            "Unable to launch the fixed privileged power command (OSStatus \(status))."
        }
    }
}

/// A deliberately session-scoped compatibility bridge for the free manual
/// build. It requests admin authorization once from an explicit user action,
/// forgets it when Governor exits, and can execute only the finite `pmset`
/// command set produced by `PrivilegedPMSetCommand`.
///
/// `AuthorizationExecuteWithPrivileges` is deprecated, so signed and
/// notarized builds continue to use the SMAppService helper instead. This
/// bridge is never a persistent daemon, never uses a shell, and never exposes
/// a caller-selected executable path or argument vector.
actor SessionAuthorizationExecutor {
    private enum State: @unchecked Sendable {
        case notAttempted
        case authorized(AuthorizationRef)
        case failed(SessionAuthorizationError)
    }

    private var state: State = .notAttempted

    deinit {
        if case let .authorized(reference) = state {
            AuthorizationFree(reference, [.destroyRights])
        }
    }

    func authorizeOnce() throws {
        switch state {
        case .authorized:
            return
        case let .failed(error):
            throw error
        case .notAttempted:
            break
        }

        var reference: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &reference)
        guard createStatus == errAuthorizationSuccess, let reference else {
            let error = SessionAuthorizationError.authorizationFailed(createStatus)
            state = .failed(error)
            throw error
        }

        let copyStatus: OSStatus = kAuthorizationRightExecute.withCString { rightName in
            var item = AuthorizationItem(
                name: rightName,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &item) { items in
                var rights = AuthorizationRights(count: 1, items: items)
                return AuthorizationCopyRights(
                    reference,
                    &rights,
                    nil,
                    [.interactionAllowed, .extendRights, .preAuthorize],
                    nil
                )
            }
        }

        guard copyStatus == errAuthorizationSuccess else {
            AuthorizationFree(reference, [.destroyRights])
            let error = SessionAuthorizationError.authorizationFailed(copyStatus)
            state = .failed(error)
            throw error
        }

        state = .authorized(reference)
    }

    /// Executes only a locally revalidated, fixed `pmset` request. There is no
    /// public method that accepts an executable path or arbitrary arguments.
    func execute(_ request: GovernorPowerModeRequest) throws {
        let reference: AuthorizationRef
        switch state {
        case let .authorized(value):
            reference = value
        case let .failed(error):
            throw error
        case .notAttempted:
            throw SessionAuthorizationError.authorizationNotRequested
        }

        let arguments = try PrivilegedPMSetCommand.arguments(for: request)
        guard let function = Self.authorizationExecuteFunction else {
            throw SessionAuthorizationError.deprecatedExecutorUnavailable
        }

        let cArguments = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
            .allocate(capacity: arguments.count + 1)
        defer { cArguments.deallocate() }

        for (index, argument) in arguments.enumerated() {
            cArguments[index] = strdup(argument)
        }
        cArguments[arguments.count] = nil
        defer {
            for index in arguments.indices {
                free(cArguments[index])
            }
        }

        // The imported legacy signature treats argv entries as nonoptional;
        // the backing allocation above is explicitly NULL-terminated.
        let importedArguments = UnsafeRawPointer(cArguments)
            .assumingMemoryBound(to: UnsafeMutablePointer<CChar>.self)
        var communicationsPipe: UnsafeMutablePointer<FILE>?
        let status = PMSetArguments.executablePath.withCString { executablePath in
            function(reference, executablePath, 0, importedArguments, &communicationsPipe)
        }
        guard status == errAuthorizationSuccess else {
            throw SessionAuthorizationError.privilegedLaunchFailed(status)
        }

        // Draining the pipe waits for the short-lived fixed command to exit.
        // Its status is independently confirmed by a fresh non-privileged read
        // in PMSetPowerSystemClient immediately after this call.
        if let communicationsPipe {
            let handle = FileHandle(
                fileDescriptor: fileno(communicationsPipe),
                closeOnDealloc: false
            )
            _ = handle.readDataToEndOfFile()
            fclose(communicationsPipe)
        }
    }

    private typealias AuthorizationExecuteFunction = @convention(c) (
        AuthorizationRef,
        UnsafePointer<CChar>,
        UInt32,
        UnsafePointer<UnsafeMutablePointer<CChar>>,
        UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
    ) -> OSStatus

    private static let authorizationExecuteFunction: AuthorizationExecuteFunction? = {
        guard let handle = dlopen(
            "/System/Library/Frameworks/Security.framework/Security",
            RTLD_LAZY | RTLD_LOCAL
        ) else {
            return nil
        }
        guard let symbol = dlsym(handle, "AuthorizationExecuteWithPrivileges") else {
            return nil
        }
        return unsafeBitCast(symbol, to: AuthorizationExecuteFunction.self)
    }()
}
