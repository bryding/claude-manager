import Foundation

enum ClaudeProcessError: Error, LocalizedError {
    case nonZeroExitCode(Int32, stderr: String?)
    case outputReadError(Error)
    case timedOut
    case interrupted

    var errorDescription: String? {
        switch self {
        case .nonZeroExitCode(let code, let stderr):
            let stderrInfo = stderr.map { ": \($0)" } ?? ""
            return "Process exited with code \(code)\(stderrInfo)"
        case .outputReadError(let error):
            return "Failed to read process output: \(error.localizedDescription)"
        case .timedOut:
            return "Process timed out"
        case .interrupted:
            return "Process was interrupted"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timedOut, .interrupted:
            return true
        case .nonZeroExitCode(let code, _):
            return code == 1
        case .outputReadError:
            return false
        }
    }
}

final class ClaudeProcess: @unchecked Sendable {
    let executablePath: String
    let arguments: [String]
    let workingDirectory: URL
    let timeout: TimeInterval?

    private var process: Process?
    private var didTimeout = false

    init(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL,
        timeout: TimeInterval? = nil
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }

    func run() -> AsyncThrowingStream<ClaudeStreamMessage, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let parser = ClaudeMessageParser()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            self.process = process

            var timeoutTask: Task<Void, Never>?

            if let timeout = self.timeout {
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning {
                        self?.didTimeout = true
                        process.terminate()
                    }
                }
            }

            Task {
                do {
                    try process.run()

                    let stdoutHandle = stdoutPipe.fileHandleForReading
                    for try await line in stdoutHandle.bytes.lines {
                        if let message = parser.parse(line: line) {
                            continuation.yield(message)
                        }
                    }

                    process.waitUntilExit()
                    timeoutTask?.cancel()

                    if self.didTimeout {
                        continuation.finish(throwing: ClaudeProcessError.timedOut)
                    } else {
                        let exitCode = process.terminationStatus
                        if exitCode != 0 {
                            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                            let stderrString = String(data: stderrData, encoding: .utf8)
                            continuation.finish(throwing: ClaudeProcessError.nonZeroExitCode(exitCode, stderr: stderrString))
                        } else {
                            continuation.finish()
                        }
                    }
                } catch {
                    timeoutTask?.cancel()
                    continuation.finish(throwing: ClaudeProcessError.outputReadError(error))
                }
            }

            continuation.onTermination = { @Sendable _ in
                timeoutTask?.cancel()
                process.terminate()
            }
        }
    }

    func terminate() {
        process?.terminate()
    }

    func interrupt() {
        process?.interrupt()
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }
}
