import Foundation

struct ContinuationSummary: Sendable, Equatable {
    let taskNumber: Int
    let taskTitle: String
    let progressDescription: String
    let filesModified: [String]
    let pendingWork: String
    let generatedAt: Date

    init(
        taskNumber: Int,
        taskTitle: String,
        progressDescription: String,
        filesModified: [String] = [],
        pendingWork: String,
        generatedAt: Date = Date()
    ) {
        self.taskNumber = taskNumber
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
            Task: \(taskNumber) - \(taskTitle)

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
