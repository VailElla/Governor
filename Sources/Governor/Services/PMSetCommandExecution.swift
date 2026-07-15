import Foundation

/// The three non-privileged `pmset` reads Governor needs to observe the
/// current system state. Keeping this as a closed enum prevents the normal
/// process runner from becoming a generic command launcher.
enum PMSetReadCommand: Sendable {
    case powerSource
    case liveState
    case capabilities

    var arguments: [String] {
        switch self {
        case .powerSource: PMSetArguments.readPowerSource
        case .liveState: PMSetArguments.readLive
        case .capabilities: PMSetArguments.readCapabilities
        }
    }
}

struct PMSetCommandRunner: Sendable {
    func run(_ command: PMSetReadCommand) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: PMSetArguments.executablePath)
            process.arguments = command.arguments
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            process.environment = [:]

            do {
                try process.run()
            } catch {
                throw PMSetExecutionError.launchFailed(error.localizedDescription)
            }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)

            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                throw PMSetExecutionError.commandFailed(
                    status: process.terminationStatus,
                    output: output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            return output
        }.value
    }
}

enum PMSetExecutionError: Error, Equatable, LocalizedError, Sendable {
    case launchFailed(String)
    case commandFailed(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            "Unable to launch pmset: \(message)"
        case let .commandFailed(status, output):
            output.isEmpty
                ? "pmset exited with status \(status)."
                : "pmset exited with status \(status): \(output)"
        }
    }
}
