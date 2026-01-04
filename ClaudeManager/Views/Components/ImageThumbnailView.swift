import SwiftUI
import AppKit

struct ImageThumbnailView: View {
    let image: AttachedImage
    var onRemove: (() -> Void)?

    @State private var isHovering = false

    private let thumbnailSize: CGFloat = 80

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
                .opacity(isHovering ? 1 : 0)
                .scaleEffect(isHovering ? 1 : 0.5)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("\(image.dimensionsDescription) • \(image.fileSizeDescription)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Image Thumbnail") {
    let thumbnail = NSImage(size: NSSize(width: 120, height: 120), flipped: false) { rect in
        NSColor.systemBlue.setFill()
        rect.fill()
        return true
    }

    let attachedImage = AttachedImage(
        data: Data(repeating: 0, count: 150_000),
        mediaType: .png,
        thumbnail: thumbnail,
        originalSize: CGSize(width: 1920, height: 1080)
    )

    HStack(spacing: 16) {
        ImageThumbnailView(image: attachedImage) {
            print("Remove tapped")
        }

        ImageThumbnailView(image: attachedImage, onRemove: nil)
    }
    .padding(32)
}
#endif
