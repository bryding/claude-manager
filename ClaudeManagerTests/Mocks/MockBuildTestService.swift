import Foundation
@testable import ClaudeManager

final class MockBuildTestService: BuildTestServiceProtocol, @unchecked Sendable {
    var detectedProjectType: ProjectType = .unknown
    var buildResult: BuildResult = CommandResult(success: true, output: "", errorOutput: nil, exitCode: 0, duration: 0.1)
    var testResult: TestResult = CommandResult(success: true, output: "", errorOutput: nil, exitCode: 0, duration: 0.1)
    var buildError: Error?
    var testError: Error?

    var detectProjectTypeCalled = false
    var runBuildCalled = false
    var runTestsCalled = false

    func detectProjectType(in directory: URL) -> ProjectType {
        detectProjectTypeCalled = true
        return detectedProjectType
    }

    func runBuild(in directory: URL, config: ProjectConfiguration) async throws -> BuildResult {
        runBuildCalled = true
        if let error = buildError {
            throw error
        }
        return buildResult
    }

    func runTests(in directory: URL, config: ProjectConfiguration) async throws -> TestResult {
        runTestsCalled = true
        if let error = testError {
            throw error
        }
        return testResult
    }
}
