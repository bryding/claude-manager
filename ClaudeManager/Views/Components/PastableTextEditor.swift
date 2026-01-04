import SwiftUI
import AppKit

// MARK: - PastableTextEditor

struct PastableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onImagePaste: (NSImage) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = PastableNSTextView()

        textView.delegate = context.coordinator
        textView.onImagePaste = onImagePaste
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 4, height: 8)

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        textView.registerForDraggedTypes([.png, .tiff, .fileURL])

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PastableNSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        textView.onImagePaste = onImagePaste
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PastableTextEditor

        init(_ parent: PastableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - PastableNSTextView

final class PastableNSTextView: NSTextView {
    var onImagePaste: ((NSImage) -> Void)?

    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.image")
    ]

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        if let image = extractImage(from: pasteboard) {
            onImagePaste?(image)
            return
        }

        super.paste(sender)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard

        if canExtractImage(from: pasteboard) {
            return .copy
        }

        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let image = extractImage(from: pasteboard) {
            onImagePaste?(image)
            return true
        }

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: ["public.image"]
        ]) as? [URL], let url = fileURLs.first {
            if let image = NSImage(contentsOf: url) {
                onImagePaste?(image)
                return true
            }
        }

        return super.performDragOperation(sender)
    }

    private func canExtractImage(from pasteboard: NSPasteboard) -> Bool {
        for type in Self.imageTypes {
            if pasteboard.data(forType: type) != nil {
                return true
            }
        }

        if let types = pasteboard.types, types.contains(.fileURL) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true,
                .urlReadingContentsConformToTypes: ["public.image"]
            ]) as? [URL], !urls.isEmpty {
                return true
            }
        }

        return false
    }

    private func extractImage(from pasteboard: NSPasteboard) -> NSImage? {
        for type in Self.imageTypes {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data) {
                return image
            }
        }

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: ["public.image"]
        ]) as? [URL], let url = fileURLs.first {
            return NSImage(contentsOf: url)
        }

        return nil
    }
}

// MARK: - Preview

#if DEBUG
struct PastableTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        PastableTextEditorPreviewWrapper()
            .frame(width: 400, height: 200)
            .padding()
    }
}

private struct PastableTextEditorPreviewWrapper: View {
    @State private var text = ""
    @State private var imageCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste or drop images here (count: \(imageCount))")
                .font(.callout)
                .foregroundStyle(.secondary)

            PastableTextEditor(text: $text) { _ in
                imageCount += 1
            }
            .frame(minHeight: 150)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }
}
#endif
