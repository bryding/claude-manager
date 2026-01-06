import SwiftUI

struct TaskListView: View {
    let tasks: [PlanTask]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasks) { task in
                    TaskRowView(task: task)
                        .accessibilityIdentifier(AccessibilityIdentifiers.TaskListView.task(task.number))
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.TaskListView.taskListView)
    }
}

// MARK: - Task Row View

private struct TaskRowView: View {
    let task: PlanTask

    @State private var isPulsing = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon
                .frame(width: 20, height: 20)
                .accessibilityIdentifier(AccessibilityIdentifiers.TaskListView.taskStatus(task.number))

            VStack(alignment: .leading, spacing: 4) {
                Text("Task \(task.number): \(task.title)")
                    .font(.headline)

                if task.status == .inProgress && !task.description.isEmpty {
                    Text(task.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(task.status == .completed || task.status == .skipped ? 0.6 : 1.0)
        .onAppear {
            isPulsing = task.status == .inProgress
        }
        .onChange(of: task.status) { _, newStatus in
            isPulsing = newStatus == .inProgress
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.gray)

        case .inProgress:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.blue)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(
                    isPulsing
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)

        case .skipped:
            Image(systemName: "circle.slash")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Task List") {
    TaskListView(tasks: [
        PlanTask(number: 1, title: "Create project structure", description: "Set up folders and files", status: .completed),
        PlanTask(number: 2, title: "Implement models", description: "Create data models for the app", status: .completed),
        PlanTask(number: 3, title: "Build services layer", description: "This is the current task being worked on with a longer description that might wrap to multiple lines.", status: .inProgress),
        PlanTask(number: 4, title: "Create state management", description: "Add app state", status: .pending),
        PlanTask(number: 5, title: "Build UI views", description: "Create SwiftUI views", status: .pending),
        PlanTask(number: 6, title: "Skipped task", description: "This was skipped", status: .skipped),
        PlanTask(number: 7, title: "Failed task", description: "This failed", status: .failed),
    ])
    .frame(width: 400, height: 500)
}
#endif
