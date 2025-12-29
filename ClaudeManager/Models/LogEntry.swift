import Foundation
import SwiftUI

// MARK: - Log Type

enum LogType: String, Sendable {
    case output
    case toolUse
    case result
    case error
    case info
}

extension LogType {
    var color: Color {
        switch self {
        case .output:
            return .primary
        case .toolUse:
            return .blue
        case .result:
            return .green
        case .error:
            return .red
        case .info:
            return .secondary
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let phase: ExecutionPhase
    let type: LogType
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        phase: ExecutionPhase,
        type: LogType,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.phase = phase
        self.type = type
        self.message = message
    }
}
