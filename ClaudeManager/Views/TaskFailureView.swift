import SwiftUI

struct TaskFailureView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let failure: PendingTaskFailure

    // MARK: - Local State

    @State private var isSubmitting = false

    // MARK: - Computed Properties

    private var stateMachine: ExecutionStateMachine {
        tab.stateMachine
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.title2)
                Text("Task Failed")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Task \(failure.taskNumber): \(failure.taskTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(failure.error)
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button("Retry") {
                    handleResponse(.retry)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)

                Button("Skip Task") {
                    handleResponse(.skip)
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)

                Button("Stop") {
                    handleResponse(.stop)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .disabled(isSubmitting)
            }
        }
        .padding()
        .frame(minWidth: 400)
    }

    // MARK: - Actions

    private func handleResponse(_ response: TaskFailureResponse) {
        isSubmitting = true
        Task {
            await stateMachine.handleTaskFailureResponse(response)
            dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Task Failure") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)

    let failure = PendingTaskFailure(
        id: UUID(),
        taskNumber: 3,
        taskTitle: "Implement user authentication",
        error: "Build failed with 2 errors:\n- Missing import statement\n- Type 'AuthService' not found"
    )

    return TaskFailureView(failure: failure)
        .environment(tab)
}
#endif
