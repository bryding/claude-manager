import Foundation

struct TimeoutConfiguration: Sendable {
    let planModeTimeout: TimeInterval
    let executionTimeout: TimeInterval

    static let `default` = TimeoutConfiguration(
        planModeTimeout: 300,
        executionTimeout: 900
    )
}
