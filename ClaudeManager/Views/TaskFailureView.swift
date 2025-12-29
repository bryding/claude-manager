import SwiftUI

struct TaskFailureView: View {
    let failure: PendingTaskFailure
    let onResponse: (TaskFailureResponse) -> Void

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
                    onResponse(.retry)
                }
                .buttonStyle(.borderedProminent)

                Button("Skip Task") {
                    onResponse(.skip)
                }
                .buttonStyle(.bordered)

                Button("Stop") {
                    onResponse(.stop)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(minWidth: 400)
    }
}
