import Foundation

// MARK: - Prompt Content

struct PromptContent: Sendable {
    let text: String
    let images: [AttachedImage]

    init(text: String, images: [AttachedImage] = []) {
        self.text = text
        self.images = images
    }

    var hasImages: Bool {
        !images.isEmpty
    }

    var contentBlocks: [ClaudeContentBlock] {
        var blocks: [ClaudeContentBlock] = images.map { image in
            .image(
                mediaType: image.mediaType.rawValue,
                data: image.base64Encoded
            )
        }
        if !text.isEmpty {
            blocks.append(.text(text))
        }
        return blocks
    }

    func toJSONData() throws -> Data {
        let blocks = contentBlocks
        return try JSONEncoder().encode(blocks)
    }
}

// MARK: - Claude Content Block

enum ClaudeContentBlock: Encodable, Sendable {
    case text(String)
    case image(mediaType: String, data: String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case source
    }

    enum SourceKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)

        case .image(let mediaType, let data):
            try container.encode("image", forKey: .type)
            var sourceContainer = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try sourceContainer.encode("base64", forKey: .type)
            try sourceContainer.encode(mediaType, forKey: .mediaType)
            try sourceContainer.encode(data, forKey: .data)
        }
    }
}

// MARK: - Equatable

extension PromptContent: Equatable {
    static func == (lhs: PromptContent, rhs: PromptContent) -> Bool {
        lhs.text == rhs.text && lhs.images == rhs.images
    }
}

extension ClaudeContentBlock: Equatable {
    static func == (lhs: ClaudeContentBlock, rhs: ClaudeContentBlock) -> Bool {
        switch (lhs, rhs) {
        case (.text(let lhsText), .text(let rhsText)):
            return lhsText == rhsText
        case (.image(let lhsMediaType, let lhsData), .image(let rhsMediaType, let rhsData)):
            return lhsMediaType == rhsMediaType && lhsData == rhsData
        default:
            return false
        }
    }
}
