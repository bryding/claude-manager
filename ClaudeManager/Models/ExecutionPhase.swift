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
    case runningBuild
    case runningTests
    case fixingBuildErrors
    case fixingTestErrors
    case clearingContext
    case handlingContextExhaustion
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
        case .executingTask, .committingImplementation, .committingReview, .committingTests, .clearingContext, .handlingContextExhaustion, .fixingBuildErrors, .fixingTestErrors:
            return "acceptEdits"
        case .idle, .waitingForUser, .paused, .completed, .failed, .runningBuild, .runningTests:
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
        case .runningBuild:
            return 0.52
        case .fixingBuildErrors:
            return 0.54
        case .reviewingCode:
            return 0.6
        case .committingReview:
            return 0.7
        case .writingTests:
            return 0.8
        case .committingTests:
            return 0.85
        case .runningTests:
            return 0.88
        case .fixingTestErrors:
            return 0.90
        case .clearingContext:
            return 0.95
        case .handlingContextExhaustion:
            return 0.4
        case .completed:
            return 1.0
        }
    }

    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .generatingInitialPlan:
            return "Generating Plan"
        case .rewritingPlan:
            return "Rewriting Plan"
        case .executingTask:
            return "Executing Task"
        case .committingImplementation:
            return "Committing Implementation"
        case .reviewingCode:
            return "Reviewing Code"
        case .committingReview:
            return "Committing Review"
        case .writingTests:
            return "Writing Tests"
        case .committingTests:
            return "Committing Tests"
        case .runningBuild:
            return "Running Build"
        case .runningTests:
            return "Running Tests"
        case .fixingBuildErrors:
            return "Fixing Build Errors"
        case .fixingTestErrors:
            return "Fixing Test Errors"
        case .clearingContext:
            return "Clearing Context"
        case .handlingContextExhaustion:
            return "Handling Context Limit"
        case .waitingForUser:
            return "Waiting for User"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    var description: String {
        switch self {
        case .idle:
            return "Ready to start"
        case .generatingInitialPlan:
            return "Claude is analyzing your feature request"
        case .rewritingPlan:
            return "Converting plan to discrete tasks"
        case .executingTask:
            return "Implementing the current task"
        case .committingImplementation:
            return "Saving implementation changes to git"
        case .reviewingCode:
            return "Claude is reviewing the code"
        case .committingReview:
            return "Saving review fixes to git"
        case .writingTests:
            return "Creating tests for core logic"
        case .committingTests:
            return "Saving tests to git"
        case .runningBuild:
            return "Building the project to verify compilation"
        case .runningTests:
            return "Running tests to verify functionality"
        case .fixingBuildErrors:
            return "Claude is fixing compilation errors"
        case .fixingTestErrors:
            return "Claude is fixing failing tests"
        case .clearingContext:
            return "Preparing for the next task"
        case .handlingContextExhaustion:
            return "Saving progress and preparing continuation"
        case .waitingForUser:
            return "Claude needs your input"
        case .paused:
            return "Execution paused"
        case .completed:
            return "All tasks finished successfully"
        case .failed:
            return "Execution encountered an error"
        }
    }

}
