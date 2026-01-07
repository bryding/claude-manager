import Foundation

enum AutoFailureHandling: String, Sendable, Equatable, Codable, CaseIterable {
    case pauseForUser
    case retryThenSkip
    case retryThenStop

    var displayName: String {
        switch self {
        case .pauseForUser:
            return "Pause for User"
        case .retryThenSkip:
            return "Retry, then Skip"
        case .retryThenStop:
            return "Retry, then Stop"
        }
    }
}

struct AutonomousConfiguration: Sendable, Equatable, Codable {
    var autoAnswerEnabled: Bool
    var autoFailureHandling: AutoFailureHandling
    var maxTaskRetries: Int
    var runBuildAfterCommit: Bool
    var runTestsAfterCommit: Bool
    var projectContext: String
    var maxTestDuration: TimeInterval

    init(
        autoAnswerEnabled: Bool = false,
        autoFailureHandling: AutoFailureHandling = .pauseForUser,
        maxTaskRetries: Int = 3,
        runBuildAfterCommit: Bool = false,
        runTestsAfterCommit: Bool = false,
        projectContext: String = "",
        maxTestDuration: TimeInterval = 30.0
    ) {
        self.autoAnswerEnabled = autoAnswerEnabled
        self.autoFailureHandling = autoFailureHandling
        self.maxTaskRetries = maxTaskRetries
        self.runBuildAfterCommit = runBuildAfterCommit
        self.runTestsAfterCommit = runTestsAfterCommit
        self.projectContext = projectContext
        self.maxTestDuration = maxTestDuration
    }

    static let `default` = AutonomousConfiguration()
}
