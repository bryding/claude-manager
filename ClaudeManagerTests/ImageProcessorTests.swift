import XCTest
@testable import ClaudeManager

final class ImageProcessorTests: XCTestCase {

    private var processor: ImageProcessor!

    override func setUp() {
        super.setUp()
        processor = ImageProcessor()
    }

    override func tearDown() {
        processor = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func createTestImage(width: Int, height: Int) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    private func createImageData(
        width: Int = 100,
        height: Int = 100,
        format: NSBitmapImageRep.FileType = .png
    ) -> Data? {
        let image = createTestImage(width: width, height: height)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        let properties: [NSBitmapImageRep.PropertyKey: Any] = format == .jpeg
            ? [.compressionFactor: 0.9]
            : [:]
        return bitmapRep.representation(using: format, properties: properties)
    }

    // MARK: - Process NSImage Tests

    func testProcessValidPNGImage() {
        let image = createTestImage(width: 200, height: 150)

        let result = processor.process(image: image)

        switch result {
        case .success(let attachedImage):
            XCTAssertFalse(attachedImage.data.isEmpty)
            XCTAssertEqual(attachedImage.mediaType, .png)
            XCTAssertEqual(attachedImage.originalSize.width, 200)
            XCTAssertEqual(attachedImage.originalSize.height, 150)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testProcessImageCreatesValidUUID() {
        let image = createTestImage(width: 100, height: 100)

        let result = processor.process(image: image)

        if case .success(let attachedImage) = result {
            XCTAssertNotEqual(attachedImage.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        } else {
            XCTFail("Expected success")
        }
    }

    func testProcessImageCreatesThumbnail() {
        let image = createTestImage(width: 500, height: 400)

        let result = processor.process(image: image)

        if case .success(let attachedImage) = result {
            let thumbnail = attachedImage.thumbnail
            XCTAssertLessThanOrEqual(thumbnail.size.width, ImageProcessor.defaultThumbnailSize)
            XCTAssertLessThanOrEqual(thumbnail.size.height, ImageProcessor.defaultThumbnailSize)
        } else {
            XCTFail("Expected success")
        }
    }

    func testProcessImageWithCustomThumbnailSize() {
        let image = createTestImage(width: 500, height: 400)
        let customSize: CGFloat = 60

        let result = processor.process(image: image, thumbnailSize: customSize)

        if case .success(let attachedImage) = result {
            let thumbnail = attachedImage.thumbnail
            XCTAssertLessThanOrEqual(thumbnail.size.width, customSize)
            XCTAssertLessThanOrEqual(thumbnail.size.height, customSize)
        } else {
            XCTFail("Expected success")
        }
    }

    func testProcessSmallImageDoesNotEnlargeThumbnail() {
        let image = createTestImage(width: 50, height: 40)

        let result = processor.process(image: image, thumbnailSize: 120)

        if case .success(let attachedImage) = result {
            let thumbnail = attachedImage.thumbnail
            XCTAssertEqual(thumbnail.size.width, 50)
            XCTAssertEqual(thumbnail.size.height, 40)
        } else {
            XCTFail("Expected success")
        }
    }

    func testProcessImageMaintainsAspectRatio() {
        let image = createTestImage(width: 800, height: 400)

        let result = processor.process(image: image, thumbnailSize: 120)

        if case .success(let attachedImage) = result {
            let thumbnail = attachedImage.thumbnail
            let aspectRatio = thumbnail.size.width / thumbnail.size.height
            XCTAssertEqual(aspectRatio, 2.0, accuracy: 0.01)
        } else {
            XCTFail("Expected success")
        }
    }

    func testProcessSquareImage() {
        let image = createTestImage(width: 300, height: 300)

        let result = processor.process(image: image, thumbnailSize: 120)

        if case .success(let attachedImage) = result {
            let thumbnail = attachedImage.thumbnail
            XCTAssertEqual(thumbnail.size.width, thumbnail.size.height, accuracy: 0.01)
            XCTAssertLessThanOrEqual(thumbnail.size.width, 120)
        } else {
            XCTFail("Expected success")
        }
    }

    // MARK: - Process Data Tests

    func testProcessValidPNGData() throws {
        let pngData = try XCTUnwrap(createImageData(width: 100, height: 80, format: .png))

        let result = processor.process(data: pngData)

        switch result {
        case .success(let attachedImage):
            XCTAssertEqual(attachedImage.mediaType, .png)
            XCTAssertFalse(attachedImage.data.isEmpty)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testProcessValidJPEGData() throws {
        let jpegData = try XCTUnwrap(createImageData(width: 100, height: 80, format: .jpeg))

        let result = processor.process(data: jpegData)

        switch result {
        case .success(let attachedImage):
            XCTAssertFalse(attachedImage.data.isEmpty)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testProcessInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])

        let result = processor.process(data: invalidData)

        switch result {
        case .success:
            XCTFail("Expected failure for invalid data")
        case .failure(let error):
            XCTAssertEqual(error, .invalidImageData)
        }
    }

    func testProcessEmptyData() {
        let emptyData = Data()

        let result = processor.process(data: emptyData)

        switch result {
        case .success:
            XCTFail("Expected failure for empty data")
        case .failure(let error):
            XCTAssertEqual(error, .invalidImageData)
        }
    }

    // MARK: - Size Limit Tests

    func testProcessImageWithinSizeLimit() throws {
        let pngData = try XCTUnwrap(createImageData(width: 100, height: 100))
        let sizeLimit = pngData.count + 1000

        let result = processor.process(data: pngData, maxSize: sizeLimit)

        if case .failure = result {
            XCTFail("Expected success for image within size limit")
        }
    }

    func testProcessImageExceedingSizeLimitReturnsError() {
        let image = createTestImage(width: 100, height: 100)
        let tinyLimit = 100

        let result = processor.process(image: image, maxSize: tinyLimit)

        switch result {
        case .success:
            XCTFail("Expected failure for image exceeding size limit")
        case .failure(let error):
            if case .imageTooLarge(let size, let limit) = error {
                XCTAssertGreaterThan(size, limit)
                XCTAssertEqual(limit, tinyLimit)
            } else {
                XCTFail("Expected imageTooLarge error but got \(error)")
            }
        }
    }

    func testProcessImageExactlyAtSizeLimit() throws {
        let pngData = try XCTUnwrap(createImageData(width: 100, height: 100))

        let result = processor.process(data: pngData, maxSize: pngData.count)

        if case .failure = result {
            XCTFail("Expected success for image exactly at size limit")
        }
    }

    func testDefaultMaxSizeIs20MB() {
        XCTAssertEqual(ImageProcessor.maxImageSize, 20 * 1024 * 1024)
    }

    // MARK: - Thumbnail Size Tests

    func testDefaultThumbnailSizeIs120() {
        XCTAssertEqual(ImageProcessor.defaultThumbnailSize, 120)
    }

    func testThumbnailForWideImage() {
        let image = createTestImage(width: 1000, height: 200)

        let result = processor.process(image: image, thumbnailSize: 120)

        if case .success(let attachedImage) = result {
            let thumbnail = attachedImage.thumbnail
            XCTAssertEqual(thumbnail.size.width, 120, accuracy: 0.01)
            XCTAssertEqual(thumbnail.size.height, 24, accuracy: 0.01)
        } else {
            XCTFail("Expected success")
        }
    }

    func testThumbnailForTallImage() {
        let image = createTestImage(width: 200, height: 1000)

        let result = processor.process(image: image, thumbnailSize: 120)

        if case .success(let attachedImage) = result {
            let thumbnail = attachedImage.thumbnail
            XCTAssertEqual(thumbnail.size.width, 24, accuracy: 0.01)
            XCTAssertEqual(thumbnail.size.height, 120, accuracy: 0.01)
        } else {
            XCTFail("Expected success")
        }
    }

    // MARK: - AttachedImage Output Tests

    func testAttachedImageHasBase64Encoded() {
        let image = createTestImage(width: 100, height: 100)

        let result = processor.process(image: image)

        if case .success(let attachedImage) = result {
            XCTAssertFalse(attachedImage.base64Encoded.isEmpty)
            let decodedData = Data(base64Encoded: attachedImage.base64Encoded)
            XCTAssertNotNil(decodedData)
            XCTAssertEqual(decodedData, attachedImage.data)
        } else {
            XCTFail("Expected success")
        }
    }

    func testAttachedImageFileSizeDescription() {
        let image = createTestImage(width: 100, height: 100)

        let result = processor.process(image: image)

        if case .success(let attachedImage) = result {
            let description = attachedImage.fileSizeDescription
            XCTAssertFalse(description.isEmpty)
            XCTAssertTrue(description.contains("B") || description.contains("KB") || description.contains("MB"))
        } else {
            XCTFail("Expected success")
        }
    }

    func testAttachedImageDimensionsDescription() {
        let image = createTestImage(width: 800, height: 600)

        let result = processor.process(image: image)

        if case .success(let attachedImage) = result {
            XCTAssertEqual(attachedImage.dimensionsDescription, "800 × 600")
        } else {
            XCTFail("Expected success")
        }
    }

    // MARK: - Multiple Process Calls

    func testMultipleProcessCallsProduceUniqueIDs() {
        let image = createTestImage(width: 100, height: 100)

        let result1 = processor.process(image: image)
        let result2 = processor.process(image: image)

        if case .success(let attachedImage1) = result1,
           case .success(let attachedImage2) = result2 {
            XCTAssertNotEqual(attachedImage1.id, attachedImage2.id)
        } else {
            XCTFail("Expected both to succeed")
        }
    }

    // MARK: - Error Equatable Tests

    func testImageProcessorErrorEquatable() {
        XCTAssertEqual(ImageProcessorError.invalidImageData, ImageProcessorError.invalidImageData)
        XCTAssertEqual(ImageProcessorError.unsupportedFormat, ImageProcessorError.unsupportedFormat)
        XCTAssertEqual(ImageProcessorError.thumbnailCreationFailed, ImageProcessorError.thumbnailCreationFailed)
        XCTAssertEqual(
            ImageProcessorError.imageTooLarge(size: 100, limit: 50),
            ImageProcessorError.imageTooLarge(size: 100, limit: 50)
        )

        XCTAssertNotEqual(ImageProcessorError.invalidImageData, ImageProcessorError.unsupportedFormat)
        XCTAssertNotEqual(
            ImageProcessorError.imageTooLarge(size: 100, limit: 50),
            ImageProcessorError.imageTooLarge(size: 200, limit: 50)
        )
    }

    // MARK: - Error Display Message Tests

    func testInvalidImageDataDisplayMessage() {
        let error = ImageProcessorError.invalidImageData
        XCTAssertEqual(error.displayMessage, "Could not read image data")
    }

    func testUnsupportedFormatDisplayMessage() {
        let error = ImageProcessorError.unsupportedFormat
        XCTAssertEqual(error.displayMessage, "Only PNG and JPEG images are supported")
    }

    func testImageTooLargeDisplayMessage() {
        let error = ImageProcessorError.imageTooLarge(size: 25 * 1024 * 1024, limit: 20 * 1024 * 1024)
        let message = error.displayMessage
        XCTAssertTrue(message.contains("25.0 MB"))
        XCTAssertTrue(message.contains("20 MB"))
    }

    func testThumbnailCreationFailedDisplayMessage() {
        let error = ImageProcessorError.thumbnailCreationFailed
        XCTAssertEqual(error.displayMessage, "Failed to create image thumbnail")
    }

    // MARK: - Edge Cases

    func testProcessVerySmallImage() {
        let image = createTestImage(width: 1, height: 1)

        let result = processor.process(image: image)

        switch result {
        case .success(let attachedImage):
            XCTAssertEqual(attachedImage.originalSize.width, 1)
            XCTAssertEqual(attachedImage.originalSize.height, 1)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testProcessLargeImage() {
        let image = createTestImage(width: 4000, height: 3000)

        let result = processor.process(image: image)

        switch result {
        case .success(let attachedImage):
            XCTAssertEqual(attachedImage.originalSize.width, 4000)
            XCTAssertEqual(attachedImage.originalSize.height, 3000)
            XCTAssertLessThanOrEqual(attachedImage.thumbnail.size.width, ImageProcessor.defaultThumbnailSize)
            XCTAssertLessThanOrEqual(attachedImage.thumbnail.size.height, ImageProcessor.defaultThumbnailSize)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testProcessorIsSendable() {
        let processor = ImageProcessor()
        let image1 = createTestImage(width: 100, height: 100)
        let image2 = createTestImage(width: 200, height: 200)
        let image3 = createTestImage(width: 150, height: 150)
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 3

        Task.detached {
            _ = processor.process(image: image1)
            expectation.fulfill()
        }

        Task.detached {
            _ = processor.process(image: image2)
            expectation.fulfill()
        }

        Task.detached {
            _ = processor.process(image: image3)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
