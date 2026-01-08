import Foundation

// MARK: - Permission Mode

enum PermissionMode: Sendable {
    case plan
    case acceptEdits
    case bypassPermissions
    case `default`

    var cliValue: String {
        switch self {
        case .plan: return "plan"
        case .acceptEdits: return "acceptEdits"
        case .bypassPermissions: return "bypassPermissions"
        case .default: return "default"
        }
    }

    var usesDangerouslySkipPermissions: Bool {
        self == .bypassPermissions
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

enum ClaudeCLIServiceError: Error, LocalizedError {
    case noResultMessage
    case processError(ClaudeProcessError)
    case executableNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noResultMessage:
            return "No result message received from Claude CLI"
        case .processError(let error):
            return "Process error: \(error.localizedDescription)"
        case .executableNotFound(let path):
            return "Claude CLI not found at: \(path)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .noResultMessage, .executableNotFound:
            return false
        case .processError(let error):
            return error.isRetryable
        }
    }
}

// MARK: - Claude CLI Service

final class ClaudeCLIService: ClaudeCLIServiceProtocol, @unchecked Sendable {
    let executablePath: String
    private var currentProcess: ClaudeProcess?

    init(executablePath: String? = nil) {
        self.executablePath = executablePath ?? Self.findClaudePath()
    }

    private static func findClaudePath() -> String {
        // Try common installation paths
        var commonPaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            NSHomeDirectory() + "/.npm-global/bin/claude"
        ]

        // Dynamically search NVM versions directory for claude
        let nvmVersionsPath = NSHomeDirectory() + "/.nvm/versions/node"
        if let nodeVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsPath) {
            for version in nodeVersions.sorted().reversed() {
                let claudePath = "\(nvmVersionsPath)/\(version)/bin/claude"
                commonPaths.append(claudePath)
            }
        }

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: try to find using login shell (with timeout to prevent hanging)
        // Use login shell (-l) to get full PATH including nvm, homebrew, etc.
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which claude"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            let deadline = Date().addingTimeInterval(5.0)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }

            if process.isRunning {
                process.terminate()
                return "/usr/local/bin/claude"
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {
            // Ignore errors, fall through to default
        }

        return "/usr/local/bin/claude"
    }

    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String? = nil,
        timeout: TimeInterval? = nil,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        try await executeInternal(
            prompt: prompt,
            stdinData: nil,
            workingDirectory: workingDirectory,
            permissionMode: permissionMode,
            sessionId: sessionId,
            timeout: timeout,
            onMessage: onMessage
        )
    }

    func execute(
        content: PromptContent,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String? = nil,
        timeout: TimeInterval? = nil,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        if content.hasImages {
            let stdinData = try content.toJSONData()
            return try await executeInternal(
                prompt: "-",
                stdinData: stdinData,
                workingDirectory: workingDirectory,
                permissionMode: permissionMode,
                sessionId: sessionId,
                timeout: timeout,
                onMessage: onMessage
            )
        } else {
            return try await execute(
                prompt: content.text,
                workingDirectory: workingDirectory,
                permissionMode: permissionMode,
                sessionId: sessionId,
                timeout: timeout,
                onMessage: onMessage
            )
        }
    }

    private func executeInternal(
        prompt: String,
        stdinData: Data?,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            print("[ClaudeCLI] Executable not found at: \(executablePath)")
            throw ClaudeCLIServiceError.executableNotFound(executablePath)
        }

        print("[ClaudeCLI] Using executable: \(executablePath)")
        print("[ClaudeCLI] Working directory: \(workingDirectory.path)")

        let arguments = buildArguments(
            prompt: prompt,
            permissionMode: permissionMode,
            sessionId: sessionId
        )

        print("[ClaudeCLI] Arguments: \(arguments)")
        if stdinData != nil {
            print("[ClaudeCLI] Sending content via stdin")
        }

        let process = ClaudeProcess(
            executablePath: executablePath,
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout,
            stdinData: stdinData
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
            print("[ClaudeCLI] Process error: \(error)")
            currentProcess = nil
            throw ClaudeCLIServiceError.processError(error)
        }

        currentProcess = nil

        guard let result = resultMessage else {
            print("[ClaudeCLI] No result message received")
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
            "--verbose"
        ]

        if permissionMode.usesDangerouslySkipPermissions {
            args.append("--dangerously-skip-permissions")
        } else {
            args.append(contentsOf: ["--permission-mode", permissionMode.cliValue])
        }

        if let sessionId = sessionId {
            args.append(contentsOf: ["--resume", sessionId])
        }

        args.append(prompt)

        return args
    }
}
