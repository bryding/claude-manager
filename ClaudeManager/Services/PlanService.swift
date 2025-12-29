import Foundation

// MARK: - Plan Service Error

enum PlanServiceError: Error {
    case fileReadFailed(URL, Error)
    case fileWriteFailed(URL, Error)
}

// MARK: - Plan Service

final class PlanService: Sendable {

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

        let taskPattern = /## Task (\d+): (.+)/
        let descriptionPattern = /\*\*Description:\*\*\s*(.+)/
        let subtaskPattern = /- \[[ xX]?\] (.+)/

        let lines = text.components(separatedBy: .newlines)
        var currentTaskNumber: Int?
        var currentTitle: String?
        var currentDescription: String?
        var currentSubtasks: [String] = []

        func saveCurrentTask() {
            if let number = currentTaskNumber, let title = currentTitle {
                let task = PlanTask(
                    number: number,
                    title: title,
                    description: currentDescription ?? "",
                    status: .pending,
                    subtasks: currentSubtasks
                )
                tasks.append(task)
            }
        }

        for line in lines {
            if let match = line.wholeMatch(of: taskPattern) {
                saveCurrentTask()

                currentTaskNumber = Int(match.1)
                currentTitle = String(match.2)
                currentDescription = nil
                currentSubtasks = []
            } else if let match = line.wholeMatch(of: descriptionPattern) {
                currentDescription = String(match.1)
            } else if let match = line.wholeMatch(of: subtaskPattern) {
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
