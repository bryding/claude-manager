import XCTest
@testable import ClaudeManager

final class ClaudeProcessTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitWithoutStdinData() {
        let process = ClaudeProcess(
            executablePath: "/bin/echo",
            arguments: ["hello"],
            workingDirectory: tempDirectory
        )

        XCTAssertEqual(process.executablePath, "/bin/echo")
        XCTAssertEqual(process.arguments, ["hello"])
        XCTAssertEqual(process.workingDirectory, tempDirectory)
        XCTAssertNil(process.timeout)
        XCTAssertNil(process.stdinData)
    }

    func testInitWithStdinData() {
        let stdinData = "test input".data(using: .utf8)!

        let process = ClaudeProcess(
            executablePath: "/bin/cat",
            arguments: [],
            workingDirectory: tempDirectory,
            stdinData: stdinData
        )

        XCTAssertEqual(process.stdinData, stdinData)
    }

    func testInitWithAllParameters() {
        let stdinData = Data([0x01, 0x02, 0x03])

        let process = ClaudeProcess(
            executablePath: "/usr/bin/env",
            arguments: ["cat"],
            workingDirectory: tempDirectory,
            timeout: 30.0,
            stdinData: stdinData
        )

        XCTAssertEqual(process.executablePath, "/usr/bin/env")
        XCTAssertEqual(process.arguments, ["cat"])
        XCTAssertEqual(process.workingDirectory, tempDirectory)
        XCTAssertEqual(process.timeout, 30.0)
        XCTAssertEqual(process.stdinData, stdinData)
    }

    func testInitWithEmptyStdinData() {
        let emptyData = Data()

        let process = ClaudeProcess(
            executablePath: "/bin/cat",
            arguments: [],
            workingDirectory: tempDirectory,
            stdinData: emptyData
        )

        XCTAssertEqual(process.stdinData, emptyData)
        XCTAssertTrue(process.stdinData!.isEmpty)
    }

    // MARK: - isRunning Tests

    func testIsRunningReturnsFalseBeforeRun() {
        let process = ClaudeProcess(
            executablePath: "/bin/echo",
            arguments: ["test"],
            workingDirectory: tempDirectory
        )

        XCTAssertFalse(process.isRunning)
    }

    // MARK: - ClaudeProcessError Tests

    func testNonZeroExitCodeErrorDescription() {
        let error = ClaudeProcessError.nonZeroExitCode(1, stderr: "Something went wrong")

        XCTAssertEqual(error.errorDescription, "Process exited with code 1: Something went wrong")
    }

    func testNonZeroExitCodeErrorDescriptionWithNilStderr() {
        let error = ClaudeProcessError.nonZeroExitCode(127, stderr: nil)

        XCTAssertEqual(error.errorDescription, "Process exited with code 127")
    }

    func testOutputReadErrorDescription() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test read error" }
        }
        let error = ClaudeProcessError.outputReadError(TestError())

        XCTAssertEqual(error.errorDescription, "Failed to read process output: Test read error")
    }

    func testTimedOutErrorDescription() {
        let error = ClaudeProcessError.timedOut

        XCTAssertEqual(error.errorDescription, "Process timed out")
    }

    func testInterruptedErrorDescription() {
        let error = ClaudeProcessError.interrupted

        XCTAssertEqual(error.errorDescription, "Process was interrupted")
    }

    // MARK: - isRetryable Tests

    func testTimedOutIsRetryable() {
        XCTAssertTrue(ClaudeProcessError.timedOut.isRetryable)
    }

    func testInterruptedIsRetryable() {
        XCTAssertTrue(ClaudeProcessError.interrupted.isRetryable)
    }

    func testExitCode1IsRetryable() {
        XCTAssertTrue(ClaudeProcessError.nonZeroExitCode(1, stderr: nil).isRetryable)
    }

    func testExitCode2IsNotRetryable() {
        XCTAssertFalse(ClaudeProcessError.nonZeroExitCode(2, stderr: nil).isRetryable)
    }

    func testOutputReadErrorIsNotRetryable() {
        struct TestError: Error {}
        XCTAssertFalse(ClaudeProcessError.outputReadError(TestError()).isRetryable)
    }
}
