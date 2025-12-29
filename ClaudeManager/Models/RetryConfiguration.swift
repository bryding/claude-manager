import Foundation

struct RetryConfiguration: Sendable, Equatable {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let backoffMultiplier: Double
    let maxDelay: TimeInterval

    init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
    }

    static let `default` = RetryConfiguration()

    func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
}
