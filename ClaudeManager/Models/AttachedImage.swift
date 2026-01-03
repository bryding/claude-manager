import Foundation
import AppKit

// MARK: - Image Media Type

enum ImageMediaType: String, Sendable {
    case png = "image/png"
    case jpeg = "image/jpeg"

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpeg"
        }
    }
}

// MARK: - Attached Image

struct AttachedImage: Identifiable, Sendable {
    let id: UUID
    let data: Data
    let mediaType: ImageMediaType
    let thumbnail: NSImage
    let originalSize: CGSize

    init(
        id: UUID = UUID(),
        data: Data,
        mediaType: ImageMediaType,
        thumbnail: NSImage,
        originalSize: CGSize
    ) {
        self.id = id
        self.data = data
        self.mediaType = mediaType
        self.thumbnail = thumbnail
        self.originalSize = originalSize
    }

    var base64Encoded: String {
        data.base64EncodedString()
    }

    var fileSizeDescription: String {
        let byteCount = data.count
        if byteCount < 1024 {
            return "\(byteCount) B"
        } else if byteCount < 1024 * 1024 {
            let kb = Double(byteCount) / 1024.0
            return String(format: "%.1f KB", kb)
        } else {
            let mb = Double(byteCount) / (1024.0 * 1024.0)
            return String(format: "%.1f MB", mb)
        }
    }

    var dimensionsDescription: String {
        "\(Int(originalSize.width)) × \(Int(originalSize.height))"
    }
}

// MARK: - Equatable

extension AttachedImage: Equatable {
    static func == (lhs: AttachedImage, rhs: AttachedImage) -> Bool {
        lhs.id == rhs.id
    }
}
