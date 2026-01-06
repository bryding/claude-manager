import SwiftUI

struct ExecutionView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab

    // MARK: - Computed Properties

    private var context: ExecutionContext {
        tab.context
    }

    // MARK: - Body

    var body: some View {
        HSplitView {
            leftPane
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            LogView()
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.ExecutionView.executionView)
    }

    // MARK: - View Sections

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            projectHeader

            PhaseIndicatorView(
                phase: context.phase,
                hasQuestion: context.pendingQuestion != nil,
                isInterviewComplete: context.interviewSession?.isComplete ?? false
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.ExecutionView.phaseIndicator)

            progressSection

            Divider()

            TaskListView(tasks: context.plan?.tasks ?? [])

            Spacer()

            Divider()

            ControlsView()
        }
        .padding()
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(progressPercentage)
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                    .accessibilityIdentifier(AccessibilityIdentifiers.ExecutionView.progressPercentage)
            }

            ProgressView(value: context.progress)
                .progressViewStyle(.linear)
                .accessibilityIdentifier(AccessibilityIdentifiers.ExecutionView.progressBar)
        }
    }

    private var progressPercentage: String {
        let percentage = Int(context.progress * 100)
        return "\(percentage)%"
    }

    private var projectHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(tab.effectiveProjectPath?.lastPathComponent ?? "No Project")
                        .font(.headline)
                    if tab.worktreeInfo != nil {
                        worktreeBadge
                    }
                }
            }

            Spacer()

            if context.phase == .completed {
                Button("New Feature") {
                    context.resetForNewFeature()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button("Change Project") {
                context.reset()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(context.isRunning)
        }
    }

    private var worktreeBadge: some View {
        Text("Worktree")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Execution - Running") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")
    tab.context.phase = .executingTask
    tab.context.plan = Plan(rawText: "", tasks: [
        PlanTask(number: 1, title: "Create project structure", description: "Set up folders", status: .completed),
        PlanTask(number: 2, title: "Implement models", description: "Create data models", status: .completed),
        PlanTask(number: 3, title: "Build services layer", description: "Implementing service layer", status: .inProgress),
        PlanTask(number: 4, title: "Create state management", description: "Add app state", status: .pending),
        PlanTask(number: 5, title: "Build UI views", description: "Create SwiftUI views", status: .pending),
    ])
    tab.context.currentTaskIndex = 2
    tab.context.totalCost = 0.42
    tab.context.logs = [
        LogEntry(phase: .executingTask, type: .info, message: "Starting task execution..."),
        LogEntry(phase: .executingTask, type: .output, message: "Reading file: /src/main.swift"),
        LogEntry(phase: .executingTask, type: .toolUse, message: "Read: ClaudeManager/Models/Plan.swift"),
        LogEntry(phase: .executingTask, type: .output, message: "Analyzing code structure"),
    ]
    return ExecutionView()
        .environment(tab)
        .frame(width: 1000, height: 600)
}

#Preview("Execution - Completed") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")
    tab.context.phase = .completed
    tab.context.plan = Plan(rawText: "", tasks: [
        PlanTask(number: 1, title: "Create project structure", description: "Set up folders", status: .completed),
        PlanTask(number: 2, title: "Implement models", description: "Create data models", status: .completed),
        PlanTask(number: 3, title: "Build services layer", description: "Build services", status: .completed),
    ])
    tab.context.currentTaskIndex = 2
    tab.context.totalCost = 1.85
    tab.context.logs = [
        LogEntry(phase: .completed, type: .result, message: "All tasks completed successfully"),
    ]
    return ExecutionView()
        .environment(tab)
        .frame(width: 1000, height: 600)
}

#Preview("Execution - Waiting for User") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")
    tab.context.phase = .waitingForUser
    tab.context.plan = Plan(rawText: "", tasks: [
        PlanTask(number: 1, title: "Implement feature", description: "Building feature", status: .inProgress),
    ])
    tab.context.currentTaskIndex = 0
    tab.context.totalCost = 0.15
    tab.context.logs = [
        LogEntry(phase: .waitingForUser, type: .info, message: "Waiting for user input..."),
    ]
    return ExecutionView()
        .environment(tab)
        .frame(width: 1000, height: 600)
}

#Preview("Execution - Worktree") {
    let tab = Tab.create(
        userPreferences: UserPreferences(),
        worktreeInfo: WorktreeInfo(
            originalRepoPath: URL(fileURLWithPath: "/Users/demo/MyProject"),
            worktreePath: URL(fileURLWithPath: "/Users/demo/MyProject/.worktrees/abc123"),
            branchName: "claude-worktree-abc123"
        )
    )
    tab.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject/.worktrees/abc123")
    tab.context.phase = .executingTask
    tab.context.plan = Plan(rawText: "", tasks: [
        PlanTask(number: 1, title: "Implement feature", description: "Building feature", status: .inProgress),
    ])
    tab.context.currentTaskIndex = 0
    tab.context.totalCost = 0.25
    tab.context.logs = [
        LogEntry(phase: .executingTask, type: .info, message: "Working in worktree..."),
    ]
    return ExecutionView()
        .environment(tab)
        .frame(width: 1000, height: 600)
}
#endif
