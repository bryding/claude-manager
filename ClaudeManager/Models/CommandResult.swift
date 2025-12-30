import Foundation

// MARK: - Command Result

struct CommandResult: Sendable, Equatable {
    let success: Bool
    let output: String
    let errorOutput: String?
    let exitCode: Int32
    let duration: TimeInterval
}

typealias BuildResult = CommandResult
typealias TestResult = CommandResult
