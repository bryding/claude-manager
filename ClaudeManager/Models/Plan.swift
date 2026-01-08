import Foundation

// MARK: - Task Status

enum TaskStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
    case skipped
}

// MARK: - Plan Task

struct PlanTask: Identifiable, Equatable, Sendable {
    let id: UUID
    let number: Int
    let taskId: String
    let title: String
    let description: String
    var status: TaskStatus
    let subtasks: [String]

    init(
        id: UUID = UUID(),
        number: Int,
        taskId: String? = nil,
        title: String,
        description: String,
        status: TaskStatus = .pending,
        subtasks: [String] = []
    ) {
        self.id = id
        self.number = number
        self.taskId = taskId ?? String(number)
        self.title = title
        self.description = description
        self.status = status
        self.subtasks = subtasks
    }
}

// MARK: - Plan

struct Plan: Equatable, Sendable {
    let rawText: String
    var tasks: [PlanTask]

    init(rawText: String, tasks: [PlanTask] = []) {
        self.rawText = rawText
        self.tasks = tasks
    }
}
