import Foundation
import AppKit

// MARK: - Image Processor Error

enum ImageProcessorError: Error, Equatable {
    case invalidImageData
    case unsupportedFormat
    case imageTooLarge(size: Int, limit: Int)
    case thumbnailCreationFailed
}

// MARK: - Image Processor

final class ImageProcessor: Sendable {

    static let defaultThumbnailSize: CGFloat = 120
    static let maxImageSize: Int = 20 * 1024 * 1024  // 20MB

    func process(
        image: NSImage,
        thumbnailSize: CGFloat = ImageProcessor.defaultThumbnailSize,
        maxSize: Int = ImageProcessor.maxImageSize
    ) -> Result<AttachedImage, ImageProcessorError> {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return .failure(.invalidImageData)
        }

        let (imageData, mediaType) = extractImageData(from: bitmapRep)

        guard let data = imageData, let type = mediaType else {
            return .failure(.unsupportedFormat)
        }

        if data.count > maxSize {
            return .failure(.imageTooLarge(size: data.count, limit: maxSize))
        }

        guard let thumbnail = createThumbnail(from: image, size: thumbnailSize) else {
            return .failure(.thumbnailCreationFailed)
        }

        let originalSize = CGSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh)

        let attachedImage = AttachedImage(
            data: data,
            mediaType: type,
            thumbnail: thumbnail,
            originalSize: originalSize
        )

        return .success(attachedImage)
    }

    func process(
        data: Data,
        thumbnailSize: CGFloat = ImageProcessor.defaultThumbnailSize,
        maxSize: Int = ImageProcessor.maxImageSize
    ) -> Result<AttachedImage, ImageProcessorError> {
        guard let image = NSImage(data: data) else {
            return .failure(.invalidImageData)
        }
        return process(image: image, thumbnailSize: thumbnailSize, maxSize: maxSize)
    }

    // MARK: - Private

    private func extractImageData(from bitmapRep: NSBitmapImageRep) -> (Data?, ImageMediaType?) {
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            return (pngData, .png)
        }

        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
            return (jpegData, .jpeg)
        }

        return (nil, nil)
    }

    private func createThumbnail(from image: NSImage, size: CGFloat) -> NSImage? {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else {
            return nil
        }

        let scale = min(size / originalSize.width, size / originalSize.height, 1.0)
        let thumbnailWidth = originalSize.width * scale
        let thumbnailHeight = originalSize.height * scale
        let thumbnailSize = NSSize(width: thumbnailWidth, height: thumbnailHeight)

        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: thumbnailSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()

        return thumbnail
    }
}
