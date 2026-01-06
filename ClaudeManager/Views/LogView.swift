import AppKit
import SwiftUI

struct LogView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab

    // MARK: - State

    @State private var searchText = ""
    @State private var selectedFilter: LogFilter = .all
    @State private var autoScroll = true
    @State private var showCopiedFeedback = false

    // MARK: - Computed Properties

    private var logs: [LogEntry] {
        tab.context.logs
    }

    private var filteredLogs: [LogEntry] {
        logs.filter { entry in
            let matchesFilter = selectedFilter == .all || selectedFilter.matches(entry.type)
            let matchesSearch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
                .padding(8)

            Divider()

            SelectableLogTextView(logs: filteredLogs, autoScroll: autoScroll)

            Divider()

            ManualInputView()
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.LogView.logView)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier(AccessibilityIdentifiers.LogView.logSearchField)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary)
            .cornerRadius(6)

            Picker("Filter", selection: $selectedFilter) {
                ForEach(LogFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .accessibilityIdentifier(AccessibilityIdentifiers.LogView.logFilterPicker)

            Spacer()

            Toggle(isOn: $autoScroll) {
                Label("Auto-scroll", systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .accessibilityIdentifier(AccessibilityIdentifiers.LogView.autoScrollToggle)

            Button {
                copyFilteredLogs()
            } label: {
                Label(
                    showCopiedFeedback ? "Copied!" : "Copy",
                    systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)
            .disabled(filteredLogs.isEmpty)
            .accessibilityIdentifier(AccessibilityIdentifiers.LogView.copyAllButton)
        }
    }

    // MARK: - Private Methods

    private func copyFilteredLogs() {
        let formattedLogs = filteredLogs.map { entry in
            let timestamp = LogTimeFormatter.shared.string(from: entry.timestamp)
            let type = entry.type.badgeLabel.padding(toLength: 7, withPad: " ", startingAt: 0)
            return "[\(timestamp)] [\(type)] \(entry.message)"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedLogs, forType: .string)

        // Show feedback
        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedFeedback = false
        }
    }
}

// MARK: - Selectable Log Text View

private struct SelectableLogTextView: NSViewRepresentable {
    let logs: [LogEntry]
    let autoScroll: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Configure text container for proper wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let attributedString = buildAttributedString(for: logs)
        textView.textStorage?.setAttributedString(attributedString)

        if autoScroll && !logs.isEmpty {
            DispatchQueue.main.async {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }

    private func buildAttributedString(for logs: [LogEntry]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let messageFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        let timestampFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let badgeFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        paragraphStyle.paragraphSpacing = 6
        paragraphStyle.lineBreakMode = .byWordWrapping

        // Message paragraph style with indent for wrapped lines
        // This ensures wrapped text aligns under the message start, not the timestamp
        let messageParagraphStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        messageParagraphStyle.headIndent = 145 // Approximate width of "HH:mm:ss.SSS badge  "

        for (index, entry) in logs.enumerated() {
            if entry.type == .separator {
                // Add separator line
                let separatorAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraphStyle
                ]
                let separator = NSAttributedString(
                    string: "─────────── \(entry.message) ───────────\n",
                    attributes: separatorAttrs
                )
                result.append(separator)
            } else {
                // Timestamp
                let timestamp = LogTimeFormatter.shared.string(from: entry.timestamp)
                let timestampAttrs: [NSAttributedString.Key: Any] = [
                    .font: timestampFont,
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]
                result.append(NSAttributedString(string: timestamp, attributes: timestampAttrs))

                // Space
                result.append(NSAttributedString(string: " "))

                // Type badge - subtle, lowercase, dimmed
                let badgeAttrs: [NSAttributedString.Key: Any] = [
                    .font: badgeFont,
                    .foregroundColor: nsColor(for: entry.type).withAlphaComponent(0.6)
                ]
                let badge = entry.type.badgeLabel.lowercased()
                let paddedBadge = badge.padding(toLength: 6, withPad: " ", startingAt: 0)
                result.append(NSAttributedString(string: paddedBadge, attributes: badgeAttrs))

                // Space
                result.append(NSAttributedString(string: " "))

                // Message - prominent, full color with proper wrapping
                let messageAttrs: [NSAttributedString.Key: Any] = [
                    .font: messageFont,
                    .foregroundColor: nsColor(for: entry.type),
                    .paragraphStyle: messageParagraphStyle
                ]
                result.append(NSAttributedString(string: entry.message, attributes: messageAttrs))

                // Newline (except for last entry)
                if index < logs.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
            }
        }

        return result
    }

    private func nsColor(for type: LogType) -> NSColor {
        switch type {
        case .output:
            return NSColor.labelColor
        case .toolUse:
            return NSColor.systemBlue
        case .result:
            return NSColor.systemGreen
        case .error:
            return NSColor.systemRed
        case .info:
            return NSColor.secondaryLabelColor
        case .separator:
            return NSColor.secondaryLabelColor
        }
    }
}

// MARK: - Log Filter

private enum LogFilter: String, CaseIterable, Identifiable {
    case all
    case output
    case toolUse
    case error

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .output: return "Output"
        case .toolUse: return "Tool Use"
        case .error: return "Error"
        }
    }

    func matches(_ type: LogType) -> Bool {
        switch self {
        case .all: return true
        case .output: return type == .output
        case .toolUse: return type == .toolUse
        case .error: return type == .error
        }
    }
}

// MARK: - Log Time Formatter

private enum LogTimeFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
#Preview("Log View") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.sessionId = "test-session"
    tab.context.phase = .executingTask
    tab.context.logs = [
        LogEntry(phase: .executingTask, type: .info, message: "Starting task execution..."),
        LogEntry(phase: .executingTask, type: .output, message: "Reading file: /src/main.swift"),
        LogEntry(phase: .executingTask, type: .toolUse, message: "Read: ClaudeManager/Models/Plan.swift"),
        LogEntry(phase: .executingTask, type: .output, message: "Analyzing code structure and dependencies"),
        LogEntry(phase: .executingTask, type: .toolUse, message: "Edit: ClaudeManager/Views/SetupView.swift"),
        LogEntry(phase: .executingTask, type: .error, message: "Build failed: Type 'Foo' has no member 'bar'"),
        LogEntry(phase: .executingTask, type: .output, message: "Fixing compilation error..."),
        LogEntry(phase: .executingTask, type: .result, message: "Task completed successfully"),
    ]
    return LogView()
        .environment(tab)
        .frame(width: 800, height: 400)
}

#Preview("Log View Empty") {
    let tab = Tab.create(userPreferences: UserPreferences())
    return LogView()
        .environment(tab)
        .frame(width: 800, height: 400)
}
#endif
