import SwiftUI

struct ExecutionView: View {
    // MARK: - Environment

    @Environment(AppState.self) private var appState

    // MARK: - Computed Properties

    private var context: ExecutionContext {
        appState.context
    }

    // MARK: - Body

    var body: some View {
        HSplitView {
            leftPane
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            LogView(logs: context.logs)
        }
    }

    // MARK: - View Sections

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            projectHeader

            PhaseIndicatorView(phase: context.phase)

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
            }

            ProgressView(value: context.progress)
                .progressViewStyle(.linear)
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
                Text(context.projectPath?.lastPathComponent ?? "No Project")
                    .font(.headline)
            }

            Spacer()

            Button("Change Project") {
                appState.context.reset()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(context.isRunning)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Execution - Running") {
    let appState = AppState()
    appState.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")
    appState.context.phase = .executingTask
    appState.context.plan = Plan(rawText: "", tasks: [
        PlanTask(number: 1, title: "Create project structure", description: "Set up folders", status: .completed),
        PlanTask(number: 2, title: "Implement models", description: "Create data models", status: .completed),
        PlanTask(number: 3, title: "Build services layer", description: "Implementing service layer", status: .inProgress),
        PlanTask(number: 4, title: "Create state management", description: "Add app state", status: .pending),
        PlanTask(number: 5, title: "Build UI views", description: "Create SwiftUI views", status: .pending),
    ])
    appState.context.currentTaskIndex = 2
    appState.context.totalCost = 0.42
    appState.context.logs = [
        LogEntry(phase: .executingTask, type: .info, message: "Starting task execution..."),
        LogEntry(phase: .executingTask, type: .output, message: "Reading file: /src/main.swift"),
        LogEntry(phase: .executingTask, type: .toolUse, message: "Read: ClaudeManager/Models/Plan.swift"),
        LogEntry(phase: .executingTask, type: .output, message: "Analyzing code structure"),
    ]
    return ExecutionView()
        .environment(appState)
        .frame(width: 1000, height: 600)
}

#Preview("Execution - Completed") {
    let appState = AppState()
    appState.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")
    appState.context.phase = .completed
    appState.context.plan = Plan(rawText: "", tasks: [
        PlanTask(number: 1, title: "Create project structure", description: "Set up folders", status: .completed),
        PlanTask(number: 2, title: "Implement models", description: "Create data models", status: .completed),
        PlanTask(number: 3, title: "Build services layer", description: "Build services", status: .completed),
    ])
    appState.context.currentTaskIndex = 2
    appState.context.totalCost = 1.85
    appState.context.logs = [
        LogEntry(phase: .completed, type: .result, message: "All tasks completed successfully"),
    ]
    return ExecutionView()
        .environment(appState)
        .frame(width: 1000, height: 600)
}

#Preview("Execution - Waiting for User") {
    let appState = AppState()
    appState.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")
    appState.context.phase = .waitingForUser
    appState.context.plan = Plan(rawText: "", tasks: [
        PlanTask(number: 1, title: "Implement feature", description: "Building feature", status: .inProgress),
    ])
    appState.context.currentTaskIndex = 0
    appState.context.totalCost = 0.15
    appState.context.logs = [
        LogEntry(phase: .waitingForUser, type: .info, message: "Waiting for user input..."),
    ]
    return ExecutionView()
        .environment(appState)
        .frame(width: 1000, height: 600)
}
#endif
