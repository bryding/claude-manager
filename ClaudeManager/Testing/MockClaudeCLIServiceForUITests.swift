import Foundation

final class MockClaudeCLIServiceForUITests: ClaudeCLIServiceProtocol, @unchecked Sendable {
    private static let mockModel = "claude-sonnet-4-20250514"
    private static let mockSessionId = "mock-session-id"
    private static let messageDelayNanoseconds: UInt64 = 100_000_000

    private let scenario: TestScenario
    private var _isRunning = false
    private var shouldTerminate = false

    var isRunning: Bool { _isRunning }

    init(scenario: TestScenario) {
        self.scenario = scenario
    }

    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        _isRunning = true
        shouldTerminate = false
        defer { _isRunning = false }

        let messages = messagesForScenario()
        for message in messages {
            if shouldTerminate { break }
            await simulateDelay()
            await onMessage(message)
        }

        return resultForScenario()
    }

    func execute(
        content: PromptContent,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        try await execute(
            prompt: content.text,
            workingDirectory: workingDirectory,
            permissionMode: permissionMode,
            sessionId: sessionId,
            timeout: timeout,
            onMessage: onMessage
        )
    }

    func terminate() {
        shouldTerminate = true
        _isRunning = false
    }

    func interrupt() {
        shouldTerminate = true
        _isRunning = false
    }

    private func simulateDelay() async {
        try? await Task.sleep(nanoseconds: Self.messageDelayNanoseconds)
    }

    // MARK: - Scenario-Based Responses

    private func messagesForScenario() -> [ClaudeStreamMessage] {
        switch scenario {
        case .idle:
            return [
                makeSystemMessage(),
                makeAssistantTextMessage("Ready to help with your project."),
            ]

        case .setupWithProject:
            return [
                makeSystemMessage(),
                makeAssistantTextMessage("I see you have a project selected. Let me know what you'd like to build."),
            ]

        case .executingTask:
            return [
                makeSystemMessage(),
                makeAssistantTextMessage("Working on Task 1: Implement feature..."),
                makeAssistantTextMessage("Reading files to understand the codebase..."),
                makeAssistantTextMessage("Making edits to implement the feature..."),
            ]

        case .waitingForUserQuestion:
            return [
                makeSystemMessage(),
                makeAssistantTextMessage("I need some clarification before proceeding."),
                makeAskUserQuestionMessage(),
            ]

        case .completed:
            return [
                makeSystemMessage(),
                makeAssistantTextMessage("Task completed successfully!"),
            ]

        case .failed:
            return [
                makeSystemMessage(),
                makeAssistantTextMessage("Encountered an error while executing the task."),
            ]
        }
    }

    private func resultForScenario() -> ClaudeExecutionResult {
        switch scenario {
        case .failed:
            return ClaudeExecutionResult(
                result: "Error: Task execution failed",
                sessionId: "mock-session-\(UUID().uuidString.prefix(8))",
                totalCostUsd: 0.01,
                durationMs: 500,
                isError: true
            )
        default:
            return ClaudeExecutionResult(
                result: "Task completed successfully",
                sessionId: "mock-session-\(UUID().uuidString.prefix(8))",
                totalCostUsd: 0.05,
                durationMs: 1000,
                isError: false
            )
        }
    }

    // MARK: - Message Factories

    private func makeSystemMessage() -> ClaudeStreamMessage {
        .system(SystemMessage(
            subtype: "init",
            sessionId: Self.mockSessionId,
            cwd: "/mock/project/path",
            tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
            model: Self.mockModel,
            permissionMode: "plan",
            mcpServers: [],
            slashCommands: ["/commit", "/review"],
            claudeCodeVersion: "1.0.0-mock",
            agents: []
        ))
    }

    private func makeAssistantMessage(
        content: [ContentBlock],
        stopReason: String = "end_turn"
    ) -> ClaudeStreamMessage {
        .assistant(AssistantMessage(
            message: MessageContent(
                id: "msg_\(UUID().uuidString.prefix(8))",
                model: Self.mockModel,
                role: "assistant",
                content: content,
                stopReason: stopReason,
                usage: UsageInfo(
                    inputTokens: 100,
                    outputTokens: 50,
                    cacheCreationInputTokens: nil,
                    cacheReadInputTokens: nil
                )
            ),
            sessionId: Self.mockSessionId,
            parentToolUseId: nil
        ))
    }

    private func makeAssistantTextMessage(_ text: String) -> ClaudeStreamMessage {
        makeAssistantMessage(content: [.text(TextContent(text: text))])
    }

    private func makeAskUserQuestionMessage() -> ClaudeStreamMessage {
        let questionInput: [String: Any] = [
            "questions": [
                [
                    "question": "Which implementation approach would you prefer?",
                    "header": "Approach",
                    "multiSelect": false,
                    "options": [
                        ["label": "Option A", "description": "A simple and straightforward implementation"],
                        ["label": "Option B", "description": "A more complex but flexible implementation"],
                        ["label": "Option C", "description": "A balanced approach with moderate complexity"]
                    ]
                ]
            ]
        ]

        return makeAssistantMessage(
            content: [
                .toolUse(ToolUseContent(
                    id: "toolu_\(UUID().uuidString.prefix(8))",
                    name: "AskUserQuestion",
                    input: AnyCodable(questionInput)
                ))
            ],
            stopReason: "tool_use"
        )
    }
}
