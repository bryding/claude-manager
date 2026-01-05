import XCTest
@testable import ClaudeManager

final class WorktreeServiceTests: XCTestCase {
    // MARK: - WorktreeServiceError Tests

    func testCommandFailedErrorDescription() {
        let error = WorktreeServiceError.commandFailed(128, stderr: "fatal: not a git repository")

        XCTAssertEqual(
            error.errorDescription,
            "Git worktree command failed with exit code 128: fatal: not a git repository"
        )
    }

    func testCommandFailedErrorDescriptionWithoutStderr() {
        let error = WorktreeServiceError.commandFailed(1, stderr: nil)

        XCTAssertEqual(
            error.errorDescription,
            "Git worktree command failed with exit code 1"
        )
    }

    func testCommandFailedErrorDescriptionWithEmptyStderr() {
        let error = WorktreeServiceError.commandFailed(1, stderr: "")

        XCTAssertEqual(
            error.errorDescription,
            "Git worktree command failed with exit code 1: "
        )
    }

    func testDirectoryCreationFailedErrorDescription() {
        let error = WorktreeServiceError.directoryCreationFailed(path: "/test/path/.worktrees")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to create directory: /test/path/.worktrees"
        )
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let service = WorktreeService()

        XCTAssertNotNil(service)
    }

    func testCustomGitPathInitialization() {
        let service = WorktreeService(gitPath: "/opt/local/bin/git")

        XCTAssertNotNil(service)
    }

    // MARK: - Non-Git Repository Error Tests

    func testCreateWorktreeFailsForNonGitRepository() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        do {
            _ = try await service.createWorktree(from: tempDir)
            XCTFail("Expected error for non-git repository")
        } catch let error as WorktreeServiceError {
            guard case .commandFailed(let code, let stderr) = error else {
                XCTFail("Expected commandFailed error")
                return
            }
            XCTAssertNotEqual(code, 0)
            XCTAssertTrue(stderr?.contains("not a git repository") == true || stderr != nil)
        }
    }

    func testRemoveWorktreeFailsForNonGitRepository() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let worktreeInfo = WorktreeInfo(
            id: UUID(),
            originalRepoPath: tempDir,
            worktreePath: tempDir.appendingPathComponent(".worktrees/test"),
            branchName: "test-branch"
        )

        do {
            try await service.removeWorktree(worktreeInfo)
            XCTFail("Expected error for non-git repository")
        } catch let error as WorktreeServiceError {
            guard case .commandFailed = error else {
                XCTFail("Expected commandFailed error")
                return
            }
        }
    }

    func testListWorktreesFailsForNonGitRepository() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        do {
            _ = try await service.listWorktrees(in: tempDir)
            XCTFail("Expected error for non-git repository")
        } catch let error as WorktreeServiceError {
            guard case .commandFailed = error else {
                XCTFail("Expected commandFailed error")
                return
            }
        }
    }

    // MARK: - List Worktrees Tests

    func testListWorktreesReturnsEmptyForRepoWithNoWorktrees() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try runGitCommand(["init"], in: tempDir)

        let worktrees = try await service.listWorktrees(in: tempDir)

        XCTAssertTrue(worktrees.isEmpty)
    }

    func testListWorktreesOnlyReturnsClaudeWorktrees() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try initializeGitRepo(at: tempDir)

        try runGitCommand(["worktree", "add", "-b", "manual-branch", "../manual-worktree"], in: tempDir)

        let claudeWorktree = try await service.createWorktree(from: tempDir)

        let worktrees = try await service.listWorktrees(in: tempDir)

        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(worktrees.first?.id, claudeWorktree.id)
    }

    // MARK: - Create Worktree Tests

    func testCreateAndListWorktreeRoundtrip() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktreeInfo = try await service.createWorktree(from: tempDir)

        XCTAssertEqual(worktreeInfo.originalRepoPath, tempDir)
        XCTAssertTrue(worktreeInfo.branchName.hasPrefix("claude-worktree-"))
        XCTAssertTrue(worktreeInfo.worktreePath.path.contains(".worktrees"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreeInfo.worktreePath.path))

        let worktrees = try await service.listWorktrees(in: tempDir)

        let matchingWorktree = worktrees.first { $0.id == worktreeInfo.id }
        XCTAssertNotNil(matchingWorktree)
        XCTAssertEqual(matchingWorktree?.branchName, worktreeInfo.branchName)
    }

    func testCreateMultipleWorktrees() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktree1 = try await service.createWorktree(from: tempDir)
        let worktree2 = try await service.createWorktree(from: tempDir)

        XCTAssertNotEqual(worktree1.id, worktree2.id)
        XCTAssertNotEqual(worktree1.branchName, worktree2.branchName)
        XCTAssertNotEqual(worktree1.worktreePath, worktree2.worktreePath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: worktree1.worktreePath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktree2.worktreePath.path))

        let worktrees = try await service.listWorktrees(in: tempDir)
        XCTAssertEqual(worktrees.count, 2)
    }

    func testWorktreeInfoHasCorrectBranchNameFormat() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktreeInfo = try await service.createWorktree(from: tempDir)

        XCTAssertTrue(worktreeInfo.branchName.hasPrefix("claude-worktree-"))
        XCTAssertEqual(worktreeInfo.branchName, "claude-worktree-\(worktreeInfo.id.uuidString)")
    }

    func testWorktreePathIsWithinWorktreesDirectory() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktreeInfo = try await service.createWorktree(from: tempDir)

        let expectedWorktreesDir = tempDir.appendingPathComponent(".worktrees")
        XCTAssertTrue(worktreeInfo.worktreePath.path.hasPrefix(expectedWorktreesDir.path))
    }

    // MARK: - Remove Worktree Tests

    func testCreateAndRemoveWorktree() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktreeInfo = try await service.createWorktree(from: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreeInfo.worktreePath.path))

        try await service.removeWorktree(worktreeInfo)

        XCTAssertFalse(FileManager.default.fileExists(atPath: worktreeInfo.worktreePath.path))
    }

    func testRemoveNonexistentWorktreeFails() async throws {
        let service = WorktreeService()
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try initializeGitRepo(at: tempDir)

        let fakeWorktreeInfo = WorktreeInfo(
            id: UUID(),
            originalRepoPath: tempDir,
            worktreePath: tempDir.appendingPathComponent(".worktrees/nonexistent"),
            branchName: "fake-branch"
        )

        do {
            try await service.removeWorktree(fakeWorktreeInfo)
            XCTFail("Expected error for nonexistent worktree")
        } catch let error as WorktreeServiceError {
            guard case .commandFailed = error else {
                XCTFail("Expected commandFailed error")
                return
            }
        }
    }

    // MARK: - Invalid Configuration Tests

    func testInvalidGitPathFails() async {
        let service = WorktreeService(gitPath: "/nonexistent/git")
        let tempDir = FileManager.default.temporaryDirectory

        do {
            _ = try await service.listWorktrees(in: tempDir)
            XCTFail("Expected error for invalid git path")
        } catch let error as WorktreeServiceError {
            guard case .commandFailed(let code, _) = error else {
                XCTFail("Expected commandFailed error with code -1")
                return
            }
            XCTAssertEqual(code, -1)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func runGitCommand(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw XCTSkip("Git command failed: \(arguments.joined(separator: " "))")
        }
    }

    private func initializeGitRepo(at path: URL) throws {
        try runGitCommand(["init"], in: path)
        try runGitCommand(["config", "user.email", "test@test.com"], in: path)
        try runGitCommand(["config", "user.name", "Test"], in: path)

        let readmeURL = path.appendingPathComponent("README.md")
        try "# Test".write(to: readmeURL, atomically: true, encoding: .utf8)

        try runGitCommand(["add", "."], in: path)
        try runGitCommand(["commit", "-m", "Initial commit"], in: path)
    }
}
