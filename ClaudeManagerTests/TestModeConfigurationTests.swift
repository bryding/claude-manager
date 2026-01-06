import XCTest
@testable import ClaudeManager

final class TestModeConfigurationTests: XCTestCase {
    // MARK: - isUITesting Detection

    func testIsUITestingTrueWhenArgumentPresent() {
        let config = TestModeConfiguration(
            arguments: ["app", "--uitesting"],
            environment: [:]
        )

        XCTAssertTrue(config.isUITesting)
    }

    func testIsUITestingFalseWhenArgumentMissing() {
        let config = TestModeConfiguration(
            arguments: ["app", "--other-flag"],
            environment: [:]
        )

        XCTAssertFalse(config.isUITesting)
    }

    func testIsUITestingFalseWithEmptyArguments() {
        let config = TestModeConfiguration(
            arguments: [],
            environment: [:]
        )

        XCTAssertFalse(config.isUITesting)
    }

    func testIsUITestingDetectsArgumentAnywhere() {
        let config = TestModeConfiguration(
            arguments: ["app", "--verbose", "--uitesting", "--debug"],
            environment: [:]
        )

        XCTAssertTrue(config.isUITesting)
    }

    // MARK: - Scenario Parsing

    func testScenarioParsedWhenUITestingAndValidScenario() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "idle"]
        )

        XCTAssertEqual(config.scenario, .idle)
    }

    func testScenarioNilWhenUITestingButNoScenarioEnv() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: [:]
        )

        XCTAssertNil(config.scenario)
    }

    func testScenarioNilWhenUITestingButInvalidScenario() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "invalidScenario"]
        )

        XCTAssertNil(config.scenario)
    }

    func testScenarioNilWhenNotUITestingEvenWithValidScenario() {
        let config = TestModeConfiguration(
            arguments: ["app"],
            environment: ["TEST_SCENARIO": "idle"]
        )

        XCTAssertNil(config.scenario)
    }

    func testScenarioNilWhenUITestingAndEmptyScenarioString() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": ""]
        )

        XCTAssertNil(config.scenario)
    }

    // MARK: - All Scenario Values

    func testAllScenariosParsedCorrectly() {
        for scenario in TestScenario.allCases {
            let config = TestModeConfiguration(
                arguments: ["--uitesting"],
                environment: ["TEST_SCENARIO": scenario.rawValue]
            )

            XCTAssertEqual(config.scenario, scenario, "Failed to parse scenario: \(scenario.rawValue)")
        }
    }

    func testSetupWithProjectScenarioParsed() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "setupWithProject"]
        )

        XCTAssertEqual(config.scenario, .setupWithProject)
    }

    func testExecutingTaskScenarioParsed() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "executingTask"]
        )

        XCTAssertEqual(config.scenario, .executingTask)
    }

    func testWaitingForUserQuestionScenarioParsed() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "waitingForUserQuestion"]
        )

        XCTAssertEqual(config.scenario, .waitingForUserQuestion)
    }

    func testCompletedScenarioParsed() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "completed"]
        )

        XCTAssertEqual(config.scenario, .completed)
    }

    func testFailedScenarioParsed() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "failed"]
        )

        XCTAssertEqual(config.scenario, .failed)
    }

    // MARK: - Case Sensitivity

    func testScenarioIsCaseSensitive() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: ["TEST_SCENARIO": "Idle"]
        )

        XCTAssertNil(config.scenario)
    }

    func testUITestingArgumentIsCaseSensitive() {
        let config = TestModeConfiguration(
            arguments: ["--UITESTING"],
            environment: ["TEST_SCENARIO": "idle"]
        )

        XCTAssertFalse(config.isUITesting)
        XCTAssertNil(config.scenario)
    }

    // MARK: - Environment Key

    func testScenarioIgnoresOtherEnvVariables() {
        let config = TestModeConfiguration(
            arguments: ["--uitesting"],
            environment: [
                "OTHER_SCENARIO": "idle",
                "SCENARIO": "completed",
            ]
        )

        XCTAssertNil(config.scenario)
    }
}
