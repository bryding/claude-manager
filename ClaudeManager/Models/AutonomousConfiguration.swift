import Foundation

enum CommandExecutionMode: String, Sendable, Equatable, Codable, CaseIterable {
    case manual
    case autonomous
    case alwaysAutonomous

    var displayName: String {
        switch self {
        case .manual:
            return "Manual"
        case .autonomous:
            return "Autonomous"
        case .alwaysAutonomous:
            return "Always Auto"
        }
    }

    var helpText: String {
        switch self {
        case .manual:
            return "Claude will ask for approval before running shell commands"
        case .autonomous:
            return "Commands run automatically. Falls back to manual on failures or timeouts"
        case .alwaysAutonomous:
            return "Commands always run automatically. Use with caution"
        }
    }
}

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
    var commandExecutionMode: CommandExecutionMode
    var commandTimeout: TimeInterval
    var fallbackOnTimeout: Bool
    var fallbackOnCommandFailure: Bool
    var consecutiveFailuresBeforeFallback: Int

    init(
        autoAnswerEnabled: Bool = false,
        autoFailureHandling: AutoFailureHandling = .pauseForUser,
        maxTaskRetries: Int = 3,
        runBuildAfterCommit: Bool = false,
        runTestsAfterCommit: Bool = false,
        projectContext: String = "",
        maxTestDuration: TimeInterval = 30.0,
        commandExecutionMode: CommandExecutionMode = .manual,
        commandTimeout: TimeInterval = 300.0,
        fallbackOnTimeout: Bool = true,
        fallbackOnCommandFailure: Bool = true,
        consecutiveFailuresBeforeFallback: Int = 2
    ) {
        self.autoAnswerEnabled = autoAnswerEnabled
        self.autoFailureHandling = autoFailureHandling
        self.maxTaskRetries = maxTaskRetries
        self.runBuildAfterCommit = runBuildAfterCommit
        self.runTestsAfterCommit = runTestsAfterCommit
        self.projectContext = projectContext
        self.maxTestDuration = maxTestDuration
        self.commandExecutionMode = commandExecutionMode
        self.commandTimeout = commandTimeout
        self.fallbackOnTimeout = fallbackOnTimeout
        self.fallbackOnCommandFailure = fallbackOnCommandFailure
        self.consecutiveFailuresBeforeFallback = consecutiveFailuresBeforeFallback
    }

    static let `default` = AutonomousConfiguration()
}
