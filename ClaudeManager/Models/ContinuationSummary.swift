import Foundation

struct ContinuationSummary: Sendable, Equatable {
    let taskId: String
    let taskTitle: String
    let progressDescription: String
    let filesModified: [String]
    let pendingWork: String
    let generatedAt: Date

    init(
        taskId: String,
        taskTitle: String,
        progressDescription: String,
        filesModified: [String] = [],
        pendingWork: String,
        generatedAt: Date = Date()
    ) {
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.progressDescription = progressDescription
        self.filesModified = filesModified
        self.pendingWork = pendingWork
        self.generatedAt = generatedAt
    }

    var promptContext: String {
        let filesSection = filesModified.isEmpty
            ? "None yet"
            : filesModified.map { "- \($0)" }.joined(separator: "\n")

        return """
            [CONTINUATION FROM PREVIOUS SESSION]
            Task: \(taskId) - \(taskTitle)

            Previous Progress:
            \(progressDescription)

            Files Modified:
            \(filesSection)

            Remaining Work:
            \(pendingWork)

            Continue from where the previous session left off.
            [END CONTINUATION CONTEXT]

            """
    }
}
