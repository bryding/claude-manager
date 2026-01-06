import Foundation

enum TestScenario: String, CaseIterable {
    case idle
    case setupWithProject
    case executingTask
    case waitingForUserQuestion
    case completed
    case failed
}

final class TestModeConfiguration {
    static let shared = TestModeConfiguration(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )

    let isUITesting: Bool
    let scenario: TestScenario?

    init(arguments: [String], environment: [String: String]) {
        self.isUITesting = arguments.contains("--uitesting")

        if isUITesting,
           let scenarioString = environment["TEST_SCENARIO"],
           let scenario = TestScenario(rawValue: scenarioString) {
            self.scenario = scenario
        } else {
            self.scenario = nil
        }
    }
}
