import Foundation

// MARK: - Plan Service Error

enum PlanServiceError: Error {
    case fileReadFailed(URL, Error)
    case fileWriteFailed(URL, Error)
}

// MARK: - Plan Service

final class PlanService: Sendable {

    // Format 1: ## Task 1: Task Title
    private static let taskPattern = /\s*## Task (\d+): (.+)/
    private static let descriptionPattern = /\s*\*\*Description:\*\*\s*(.+)/
    private static let subtaskPattern = /\s*- \[[ xX]?\] (.+)/

    // Format 2: - [x] **Task 1.1**: Task description (checkbox-style)
    private static let checkboxTaskPattern = /\s*- \[([xX ])\] \*\*Task ([\d.]+)\*\*:\s*(.+)/

    // Format 3: - [x] ~~**Task 2.1**: Task description~~ - SKIPPED
    private static let skippedTaskPattern = /\s*- \[[xX]\] ~~\*\*Task ([\d.]+)\*\*:\s*(.+)~~ - SKIPPED/

    func parsePlanFromFile(at url: URL) throws -> Plan {
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw PlanServiceError.fileReadFailed(url, error)
        }
        return parsePlanFromText(text)
    }

    func parsePlanFromText(_ text: String) -> Plan {
        var tasks: [PlanTask] = []
        let lines = text.components(separatedBy: .newlines)
        var currentTaskNumber: Int?
        var currentTaskId: String?
        var currentTitle: String?
        var currentDescription: String?
        var currentSubtasks: [String] = []
        var currentStatus: TaskStatus = .pending

        func saveCurrentTask() {
            if let number = currentTaskNumber, let title = currentTitle {
                let task = PlanTask(
                    number: number,
                    taskId: currentTaskId,
                    title: title,
                    description: currentDescription ?? "",
                    status: currentStatus,
                    subtasks: currentSubtasks
                )
                tasks.append(task)
            }
        }

        for line in lines {
            // Format 1: ## Task 1: Task Title
            if let match = line.wholeMatch(of: Self.taskPattern) {
                saveCurrentTask()

                let taskNumber = Int(match.1) ?? tasks.count + 1
                currentTaskNumber = taskNumber
                currentTaskId = String(taskNumber)
                currentTitle = String(match.2)
                currentDescription = nil
                currentSubtasks = []
                currentStatus = .pending
            }
            // Format 3: - [x] ~~**Task 2.1**: ...~~ - SKIPPED (check before format 2)
            else if let match = line.wholeMatch(of: Self.skippedTaskPattern) {
                saveCurrentTask()

                let taskId = String(match.1)
                let description = String(match.2)
                let taskNumber = Int(taskId.split(separator: ".").first ?? "") ?? tasks.count + 1

                currentTaskNumber = taskNumber
                currentTaskId = taskId
                currentTitle = description
                currentDescription = nil
                currentSubtasks = []
                currentStatus = .skipped
            }
            // Format 2: - [x] **Task 1.1**: Task description
            else if let match = line.wholeMatch(of: Self.checkboxTaskPattern) {
                saveCurrentTask()

                let checkbox = String(match.1)
                let taskId = String(match.2)
                let description = String(match.3)

                // Extract task number (use first part before decimal, or parse as-is)
                let taskNumber = Int(taskId.split(separator: ".").first ?? "") ?? tasks.count + 1

                currentTaskNumber = taskNumber
                currentTaskId = taskId
                currentTitle = description
                currentDescription = nil
                currentSubtasks = []
                currentStatus = (checkbox == "x" || checkbox == "X") ? .completed : .pending
            } else if let match = line.wholeMatch(of: Self.descriptionPattern) {
                currentDescription = String(match.1)
            } else if let match = line.wholeMatch(of: Self.subtaskPattern) {
                currentSubtasks.append(String(match.1))
            }
        }

        saveCurrentTask()

        return Plan(rawText: text, tasks: tasks)
    }

    func savePlan(_ plan: Plan, to url: URL) throws {
        do {
            try plan.rawText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw PlanServiceError.fileWriteFailed(url, error)
        }
    }
}
