import Foundation

// MARK: - Main Stream Message

enum ClaudeStreamMessage: Decodable {
    case system(SystemMessage)
    case assistant(AssistantMessage)
    case user(UserMessage)
    case result(ResultMessage)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "system":
            self = .system(try SystemMessage(from: decoder))
        case "assistant":
            self = .assistant(try AssistantMessage(from: decoder))
        case "user":
            self = .user(try UserMessage(from: decoder))
        case "result":
            self = .result(try ResultMessage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }
}

// MARK: - System Message

struct SystemMessage: Decodable {
    let subtype: String
    let sessionId: String
    let cwd: String
    let tools: [String]
    let model: String
    let permissionMode: String
    let mcpServers: [String]
    let slashCommands: [String]
    let claudeCodeVersion: String
    let agents: [String]

    enum CodingKeys: String, CodingKey {
        case subtype
        case sessionId = "session_id"
        case cwd
        case tools
        case model
        case permissionMode
        case mcpServers = "mcp_servers"
        case slashCommands = "slash_commands"
        case claudeCodeVersion = "claude_code_version"
        case agents
    }
}

// MARK: - Assistant Message

struct AssistantMessage: Decodable {
    let message: MessageContent
    let sessionId: String
    let parentToolUseId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case sessionId = "session_id"
        case parentToolUseId = "parent_tool_use_id"
    }
}

struct MessageContent: Decodable {
    let id: String
    let model: String
    let role: String
    let content: [ContentBlock]
    let stopReason: String?
    let usage: UsageInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case model
        case role
        case content
        case stopReason = "stop_reason"
        case usage
    }
}

// MARK: - Content Blocks

enum ContentBlock: Decodable {
    case text(TextContent)
    case toolUse(ToolUseContent)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }
}

struct TextContent: Decodable {
    let text: String
}

struct ToolUseContent: Decodable {
    let id: String
    let name: String
    let input: AnyCodable
}

// MARK: - User Message

struct UserMessage: Decodable {
    let message: UserMessageContent
    let sessionId: String
    let parentToolUseId: String?
    let toolUseResult: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case message
        case sessionId = "session_id"
        case parentToolUseId = "parent_tool_use_id"
        case toolUseResult = "tool_use_result"
    }
}

struct UserMessageContent: Decodable {
    let role: String
    let content: [ToolResultContent]
}

struct ToolResultContent: Decodable {
    let toolUseId: String
    let type: String
    let content: String
    let isError: Bool?

    enum CodingKeys: String, CodingKey {
        case toolUseId = "tool_use_id"
        case type
        case content
        case isError = "is_error"
    }
}

// MARK: - Result Message

struct ResultMessage: Decodable {
    let subtype: String
    let isError: Bool
    let durationMs: Int
    let durationApiMs: Int
    let numTurns: Int
    let result: String
    let sessionId: String
    let totalCostUsd: Double
    let usage: ResultUsage

    enum CodingKeys: String, CodingKey {
        case subtype
        case isError = "is_error"
        case durationMs = "duration_ms"
        case durationApiMs = "duration_api_ms"
        case numTurns = "num_turns"
        case result
        case sessionId = "session_id"
        case totalCostUsd = "total_cost_usd"
        case usage
    }
}

struct ResultUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

// MARK: - Usage Info

struct UsageInfo: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

// MARK: - AskUserQuestion Input

struct AskUserQuestionInput: Decodable {
    let questions: [Question]

    struct Question: Decodable {
        let question: String
        let header: String
        let options: [Option]
        let multiSelect: Bool
    }

    struct Option: Decodable {
        let label: String
        let description: String
    }
}

// MARK: - AnyCodable

struct AnyCodable: Decodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable"
            )
        }
    }

    var dictionary: [String: Any]? {
        value as? [String: Any]
    }

    var array: [Any]? {
        value as? [Any]
    }

    var string: String? {
        value as? String
    }

    var int: Int? {
        value as? Int
    }

    var double: Double? {
        value as? Double
    }

    var bool: Bool? {
        value as? Bool
    }
}

// MARK: - Convenience Extensions

extension ToolUseContent {
    func decodeInput<T: Decodable>(as type: T.Type) -> T? {
        guard let dict = input.dictionary else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    var isAskUserQuestion: Bool {
        name == "AskUserQuestion"
    }

    var askUserQuestionInput: AskUserQuestionInput? {
        decodeInput(as: AskUserQuestionInput.self)
    }
}
