import Foundation

// MARK: - Execution Phase

enum ExecutionPhase: String, Sendable, Equatable {
    case idle
    case generatingInitialPlan
    case rewritingPlan
    case executingTask
    case committingImplementation
    case reviewingCode
    case committingReview
    case writingTests
    case committingTests
    case clearingContext
    case waitingForUser
    case paused
    case completed
    case failed
}

// MARK: - Computed Properties

extension ExecutionPhase {
    var permissionMode: String? {
        switch self {
        case .generatingInitialPlan, .rewritingPlan, .reviewingCode, .writingTests:
            return "plan"
        case .executingTask, .committingImplementation, .committingReview, .committingTests, .clearingContext:
            return "acceptEdits"
        case .idle, .waitingForUser, .paused, .completed, .failed:
            return nil
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }
}
