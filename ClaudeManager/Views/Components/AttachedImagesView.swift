import SwiftUI
import AppKit

struct AttachedImagesView: View {
    let images: [AttachedImage]
    var onRemove: ((UUID) -> Void)?
    var onRemoveAll: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(images) { image in
                        ImageThumbnailView(image: image) {
                            onRemove?(image.id)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Label(imageCountLabel, systemImage: "photo.stack")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            if images.count > 1, let onRemoveAll {
                Button("Remove All", action: onRemoveAll)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
            }
        }
    }

    private var imageCountLabel: String {
        let count = images.count
        return count == 1 ? "1 image attached" : "\(count) images attached"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Attached Images") {
    let thumbnail = NSImage(size: NSSize(width: 120, height: 120), flipped: false) { rect in
        NSColor.systemBlue.setFill()
        rect.fill()
        return true
    }

    let images = (0..<3).map { index in
        AttachedImage(
            data: Data(repeating: 0, count: 150_000 * (index + 1)),
            mediaType: index % 2 == 0 ? .png : .jpeg,
            thumbnail: thumbnail,
            originalSize: CGSize(width: 1920, height: 1080)
        )
    }

    return VStack(spacing: 24) {
        GroupBox("Multiple Images") {
            AttachedImagesView(
                images: images,
                onRemove: { id in print("Remove: \(id)") },
                onRemoveAll: { print("Remove all") }
            )
            .padding(.vertical, 8)
        }

        GroupBox("Single Image") {
            AttachedImagesView(
                images: [images[0]],
                onRemove: { id in print("Remove: \(id)") },
                onRemoveAll: { print("Remove all") }
            )
            .padding(.vertical, 8)
        }
    }
    .padding(24)
    .frame(width: 500)
}
#endif
