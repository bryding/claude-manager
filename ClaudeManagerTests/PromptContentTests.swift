import XCTest
@testable import ClaudeManager

final class PromptContentTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestImage(mediaType: ImageMediaType = .png, dataSize: Int = 100) -> AttachedImage {
        let data = Data(repeating: 0x42, count: dataSize)
        let thumbnail = NSImage(size: NSSize(width: 80, height: 80))
        return AttachedImage(
            data: data,
            mediaType: mediaType,
            thumbnail: thumbnail,
            originalSize: CGSize(width: 800, height: 600)
        )
    }

    // MARK: - Initialization Tests

    func testInitWithTextOnly() {
        let content = PromptContent(text: "Hello world")

        XCTAssertEqual(content.text, "Hello world")
        XCTAssertTrue(content.images.isEmpty)
    }

    func testInitWithTextAndImages() {
        let image = makeTestImage()
        let content = PromptContent(text: "Description", images: [image])

        XCTAssertEqual(content.text, "Description")
        XCTAssertEqual(content.images.count, 1)
    }

    func testInitWithEmptyText() {
        let content = PromptContent(text: "")

        XCTAssertEqual(content.text, "")
        XCTAssertTrue(content.images.isEmpty)
    }

    func testDefaultImagesParameterIsEmpty() {
        let content = PromptContent(text: "Test")

        XCTAssertTrue(content.images.isEmpty)
    }

    // MARK: - hasImages Tests

    func testHasImagesReturnsFalseWhenNoImages() {
        let content = PromptContent(text: "Text only")

        XCTAssertFalse(content.hasImages)
    }

    func testHasImagesReturnsTrueWhenImagesPresent() {
        let image = makeTestImage()
        let content = PromptContent(text: "With image", images: [image])

        XCTAssertTrue(content.hasImages)
    }

    func testHasImagesReturnsTrueWithMultipleImages() {
        let images = [makeTestImage(), makeTestImage()]
        let content = PromptContent(text: "Multiple", images: images)

        XCTAssertTrue(content.hasImages)
    }

    // MARK: - contentBlocks Tests

    func testContentBlocksWithTextOnly() {
        let content = PromptContent(text: "Just text")

        let blocks = content.contentBlocks

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0], .text("Just text"))
    }

    func testContentBlocksWithEmptyTextReturnsNoTextBlock() {
        let content = PromptContent(text: "")

        let blocks = content.contentBlocks

        XCTAssertTrue(blocks.isEmpty)
    }

    func testContentBlocksWithImageOnly() {
        let image = makeTestImage(mediaType: .jpeg)
        let content = PromptContent(text: "", images: [image])

        let blocks = content.contentBlocks

        XCTAssertEqual(blocks.count, 1)
        if case .image(let mediaType, let data) = blocks[0] {
            XCTAssertEqual(mediaType, "image/jpeg")
            XCTAssertEqual(data, image.base64Encoded)
        } else {
            XCTFail("Expected image block")
        }
    }

    func testContentBlocksWithTextAndImage() {
        let image = makeTestImage(mediaType: .png)
        let content = PromptContent(text: "Description", images: [image])

        let blocks = content.contentBlocks

        XCTAssertEqual(blocks.count, 2)
        if case .image(let mediaType, _) = blocks[0] {
            XCTAssertEqual(mediaType, "image/png")
        } else {
            XCTFail("Expected image block first")
        }
        XCTAssertEqual(blocks[1], .text("Description"))
    }

    func testContentBlocksOrdersImagesBeforeText() {
        let images = [makeTestImage(), makeTestImage()]
        let content = PromptContent(text: "After images", images: images)

        let blocks = content.contentBlocks

        XCTAssertEqual(blocks.count, 3)
        if case .image = blocks[0], case .image = blocks[1] {
            // Images are first
        } else {
            XCTFail("Expected images first")
        }
        XCTAssertEqual(blocks[2], .text("After images"))
    }

    // MARK: - toJSONData Tests

    func testToJSONDataWithTextOnly() throws {
        let content = PromptContent(text: "Hello")

        let data = try content.toJSONData()
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 1)
        XCTAssertEqual(json?[0]["type"] as? String, "text")
        XCTAssertEqual(json?[0]["text"] as? String, "Hello")
    }

    func testToJSONDataWithImage() throws {
        let image = makeTestImage(mediaType: .png, dataSize: 10)
        let content = PromptContent(text: "", images: [image])

        let data = try content.toJSONData()
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 1)
        XCTAssertEqual(json?[0]["type"] as? String, "image")

        let source = json?[0]["source"] as? [String: Any]
        XCTAssertEqual(source?["type"] as? String, "base64")
        XCTAssertEqual(source?["media_type"] as? String, "image/png")
        XCTAssertNotNil(source?["data"] as? String)
    }

    func testToJSONDataWithEmptyContentReturnsEmptyArray() throws {
        let content = PromptContent(text: "")

        let data = try content.toJSONData()
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 0)
    }

    // MARK: - Equatable Tests

    func testEquatableWithSameContent() {
        let content1 = PromptContent(text: "Same")
        let content2 = PromptContent(text: "Same")

        XCTAssertEqual(content1, content2)
    }

    func testEquatableWithDifferentText() {
        let content1 = PromptContent(text: "First")
        let content2 = PromptContent(text: "Second")

        XCTAssertNotEqual(content1, content2)
    }

    func testEquatableWithDifferentImages() {
        let image1 = makeTestImage()
        let image2 = makeTestImage()
        let content1 = PromptContent(text: "Same", images: [image1])
        let content2 = PromptContent(text: "Same", images: [image2])

        // Different images have different UUIDs
        XCTAssertNotEqual(content1, content2)
    }

    func testEquatableWithSameImages() {
        let image = makeTestImage()
        let content1 = PromptContent(text: "Same", images: [image])
        let content2 = PromptContent(text: "Same", images: [image])

        XCTAssertEqual(content1, content2)
    }
}

// MARK: - ClaudeContentBlock Tests

final class ClaudeContentBlockTests: XCTestCase {

    private let encoder = JSONEncoder()

    // MARK: - Text Block Tests

    func testTextBlockEncoding() throws {
        let block = ClaudeContentBlock.text("Hello world")

        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "text")
        XCTAssertEqual(json?["text"] as? String, "Hello world")
        XCTAssertNil(json?["source"])
    }

    func testTextBlockWithEmptyString() throws {
        let block = ClaudeContentBlock.text("")

        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "text")
        XCTAssertEqual(json?["text"] as? String, "")
    }

    func testTextBlockWithSpecialCharacters() throws {
        let block = ClaudeContentBlock.text("Hello\n\"World\" & <Test>")

        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["text"] as? String, "Hello\n\"World\" & <Test>")
    }

    func testTextBlockWithUnicode() throws {
        let block = ClaudeContentBlock.text("Hello 世界 🌍")

        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["text"] as? String, "Hello 世界 🌍")
    }

    // MARK: - Image Block Tests

    func testImageBlockEncoding() throws {
        let block = ClaudeContentBlock.image(mediaType: "image/png", data: "SGVsbG8=")

        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "image")
        XCTAssertNil(json?["text"])

        let source = json?["source"] as? [String: Any]
        XCTAssertNotNil(source)
        XCTAssertEqual(source?["type"] as? String, "base64")
        XCTAssertEqual(source?["media_type"] as? String, "image/png")
        XCTAssertEqual(source?["data"] as? String, "SGVsbG8=")
    }

    func testImageBlockWithJpegMediaType() throws {
        let block = ClaudeContentBlock.image(mediaType: "image/jpeg", data: "dGVzdA==")

        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let source = json?["source"] as? [String: Any]
        XCTAssertEqual(source?["media_type"] as? String, "image/jpeg")
    }

    func testImageBlockSourceStructure() throws {
        let block = ClaudeContentBlock.image(mediaType: "image/png", data: "abc123")

        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let source = json?["source"] as? [String: Any]
        XCTAssertEqual(source?.keys.count, 3)
        XCTAssertNotNil(source?["type"])
        XCTAssertNotNil(source?["media_type"])
        XCTAssertNotNil(source?["data"])
    }

    // MARK: - Equatable Tests

    func testTextBlocksEqual() {
        let block1 = ClaudeContentBlock.text("Same")
        let block2 = ClaudeContentBlock.text("Same")

        XCTAssertEqual(block1, block2)
    }

    func testTextBlocksNotEqual() {
        let block1 = ClaudeContentBlock.text("First")
        let block2 = ClaudeContentBlock.text("Second")

        XCTAssertNotEqual(block1, block2)
    }

    func testImageBlocksEqual() {
        let block1 = ClaudeContentBlock.image(mediaType: "image/png", data: "abc")
        let block2 = ClaudeContentBlock.image(mediaType: "image/png", data: "abc")

        XCTAssertEqual(block1, block2)
    }

    func testImageBlocksNotEqualDifferentMediaType() {
        let block1 = ClaudeContentBlock.image(mediaType: "image/png", data: "abc")
        let block2 = ClaudeContentBlock.image(mediaType: "image/jpeg", data: "abc")

        XCTAssertNotEqual(block1, block2)
    }

    func testImageBlocksNotEqualDifferentData() {
        let block1 = ClaudeContentBlock.image(mediaType: "image/png", data: "abc")
        let block2 = ClaudeContentBlock.image(mediaType: "image/png", data: "xyz")

        XCTAssertNotEqual(block1, block2)
    }

    func testTextAndImageBlocksNotEqual() {
        let textBlock = ClaudeContentBlock.text("text")
        let imageBlock = ClaudeContentBlock.image(mediaType: "image/png", data: "data")

        XCTAssertNotEqual(textBlock, imageBlock)
    }

    // MARK: - Array Encoding Tests

    func testEncodingArrayOfBlocks() throws {
        let blocks: [ClaudeContentBlock] = [
            .image(mediaType: "image/png", data: "img1"),
            .text("Description")
        ]

        let data = try encoder.encode(blocks)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertEqual(json?.count, 2)
        XCTAssertEqual(json?[0]["type"] as? String, "image")
        XCTAssertEqual(json?[1]["type"] as? String, "text")
    }
}
