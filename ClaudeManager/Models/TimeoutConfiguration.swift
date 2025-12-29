import Foundation

struct TimeoutConfiguration: Sendable {
    let planModeTimeout: TimeInterval
    let executionTimeout: TimeInterval
    let commitTimeout: TimeInterval

    static let `default` = TimeoutConfiguration(
        planModeTimeout: 300,
        executionTimeout: 900,
        commitTimeout: 60
    )
}
