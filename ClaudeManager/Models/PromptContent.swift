import Foundation

// MARK: - Prompt Content

struct PromptContent: Sendable, Equatable {
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
        let imageBlocks = images.map { image in
            ClaudeContentBlock.image(
                mediaType: image.mediaType.rawValue,
                data: image.base64Encoded
            )
        }
        let textBlocks = text.isEmpty ? [] : [ClaudeContentBlock.text(text)]
        return imageBlocks + textBlocks
    }

    func toJSONData() throws -> Data {
        try JSONEncoder().encode(contentBlocks)
    }
}

// MARK: - Claude Content Block

enum ClaudeContentBlock: Encodable, Sendable, Equatable {
    case text(String)
    case image(mediaType: String, data: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case source
    }

    private enum SourceKeys: String, CodingKey {
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
