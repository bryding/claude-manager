import Foundation

// MARK: - Interview Q&A

struct InterviewQA: Identifiable, Equatable, Sendable {
    let id: UUID
    let question: String
    let answer: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.timestamp = timestamp
    }
}

// MARK: - Interview Session

struct InterviewSession: Equatable, Sendable {
    let featureDescription: String
    let attachedImages: [AttachedImage]
    var exchanges: [InterviewQA]
    let startedAt: Date
    var completedAt: Date?

    init(
        featureDescription: String,
        attachedImages: [AttachedImage] = [],
        exchanges: [InterviewQA] = [],
        startedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.featureDescription = featureDescription
        self.attachedImages = attachedImages
        self.exchanges = exchanges
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    var isComplete: Bool {
        completedAt != nil
    }

    mutating func addExchange(question: String, answer: String) {
        let exchange = InterviewQA(question: question, answer: answer)
        exchanges.append(exchange)
    }

    mutating func markComplete() {
        completedAt = Date()
    }

    var promptContext: String {
        guard !exchanges.isEmpty else { return "" }

        return exchanges.enumerated().map { index, exchange in
            let num = index + 1
            return "Q\(num): \(exchange.question)\nA\(num): \(exchange.answer)"
        }.joined(separator: "\n\n")
    }
}
