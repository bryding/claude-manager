import XCTest
@testable import ClaudeManager

final class ClaudeStreamMessageTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - System Message Tests

    func testDecodeSystemMessage() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "tools": ["Read", "Write", "Bash"],
            "model": "claude-opus-4-5-20251101",
            "permissionMode": "plan",
            "mcp_servers": [],
            "slash_commands": ["commit", "review"],
            "claude_code_version": "2.0.76",
            "agents": ["general-purpose", "Explore"]
        }
        """

        let message = try decoder.decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)

        guard case .system(let system) = message else {
            XCTFail("Expected system message")
            return
        }

        XCTAssertEqual(system.subtype, "init")
        XCTAssertEqual(system.sessionId, "abc-123")
        XCTAssertEqual(system.cwd, "/Users/test/project")
        XCTAssertEqual(system.tools, ["Read", "Write", "Bash"])
        XCTAssertEqual(system.model, "claude-opus-4-5-20251101")
        XCTAssertEqual(system.permissionMode, "plan")
        XCTAssertEqual(system.mcpServers, [])
        XCTAssertEqual(system.slashCommands, ["commit", "review"])
        XCTAssertEqual(system.claudeCodeVersion, "2.0.76")
        XCTAssertEqual(system.agents, ["general-purpose", "Explore"])
    }

    // MARK: - Assistant Message Tests

    func testDecodeAssistantMessageWithText() throws {
        let json = """
        {
            "type": "assistant",
            "message": {
                "id": "msg_123",
                "model": "claude-opus-4-5-20251101",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "Hello world!"}
                ],
                "stop_reason": null,
                "usage": {
                    "input_tokens": 100,
                    "output_tokens": 50
                }
            },
            "session_id": "abc-123",
            "parent_tool_use_id": null
        }
        """

        let message = try decoder.decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)

        guard case .assistant(let assistant) = message else {
            XCTFail("Expected assistant message")
            return
        }

        XCTAssertEqual(assistant.sessionId, "abc-123")
        XCTAssertNil(assistant.parentToolUseId)
        XCTAssertEqual(assistant.message.id, "msg_123")
        XCTAssertEqual(assistant.message.content.count, 1)

        guard case .text(let textContent) = assistant.message.content[0] else {
            XCTFail("Expected text content")
            return
        }
        XCTAssertEqual(textContent.text, "Hello world!")
    }

    func testDecodeAssistantMessageWithToolUse() throws {
        let json = """
        {
            "type": "assistant",
            "message": {
                "id": "msg_456",
                "model": "claude-opus-4-5-20251101",
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "toolu_123",
                        "name": "Read",
                        "input": {"file_path": "/test/file.txt"}
                    }
                ],
                "stop_reason": null,
                "usage": null
            },
            "session_id": "abc-123",
            "parent_tool_use_id": null
        }
        """

        let message = try decoder.decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)

        guard case .assistant(let assistant) = message else {
            XCTFail("Expected assistant message")
            return
        }

        guard case .toolUse(let toolUse) = assistant.message.content[0] else {
            XCTFail("Expected tool use content")
            return
        }

        XCTAssertEqual(toolUse.id, "toolu_123")
        XCTAssertEqual(toolUse.name, "Read")
        XCTAssertEqual(toolUse.input.dictionary?["file_path"] as? String, "/test/file.txt")
    }

    // MARK: - Result Message Tests

    func testDecodeResultMessage() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "is_error": false,
            "duration_ms": 5000,
            "duration_api_ms": 8000,
            "num_turns": 2,
            "result": "Task completed successfully",
            "session_id": "abc-123",
            "total_cost_usd": 0.05,
            "usage": {
                "input_tokens": 1000,
                "output_tokens": 500,
                "cache_creation_input_tokens": 100,
                "cache_read_input_tokens": 200
            }
        }
        """

        let message = try decoder.decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)

        guard case .result(let result) = message else {
            XCTFail("Expected result message")
            return
        }

        XCTAssertEqual(result.subtype, "success")
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.durationMs, 5000)
        XCTAssertEqual(result.durationApiMs, 8000)
        XCTAssertEqual(result.numTurns, 2)
        XCTAssertEqual(result.result, "Task completed successfully")
        XCTAssertEqual(result.sessionId, "abc-123")
        XCTAssertEqual(result.totalCostUsd, 0.05, accuracy: 0.001)
        XCTAssertEqual(result.usage.inputTokens, 1000)
        XCTAssertEqual(result.usage.outputTokens, 500)
        XCTAssertEqual(result.usage.cacheCreationInputTokens, 100)
        XCTAssertEqual(result.usage.cacheReadInputTokens, 200)
    }

    // MARK: - User Message Tests

    func testDecodeUserMessage() throws {
        let json = """
        {
            "type": "user",
            "message": {
                "role": "user",
                "content": [
                    {
                        "tool_use_id": "toolu_123",
                        "type": "tool_result",
                        "content": "File contents here"
                    }
                ]
            },
            "session_id": "abc-123",
            "parent_tool_use_id": null,
            "tool_use_result": null
        }
        """

        let message = try decoder.decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)

        guard case .user(let user) = message else {
            XCTFail("Expected user message")
            return
        }

        XCTAssertEqual(user.sessionId, "abc-123")
        XCTAssertEqual(user.message.role, "user")
        XCTAssertEqual(user.message.content.count, 1)
        XCTAssertEqual(user.message.content[0].toolUseId, "toolu_123")
        XCTAssertEqual(user.message.content[0].content, "File contents here")
    }

    // MARK: - AskUserQuestion Tests

    func testDecodeAskUserQuestionToolUse() throws {
        let json = """
        {
            "type": "assistant",
            "message": {
                "id": "msg_789",
                "model": "claude-opus-4-5-20251101",
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "toolu_ask",
                        "name": "AskUserQuestion",
                        "input": {
                            "questions": [
                                {
                                    "question": "What is your favorite color?",
                                    "header": "Color",
                                    "options": [
                                        {"label": "Blue", "description": "A calm color"},
                                        {"label": "Red", "description": "A bold color"}
                                    ],
                                    "multiSelect": false
                                }
                            ]
                        }
                    }
                ],
                "stop_reason": null,
                "usage": null
            },
            "session_id": "abc-123",
            "parent_tool_use_id": null
        }
        """

        let message = try decoder.decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)

        guard case .assistant(let assistant) = message else {
            XCTFail("Expected assistant message")
            return
        }

        guard case .toolUse(let toolUse) = assistant.message.content[0] else {
            XCTFail("Expected tool use content")
            return
        }

        XCTAssertTrue(toolUse.isAskUserQuestion)

        guard let questionInput = toolUse.askUserQuestionInput else {
            XCTFail("Expected AskUserQuestionInput")
            return
        }

        XCTAssertEqual(questionInput.questions.count, 1)
        XCTAssertEqual(questionInput.questions[0].question, "What is your favorite color?")
        XCTAssertEqual(questionInput.questions[0].header, "Color")
        XCTAssertEqual(questionInput.questions[0].options.count, 2)
        XCTAssertEqual(questionInput.questions[0].options[0].label, "Blue")
        XCTAssertFalse(questionInput.questions[0].multiSelect)
    }

    func testIsAskUserQuestionReturnsFalseForOtherTools() throws {
        let json = """
        {
            "type": "tool_use",
            "id": "toolu_read",
            "name": "Read",
            "input": {"file_path": "/test.txt"}
        }
        """

        let toolUse = try decoder.decode(ToolUseContent.self, from: json.data(using: .utf8)!)

        XCTAssertFalse(toolUse.isAskUserQuestion)
        XCTAssertNil(toolUse.askUserQuestionInput)
    }

    // MARK: - Error Handling Tests

    func testDecodeUnknownMessageTypeThrows() {
        let json = """
        {"type": "unknown_type"}
        """

        XCTAssertThrowsError(try decoder.decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!))
    }

    func testDecodeUnknownContentBlockTypeThrows() {
        let json = """
        {"type": "unknown_block"}
        """

        XCTAssertThrowsError(try decoder.decode(ContentBlock.self, from: json.data(using: .utf8)!))
    }
}

// MARK: - AnyCodable Tests

final class AnyCodableTests: XCTestCase {

    private let decoder = JSONDecoder()

    func testDecodeString() throws {
        let json = "\"hello\""
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(value.string, "hello")
    }

    func testDecodeInt() throws {
        let json = "42"
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(value.int, 42)
    }

    func testDecodeDouble() throws {
        let json = "3.14"
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(value.double!, 3.14, accuracy: 0.001)
    }

    func testDecodeBool() throws {
        let json = "true"
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(value.bool, true)
    }

    func testDecodeArray() throws {
        let json = "[1, 2, 3]"
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        let array = value.array as? [Int]
        XCTAssertEqual(array, [1, 2, 3])
    }

    func testDecodeDictionary() throws {
        let json = """
        {"key": "value", "number": 123}
        """
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        let dict = value.dictionary
        XCTAssertEqual(dict?["key"] as? String, "value")
        XCTAssertEqual(dict?["number"] as? Int, 123)
    }

    func testDecodeNull() throws {
        let json = "null"
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(value.value is NSNull)
    }

    func testDecodeNestedStructure() throws {
        let json = """
        {
            "name": "test",
            "items": [1, 2, 3],
            "nested": {"inner": true}
        }
        """
        let value = try decoder.decode(AnyCodable.self, from: json.data(using: .utf8)!)
        let dict = value.dictionary

        XCTAssertEqual(dict?["name"] as? String, "test")
        XCTAssertEqual(dict?["items"] as? [Int], [1, 2, 3])

        let nested = dict?["nested"] as? [String: Any]
        XCTAssertEqual(nested?["inner"] as? Bool, true)
    }
}
