import XCTest

@MainActor
final class ClaudeManagerUITests: ClaudeManagerUITestCase {
    func testAppLaunches() throws {
        launch(scenario: .idle)
        XCTAssertTrue(app.windows.count > 0)
    }
}
