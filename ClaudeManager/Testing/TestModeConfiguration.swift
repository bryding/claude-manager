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
    static let shared = TestModeConfiguration()

    let isUITesting: Bool
    let scenario: TestScenario?

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        self.isUITesting = arguments.contains("--uitesting")

        if isUITesting,
           let scenarioString = ProcessInfo.processInfo.environment["TEST_SCENARIO"],
           let scenario = TestScenario(rawValue: scenarioString) {
            self.scenario = scenario
        } else {
            self.scenario = nil
        }
    }
}
