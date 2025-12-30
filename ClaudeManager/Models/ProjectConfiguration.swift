import Foundation

enum ProjectType: String, Sendable, Equatable, Codable, CaseIterable {
    case swift
    case xcode
    case typescript
    case javascript
    case python
    case rust
    case go
    case unknown

    var displayName: String {
        switch self {
        case .swift:
            return "Swift Package"
        case .xcode:
            return "Xcode Project"
        case .typescript:
            return "TypeScript"
        case .javascript:
            return "JavaScript"
        case .python:
            return "Python"
        case .rust:
            return "Rust"
        case .go:
            return "Go"
        case .unknown:
            return "Unknown"
        }
    }
}

struct ProjectConfiguration: Sendable, Equatable, Codable {
    var projectType: ProjectType
    var buildCommand: String?
    var testCommand: String?

    init(
        projectType: ProjectType = .unknown,
        buildCommand: String? = nil,
        testCommand: String? = nil
    ) {
        self.projectType = projectType
        self.buildCommand = buildCommand
        self.testCommand = testCommand
    }

    static let `default` = ProjectConfiguration()
}
