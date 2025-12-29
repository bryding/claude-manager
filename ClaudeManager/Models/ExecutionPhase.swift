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

    var progressWeight: Double {
        switch self {
        case .idle, .paused, .failed:
            return 0.0
        case .generatingInitialPlan:
            return 0.1
        case .rewritingPlan:
            return 0.2
        case .executingTask, .waitingForUser:
            return 0.3
        case .committingImplementation:
            return 0.5
        case .reviewingCode:
            return 0.6
        case .committingReview:
            return 0.7
        case .writingTests:
            return 0.8
        case .committingTests:
            return 0.85
        case .clearingContext:
            return 0.95
        case .completed:
            return 1.0
        }
    }
}
