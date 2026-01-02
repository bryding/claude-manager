import XCTest
@testable import ClaudeManager

final class InterviewSessionTests: XCTestCase {

    // MARK: - InterviewQA Tests

    func testInterviewQAInitialization() {
        let qa = InterviewQA(question: "What is the scope?", answer: "Just the login page")

        XCTAssertEqual(qa.question, "What is the scope?")
        XCTAssertEqual(qa.answer, "Just the login page")
        XCTAssertNotNil(qa.id)
        XCTAssertNotNil(qa.timestamp)
    }

    // MARK: - InterviewSession Tests

    func testInterviewSessionInitialization() {
        let session = InterviewSession(featureDescription: "Add dark mode")

        XCTAssertEqual(session.featureDescription, "Add dark mode")
        XCTAssertTrue(session.exchanges.isEmpty)
        XCTAssertNil(session.completedAt)
        XCTAssertFalse(session.isComplete)
    }

    func testIsCompleteReturnsTrueWhenCompletedAtIsSet() {
        var session = InterviewSession(featureDescription: "Test feature")
        XCTAssertFalse(session.isComplete)

        session.markComplete()
        XCTAssertTrue(session.isComplete)
        XCTAssertNotNil(session.completedAt)
    }

    func testAddExchangeAppendsToExchanges() {
        var session = InterviewSession(featureDescription: "Test feature")
        XCTAssertEqual(session.exchanges.count, 0)

        session.addExchange(question: "Q1?", answer: "A1")
        XCTAssertEqual(session.exchanges.count, 1)
        XCTAssertEqual(session.exchanges[0].question, "Q1?")
        XCTAssertEqual(session.exchanges[0].answer, "A1")

        session.addExchange(question: "Q2?", answer: "A2")
        XCTAssertEqual(session.exchanges.count, 2)
    }

    // MARK: - promptContext Tests

    func testPromptContextReturnsEmptyStringWhenNoExchanges() {
        let session = InterviewSession(featureDescription: "Test feature")

        XCTAssertEqual(session.promptContext, "")
    }

    func testPromptContextFormatsSingleExchange() {
        var session = InterviewSession(featureDescription: "Test feature")
        session.addExchange(question: "What is the scope?", answer: "Just the login page")

        let expected = "Q1: What is the scope?\nA1: Just the login page"
        XCTAssertEqual(session.promptContext, expected)
    }

    func testPromptContextFormatsMultipleExchanges() {
        var session = InterviewSession(featureDescription: "Test feature")
        session.addExchange(question: "First question?", answer: "First answer")
        session.addExchange(question: "Second question?", answer: "Second answer")
        session.addExchange(question: "Third question?", answer: "Third answer")

        let expected = """
            Q1: First question?
            A1: First answer

            Q2: Second question?
            A2: Second answer

            Q3: Third question?
            A3: Third answer
            """
        XCTAssertEqual(session.promptContext, expected)
    }

    func testPromptContextPreservesMultilineContent() {
        var session = InterviewSession(featureDescription: "Test feature")
        session.addExchange(
            question: "What features?\nList them all.",
            answer: "Feature 1\nFeature 2\nFeature 3"
        )

        let expected = "Q1: What features?\nList them all.\nA1: Feature 1\nFeature 2\nFeature 3"
        XCTAssertEqual(session.promptContext, expected)
    }
}
