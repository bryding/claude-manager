import XCTest

@MainActor
class ClaudeManagerUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func launch(scenario: TestScenario) {
        app.launchEnvironment["TEST_SCENARIO"] = scenario.rawValue
        app.launch()
    }

    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        element.waitForExistence(timeout: timeout)
    }
}
