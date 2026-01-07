import XCTest
@testable import ClaudeManager

final class PlanServiceTests: XCTestCase {

    private var service: PlanService!

    override func setUp() {
        super.setUp()
        service = PlanService()
    }

    // MARK: - Parse Empty/Minimal Input

    func testParseEmptyText() {
        let plan = service.parsePlanFromText("")

        XCTAssertEqual(plan.rawText, "")
        XCTAssertTrue(plan.tasks.isEmpty)
    }

    func testParseTextWithNoTasks() {
        let text = """
        # Project Plan

        Some introductory text here.
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.rawText, text)
        XCTAssertTrue(plan.tasks.isEmpty)
    }

    // MARK: - Parse Single Task

    func testParseSingleTask() {
        let text = """
        ## Task 1: Implement Feature

        **Description:** Build the new feature.

        - [ ] Create model
        - [ ] Add service
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks.count, 1)

        let task = plan.tasks[0]
        XCTAssertEqual(task.number, 1)
        XCTAssertEqual(task.title, "Implement Feature")
        XCTAssertEqual(task.description, "Build the new feature.")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.subtasks, ["Create model", "Add service"])
    }

    // MARK: - Parse Multiple Tasks

    func testParseMultipleTasks() {
        let text = """
        ## Task 1: First Task

        **Description:** Do first thing.

        - [ ] Step one

        ## Task 2: Second Task

        **Description:** Do second thing.

        - [ ] Step A
        - [ ] Step B
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks.count, 2)

        XCTAssertEqual(plan.tasks[0].number, 1)
        XCTAssertEqual(plan.tasks[0].title, "First Task")
        XCTAssertEqual(plan.tasks[0].subtasks.count, 1)

        XCTAssertEqual(plan.tasks[1].number, 2)
        XCTAssertEqual(plan.tasks[1].title, "Second Task")
        XCTAssertEqual(plan.tasks[1].subtasks.count, 2)
    }

    // MARK: - Parse Checkbox Variations

    func testParseCheckedSubtasks() {
        let text = """
        ## Task 1: Test

        - [x] Completed item
        - [X] Also completed
        - [ ] Not completed
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks[0].subtasks.count, 3)
        XCTAssertEqual(plan.tasks[0].subtasks[0], "Completed item")
        XCTAssertEqual(plan.tasks[0].subtasks[1], "Also completed")
        XCTAssertEqual(plan.tasks[0].subtasks[2], "Not completed")
    }

    // MARK: - Parse Task Without Optional Fields

    func testParseTaskWithoutDescription() {
        let text = """
        ## Task 1: No Description Task

        - [ ] Just subtasks
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks[0].description, "")
        XCTAssertEqual(plan.tasks[0].subtasks.count, 1)
    }

    func testParseTaskWithoutSubtasks() {
        let text = """
        ## Task 1: No Subtasks

        **Description:** Just a description.
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks[0].description, "Just a description.")
        XCTAssertTrue(plan.tasks[0].subtasks.isEmpty)
    }

    // MARK: - Raw Text Preservation

    func testRawTextPreserved() {
        let text = """
        # Header

        ## Task 1: Test

        Extra content here.
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.rawText, text)
    }

    // MARK: - Checkbox Task Format (Alternative Format)

    func testParseCheckboxTaskFormat() {
        let text = """
        - [ ] **Task 1.1**: Implement the feature
        - [x] **Task 1.2**: Complete the setup
        - [ ] **Task 2.1**: Another pending task
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks.count, 3)

        XCTAssertEqual(plan.tasks[0].number, 1)
        XCTAssertEqual(plan.tasks[0].title, "Implement the feature")
        XCTAssertEqual(plan.tasks[0].status, .pending)

        XCTAssertEqual(plan.tasks[1].number, 1)
        XCTAssertEqual(plan.tasks[1].title, "Complete the setup")
        XCTAssertEqual(plan.tasks[1].status, .completed)

        XCTAssertEqual(plan.tasks[2].number, 2)
        XCTAssertEqual(plan.tasks[2].title, "Another pending task")
        XCTAssertEqual(plan.tasks[2].status, .pending)
    }

    func testParseSkippedTaskFormat() {
        let text = """
        - [x] ~~**Task 2.1**: Migration utility~~ - SKIPPED
        - [ ] **Task 3.1**: Next task
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks.count, 2)

        XCTAssertEqual(plan.tasks[0].number, 2)
        XCTAssertEqual(plan.tasks[0].title, "Migration utility")
        XCTAssertEqual(plan.tasks[0].status, .skipped)

        XCTAssertEqual(plan.tasks[1].number, 3)
        XCTAssertEqual(plan.tasks[1].status, .pending)
    }

    func testParseCheckboxTaskWithZeroPrefix() {
        // Test format from real-world plan.md with task numbers starting at 0
        let text = """
        - [x] **Task 0.1**: Initialize Vue 3 + Vite + TypeScript Project

        **Description:** Create project foundation with folder structure.

        - [x] Create new Vite project with Vue 3 + TypeScript template
        - [x] Configure TypeScript with strict mode

        - [ ] **Task 0.2**: Configure Linting & Formatting

        **Description:** Set up ESLint, Prettier, and EditorConfig.

        - [ ] Install ESLint with Vue plugin
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks.count, 2)

        XCTAssertEqual(plan.tasks[0].number, 0)
        XCTAssertEqual(plan.tasks[0].title, "Initialize Vue 3 + Vite + TypeScript Project")
        XCTAssertEqual(plan.tasks[0].status, .completed)
        XCTAssertEqual(plan.tasks[0].description, "Create project foundation with folder structure.")
        XCTAssertEqual(plan.tasks[0].subtasks.count, 2)

        XCTAssertEqual(plan.tasks[1].number, 0)
        XCTAssertEqual(plan.tasks[1].title, "Configure Linting & Formatting")
        XCTAssertEqual(plan.tasks[1].status, .pending)
        XCTAssertEqual(plan.tasks[1].description, "Set up ESLint, Prettier, and EditorConfig.")
        XCTAssertEqual(plan.tasks[1].subtasks.count, 1)
    }

    func testParseMixedFormats() {
        let text = """
        ## Task 1: Standard format task

        **Description:** Using the standard format.

        - [ ] Subtask one

        - [x] **Task 2.1**: Checkbox format completed
        - [ ] **Task 2.2**: Checkbox format pending
        """

        let plan = service.parsePlanFromText(text)

        XCTAssertEqual(plan.tasks.count, 3)

        XCTAssertEqual(plan.tasks[0].number, 1)
        XCTAssertEqual(plan.tasks[0].title, "Standard format task")
        XCTAssertEqual(plan.tasks[0].status, .pending)
        XCTAssertEqual(plan.tasks[0].subtasks.count, 1)

        XCTAssertEqual(plan.tasks[1].number, 2)
        XCTAssertEqual(plan.tasks[1].title, "Checkbox format completed")
        XCTAssertEqual(plan.tasks[1].status, .completed)

        XCTAssertEqual(plan.tasks[2].number, 2)
        XCTAssertEqual(plan.tasks[2].title, "Checkbox format pending")
        XCTAssertEqual(plan.tasks[2].status, .pending)
    }

    // MARK: - File Operations

    func testParsePlanFromNonexistentFile() {
        let url = URL(fileURLWithPath: "/nonexistent/path/plan.md")

        XCTAssertThrowsError(try service.parsePlanFromFile(at: url)) { error in
            guard case PlanServiceError.fileReadFailed(let failedUrl, _) = error else {
                XCTFail("Expected fileReadFailed error")
                return
            }
            XCTAssertEqual(failedUrl, url)
        }
    }

    func testSavePlanToInvalidPath() {
        let plan = Plan(rawText: "test", tasks: [])
        let url = URL(fileURLWithPath: "/nonexistent/directory/plan.md")

        XCTAssertThrowsError(try service.savePlan(plan, to: url)) { error in
            guard case PlanServiceError.fileWriteFailed(let failedUrl, _) = error else {
                XCTFail("Expected fileWriteFailed error")
                return
            }
            XCTAssertEqual(failedUrl, url)
        }
    }

    func testRoundTripFileOperations() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("test-plan-\(UUID().uuidString).md")

        defer {
            try? FileManager.default.removeItem(at: fileUrl)
        }

        let originalText = """
        ## Task 1: Test Task

        **Description:** A test.

        - [ ] Item one
        """

        let originalPlan = Plan(rawText: originalText, tasks: [])

        try service.savePlan(originalPlan, to: fileUrl)
        let loadedPlan = try service.parsePlanFromFile(at: fileUrl)

        XCTAssertEqual(loadedPlan.rawText, originalText)
        XCTAssertEqual(loadedPlan.tasks.count, 1)
        XCTAssertEqual(loadedPlan.tasks[0].title, "Test Task")
    }
}
