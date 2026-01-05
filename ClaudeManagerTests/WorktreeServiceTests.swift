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
        let customPath = "/opt/local/bin/git"
        let service = WorktreeService(gitPath: customPath)

        XCTAssertNotNil(service)
    }

    // MARK: - Integration Tests (require actual git repo)

    func testCreateWorktreeFailsForNonGitRepository() async {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            do {
                _ = try await service.createWorktree(from: tempDir)
                XCTFail("Expected error for non-git repository")
            } catch let error as WorktreeServiceError {
                if case .commandFailed(let code, let stderr) = error {
                    XCTAssertNotEqual(code, 0)
                    XCTAssertTrue(stderr?.contains("not a git repository") == true || stderr != nil)
                } else {
                    XCTFail("Expected commandFailed error")
                }
            }
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }
    }

    func testRemoveWorktreeFailsForNonGitRepository() async {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

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
                if case .commandFailed = error {
                    // Expected error
                } else {
                    XCTFail("Expected commandFailed error")
                }
            }
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }
    }

    func testListWorktreesFailsForNonGitRepository() async {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            do {
                _ = try await service.listWorktrees(in: tempDir)
                XCTFail("Expected error for non-git repository")
            } catch let error as WorktreeServiceError {
                if case .commandFailed = error {
                    // Expected error
                } else {
                    XCTFail("Expected commandFailed error")
                }
            }
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }
    }

    func testListWorktreesReturnsEmptyForRepoWithNoWorktrees() async throws {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = tempDir
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw XCTSkip("Git init failed")
        }

        let worktrees = try await service.listWorktrees(in: tempDir)

        XCTAssertTrue(worktrees.isEmpty)
    }

    func testCreateAndListWorktreeRoundtrip() async throws {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

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

    func testCreateAndRemoveWorktree() async throws {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktreeInfo = try await service.createWorktree(from: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreeInfo.worktreePath.path))

        try await service.removeWorktree(worktreeInfo)

        XCTAssertFalse(FileManager.default.fileExists(atPath: worktreeInfo.worktreePath.path))
    }

    func testCreateMultipleWorktrees() async throws {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

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
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktreeInfo = try await service.createWorktree(from: tempDir)

        XCTAssertTrue(worktreeInfo.branchName.hasPrefix("claude-worktree-"))
        XCTAssertEqual(worktreeInfo.branchName, "claude-worktree-\(worktreeInfo.id.uuidString)")
    }

    func testWorktreePathIsWithinWorktreesDirectory() async throws {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try initializeGitRepo(at: tempDir)

        let worktreeInfo = try await service.createWorktree(from: tempDir)

        let expectedWorktreesDir = tempDir.appendingPathComponent(".worktrees")
        XCTAssertTrue(worktreeInfo.worktreePath.path.hasPrefix(expectedWorktreesDir.path))
    }

    func testListWorktreesOnlyReturnsClaudeWorktrees() async throws {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try initializeGitRepo(at: tempDir)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "add", "-b", "manual-branch", "../manual-worktree"]
        process.currentDirectoryURL = tempDir
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let claudeWorktree = try await service.createWorktree(from: tempDir)

        let worktrees = try await service.listWorktrees(in: tempDir)

        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(worktrees.first?.id, claudeWorktree.id)
    }

    func testRemoveNonexistentWorktreeFails() async throws {
        let service = WorktreeService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

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
            if case .commandFailed = error {
                // Expected
            } else {
                XCTFail("Expected commandFailed error")
            }
        }
    }

    func testInvalidGitPathFails() async {
        let service = WorktreeService(gitPath: "/nonexistent/git")
        let tempDir = FileManager.default.temporaryDirectory

        do {
            _ = try await service.listWorktrees(in: tempDir)
            XCTFail("Expected error for invalid git path")
        } catch let error as WorktreeServiceError {
            if case .commandFailed(let code, _) = error {
                XCTAssertEqual(code, -1)
            } else {
                XCTFail("Expected commandFailed error with code -1")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func initializeGitRepo(at path: URL) throws {
        let gitInit = Process()
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        gitInit.currentDirectoryURL = path
        gitInit.standardOutput = FileHandle.nullDevice
        gitInit.standardError = FileHandle.nullDevice
        try gitInit.run()
        gitInit.waitUntilExit()

        guard gitInit.terminationStatus == 0 else {
            throw XCTSkip("Git init failed")
        }

        let gitConfig1 = Process()
        gitConfig1.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfig1.arguments = ["config", "user.email", "test@test.com"]
        gitConfig1.currentDirectoryURL = path
        gitConfig1.standardOutput = FileHandle.nullDevice
        gitConfig1.standardError = FileHandle.nullDevice
        try gitConfig1.run()
        gitConfig1.waitUntilExit()

        let gitConfig2 = Process()
        gitConfig2.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfig2.arguments = ["config", "user.name", "Test"]
        gitConfig2.currentDirectoryURL = path
        gitConfig2.standardOutput = FileHandle.nullDevice
        gitConfig2.standardError = FileHandle.nullDevice
        try gitConfig2.run()
        gitConfig2.waitUntilExit()

        let readmeURL = path.appendingPathComponent("README.md")
        try "# Test".write(to: readmeURL, atomically: true, encoding: .utf8)

        let gitAdd = Process()
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        gitAdd.currentDirectoryURL = path
        gitAdd.standardOutput = FileHandle.nullDevice
        gitAdd.standardError = FileHandle.nullDevice
        try gitAdd.run()
        gitAdd.waitUntilExit()

        let gitCommit = Process()
        gitCommit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitCommit.arguments = ["commit", "-m", "Initial commit"]
        gitCommit.currentDirectoryURL = path
        gitCommit.standardOutput = FileHandle.nullDevice
        gitCommit.standardError = FileHandle.nullDevice
        try gitCommit.run()
        gitCommit.waitUntilExit()

        guard gitCommit.terminationStatus == 0 else {
            throw XCTSkip("Git commit failed")
        }
    }
}
