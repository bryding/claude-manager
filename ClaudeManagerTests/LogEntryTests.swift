import XCTest
@testable import ClaudeManager

final class LogEntryTests: XCTestCase {

    // MARK: - LogType Badge Label Tests

    func testOutputBadgeLabel() {
        XCTAssertEqual(LogType.output.badgeLabel, "OUTPUT")
    }

    func testToolUseBadgeLabel() {
        XCTAssertEqual(LogType.toolUse.badgeLabel, "TOOL")
    }

    func testResultBadgeLabel() {
        XCTAssertEqual(LogType.result.badgeLabel, "RESULT")
    }

    func testErrorBadgeLabel() {
        XCTAssertEqual(LogType.error.badgeLabel, "ERROR")
    }

    func testInfoBadgeLabel() {
        XCTAssertEqual(LogType.info.badgeLabel, "INFO")
    }

    func testSeparatorBadgeLabel() {
        XCTAssertEqual(LogType.separator.badgeLabel, "SESSION")
    }

    func testAllBadgeLabelsAreUppercase() {
        for logType in [LogType.output, .toolUse, .result, .error, .info, .separator] {
            XCTAssertEqual(
                logType.badgeLabel,
                logType.badgeLabel.uppercased(),
                "\(logType) badge label should be uppercase"
            )
        }
    }

    func testBadgeLabelsHaveMaxSixCharacters() {
        // The log view pads badges to 6 characters, so labels should fit
        for logType in [LogType.output, .toolUse, .result, .error, .info] {
            XCTAssertLessThanOrEqual(
                logType.badgeLabel.count,
                6,
                "\(logType) badge label should be at most 6 characters for proper alignment"
            )
        }
    }

    // MARK: - LogEntry Initialization Tests

    func testLogEntryInitializationWithDefaults() {
        let entry = LogEntry(phase: .executingTask, type: .output, message: "Test message")

        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.timestamp)
        XCTAssertEqual(entry.phase, .executingTask)
        XCTAssertEqual(entry.type, .output)
        XCTAssertEqual(entry.message, "Test message")
    }

    func testLogEntryInitializationWithCustomValues() {
        let customId = UUID()
        let customDate = Date(timeIntervalSince1970: 1000)

        let entry = LogEntry(
            id: customId,
            timestamp: customDate,
            phase: .conductingInterview,
            type: .toolUse,
            message: "Custom message"
        )

        XCTAssertEqual(entry.id, customId)
        XCTAssertEqual(entry.timestamp, customDate)
        XCTAssertEqual(entry.phase, .conductingInterview)
        XCTAssertEqual(entry.type, .toolUse)
        XCTAssertEqual(entry.message, "Custom message")
    }

    func testLogEntryWithEmptyMessage() {
        let entry = LogEntry(phase: .idle, type: .info, message: "")

        XCTAssertEqual(entry.message, "")
    }

    func testLogEntryWithLongMessage() {
        let longMessage = String(repeating: "a", count: 10000)
        let entry = LogEntry(phase: .executingTask, type: .output, message: longMessage)

        XCTAssertEqual(entry.message.count, 10000)
    }

    func testLogEntryWithMultilineMessage() {
        let multilineMessage = "Line 1\nLine 2\nLine 3"
        let entry = LogEntry(phase: .executingTask, type: .output, message: multilineMessage)

        XCTAssertEqual(entry.message, multilineMessage)
        XCTAssertTrue(entry.message.contains("\n"))
    }

    func testLogEntryWithSpecialCharacters() {
        let specialMessage = "Error: <script>alert('xss')</script> & \"quotes\" 'apostrophes'"
        let entry = LogEntry(phase: .executingTask, type: .error, message: specialMessage)

        XCTAssertEqual(entry.message, specialMessage)
    }

    func testLogEntryWithUnicodeCharacters() {
        let unicodeMessage = "Hello 世界 🌍 مرحبا"
        let entry = LogEntry(phase: .executingTask, type: .output, message: unicodeMessage)

        XCTAssertEqual(entry.message, unicodeMessage)
    }

    // MARK: - LogEntry Equatable Tests

    func testLogEntriesWithSameIdAreEqual() {
        let id = UUID()
        let timestamp = Date()

        let entry1 = LogEntry(
            id: id,
            timestamp: timestamp,
            phase: .executingTask,
            type: .output,
            message: "Same message"
        )
        let entry2 = LogEntry(
            id: id,
            timestamp: timestamp,
            phase: .executingTask,
            type: .output,
            message: "Same message"
        )

        XCTAssertEqual(entry1, entry2)
    }

    func testLogEntriesWithDifferentIdsAreNotEqual() {
        let timestamp = Date()

        let entry1 = LogEntry(
            id: UUID(),
            timestamp: timestamp,
            phase: .executingTask,
            type: .output,
            message: "Same message"
        )
        let entry2 = LogEntry(
            id: UUID(),
            timestamp: timestamp,
            phase: .executingTask,
            type: .output,
            message: "Same message"
        )

        XCTAssertNotEqual(entry1, entry2)
    }

    func testLogEntriesWithDifferentMessagesAreNotEqual() {
        let id = UUID()
        let timestamp = Date()

        let entry1 = LogEntry(
            id: id,
            timestamp: timestamp,
            phase: .executingTask,
            type: .output,
            message: "Message 1"
        )
        let entry2 = LogEntry(
            id: id,
            timestamp: timestamp,
            phase: .executingTask,
            type: .output,
            message: "Message 2"
        )

        XCTAssertNotEqual(entry1, entry2)
    }

    func testLogEntriesWithDifferentTypesAreNotEqual() {
        let id = UUID()
        let timestamp = Date()

        let entry1 = LogEntry(
            id: id,
            timestamp: timestamp,
            phase: .executingTask,
            type: .output,
            message: "Same message"
        )
        let entry2 = LogEntry(
            id: id,
            timestamp: timestamp,
            phase: .executingTask,
            type: .error,
            message: "Same message"
        )

        XCTAssertNotEqual(entry1, entry2)
    }

    // MARK: - LogEntry Identifiable Tests

    func testLogEntryIdentifiableConformance() {
        let entry = LogEntry(phase: .executingTask, type: .output, message: "Test")

        // Identifiable requires id property
        let _: UUID = entry.id
        XCTAssertNotNil(entry.id)
    }

    func testUniqueIdsForDifferentEntries() {
        let entry1 = LogEntry(phase: .executingTask, type: .output, message: "Test 1")
        let entry2 = LogEntry(phase: .executingTask, type: .output, message: "Test 2")

        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    // MARK: - LogType All Cases Tests

    func testAllLogTypesHaveBadgeLabels() {
        let allTypes: [LogType] = [.output, .toolUse, .result, .error, .info, .separator]

        for logType in allTypes {
            XCTAssertFalse(logType.badgeLabel.isEmpty, "\(logType) should have a non-empty badge label")
        }
    }

    func testAllLogTypesHaveColors() {
        let allTypes: [LogType] = [.output, .toolUse, .result, .error, .info, .separator]

        for logType in allTypes {
            // Just verify color property is accessible and returns a value
            _ = logType.color
        }
    }

    // MARK: - Separator Log Type Tests

    func testSeparatorTypeForSessionMarkers() {
        let entry = LogEntry(phase: .idle, type: .separator, message: "New Session")

        XCTAssertEqual(entry.type, .separator)
        XCTAssertEqual(entry.type.badgeLabel, "SESSION")
    }
}
