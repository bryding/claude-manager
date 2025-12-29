import Foundation

enum ClaudeProcessError: Error {
    case nonZeroExitCode(Int32, stderr: String?)
    case outputReadError(Error)
}

final class ClaudeProcess: @unchecked Sendable {
    let executablePath: String
    let arguments: [String]
    let workingDirectory: URL

    private var process: Process?

    init(executablePath: String, arguments: [String], workingDirectory: URL) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
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

                    let exitCode = process.terminationStatus
                    if exitCode != 0 {
                        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let stderrString = String(data: stderrData, encoding: .utf8)
                        continuation.finish(throwing: ClaudeProcessError.nonZeroExitCode(exitCode, stderr: stderrString))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: ClaudeProcessError.outputReadError(error))
                }
            }

            continuation.onTermination = { @Sendable _ in
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
