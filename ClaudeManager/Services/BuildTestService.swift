import Foundation

// MARK: - Error Type

enum BuildTestServiceError: Error, LocalizedError {
    case noBuildCommand
    case noTestCommand
    case processCreationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noBuildCommand:
            return "No build command configured for this project type"
        case .noTestCommand:
            return "No test command configured for this project type"
        case .processCreationFailed(let error):
            return "Failed to create process: \(error.localizedDescription)"
        }
    }
}

// MARK: - BuildTestService

final class BuildTestService: BuildTestServiceProtocol, @unchecked Sendable {

    // MARK: - Project Type Detection

    func detectProjectType(in directory: URL) -> ProjectType {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
            return .swift
        }

        if let contents = try? fileManager.contentsOfDirectory(atPath: directory.path),
           contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
            return .xcode
        }

        let hasPackageJson = fileManager.fileExists(atPath: directory.appendingPathComponent("package.json").path)
        let hasTsConfig = fileManager.fileExists(atPath: directory.appendingPathComponent("tsconfig.json").path)
        if hasPackageJson && hasTsConfig {
            return .typescript
        }

        if hasPackageJson {
            return .javascript
        }

        if fileManager.fileExists(atPath: directory.appendingPathComponent("Cargo.toml").path) {
            return .rust
        }

        if fileManager.fileExists(atPath: directory.appendingPathComponent("go.mod").path) {
            return .go
        }

        if fileManager.fileExists(atPath: directory.appendingPathComponent("pyproject.toml").path) ||
           fileManager.fileExists(atPath: directory.appendingPathComponent("setup.py").path) ||
           fileManager.fileExists(atPath: directory.appendingPathComponent("requirements.txt").path) {
            return .python
        }

        return .unknown
    }

    // MARK: - Default Commands

    func defaultBuildCommand(for projectType: ProjectType) -> String? {
        switch projectType {
        case .swift:
            return "swift build"
        case .xcode:
            return "xcodebuild build"
        case .typescript, .javascript:
            return "npm run build"
        case .rust:
            return "cargo build"
        case .go:
            return "go build ./..."
        case .python, .unknown:
            return nil
        }
    }

    func defaultTestCommand(for projectType: ProjectType) -> String? {
        switch projectType {
        case .swift:
            return "swift test"
        case .xcode:
            return "xcodebuild test"
        case .typescript, .javascript:
            return "npm test"
        case .rust:
            return "cargo test"
        case .go:
            return "go test ./..."
        case .python:
            return "pytest"
        case .unknown:
            return nil
        }
    }

    // MARK: - Build Execution

    func runBuild(in directory: URL, config: ProjectConfiguration) async throws -> BuildResult {
        let command = config.buildCommand ?? defaultBuildCommand(for: config.projectType)
        guard let command = command else {
            throw BuildTestServiceError.noBuildCommand
        }

        let result = try await runCommand(command, in: directory)
        return BuildResult(
            success: result.exitCode == 0,
            output: result.output,
            errorOutput: result.errorOutput.isEmpty ? nil : result.errorOutput,
            exitCode: result.exitCode,
            duration: result.duration
        )
    }

    // MARK: - Test Execution

    func runTests(in directory: URL, config: ProjectConfiguration) async throws -> TestResult {
        let command = config.testCommand ?? defaultTestCommand(for: config.projectType)
        guard let command = command else {
            throw BuildTestServiceError.noTestCommand
        }

        let result = try await runCommand(command, in: directory)
        return TestResult(
            success: result.exitCode == 0,
            output: result.output,
            errorOutput: result.errorOutput.isEmpty ? nil : result.errorOutput,
            exitCode: result.exitCode,
            duration: result.duration
        )
    }

    // MARK: - Private Helpers

    private func runCommand(_ command: String, in directory: URL) async throws -> (output: String, errorOutput: String, exitCode: Int32, duration: TimeInterval) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let startTime = Date()
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                process.currentDirectoryURL = directory
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    let duration = Date().timeIntervalSince(startTime)

                    continuation.resume(returning: (stdout, stderr, process.terminationStatus, duration))
                } catch {
                    continuation.resume(throwing: BuildTestServiceError.processCreationFailed(error))
                }
            }
        }
    }
}
