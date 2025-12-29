import Foundation

// MARK: - Permission Mode

enum PermissionMode: Sendable {
    case plan
    case acceptEdits
    case `default`

    var cliValue: String {
        switch self {
        case .plan: return "plan"
        case .acceptEdits: return "acceptEdits"
        case .default: return "default"
        }
    }
}

// MARK: - Execution Result

struct ClaudeExecutionResult: Sendable {
    let result: String
    let sessionId: String
    let totalCostUsd: Double
    let durationMs: Int
    let isError: Bool
}

// MARK: - Service Error

enum ClaudeCLIServiceError: Error {
    case noResultMessage
    case processError(ClaudeProcessError)
}

// MARK: - Claude CLI Service

final class ClaudeCLIService: @unchecked Sendable {
    let executablePath: String
    private var currentProcess: ClaudeProcess?

    init(executablePath: String = "/usr/local/bin/claude") {
        self.executablePath = executablePath
    }

    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String? = nil,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        let arguments = buildArguments(
            prompt: prompt,
            permissionMode: permissionMode,
            sessionId: sessionId
        )

        let process = ClaudeProcess(
            executablePath: executablePath,
            arguments: arguments,
            workingDirectory: workingDirectory
        )
        currentProcess = process

        var resultMessage: ResultMessage?

        do {
            for try await message in process.run() {
                await onMessage(message)

                if case .result(let result) = message {
                    resultMessage = result
                }
            }
        } catch let error as ClaudeProcessError {
            currentProcess = nil
            throw ClaudeCLIServiceError.processError(error)
        }

        currentProcess = nil

        guard let result = resultMessage else {
            throw ClaudeCLIServiceError.noResultMessage
        }

        return ClaudeExecutionResult(
            result: result.result,
            sessionId: result.sessionId,
            totalCostUsd: result.totalCostUsd,
            durationMs: result.durationMs,
            isError: result.isError
        )
    }

    func terminate() {
        currentProcess?.terminate()
    }

    func interrupt() {
        currentProcess?.interrupt()
    }

    var isRunning: Bool {
        currentProcess?.isRunning ?? false
    }

    private func buildArguments(
        prompt: String,
        permissionMode: PermissionMode,
        sessionId: String?
    ) -> [String] {
        var args: [String] = [
            "-p",
            "--output-format", "stream-json",
            "--permission-mode", permissionMode.cliValue
        ]

        if let sessionId = sessionId {
            args.append(contentsOf: ["--resume", sessionId])
        }

        args.append(prompt)

        return args
    }
}
