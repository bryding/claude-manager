import SwiftUI

struct LogView: View {
    let logs: [LogEntry]

    @State private var searchText = ""
    @State private var selectedFilter: LogFilter = .all
    @State private var autoScroll = true

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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { entry in
                            LogEntryView(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: logs.count) { _, _ in
                    if autoScroll, let lastLog = filteredLogs.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
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

            Spacer()

            Toggle(isOn: $autoScroll) {
                Label("Auto-scroll", systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
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

// MARK: - Log Entry View

private struct LogEntryView: View {
    let entry: LogEntry

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        if entry.type == .separator {
            separatorView
        } else {
            regularEntryView
        }
    }

    private var separatorView: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)

            Text(entry.message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 12)
    }

    private var regularEntryView: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .leading)

            typeBadge
                .frame(width: 70, alignment: .leading)

            Text(entry.message)
                .font(.body.monospaced())
                .foregroundStyle(entry.type.color)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private var typeBadge: some View {
        Text(entry.type.badgeLabel)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(entry.type.color.opacity(0.15))
            .foregroundStyle(entry.type.color)
            .cornerRadius(4)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Log View") {
    LogView(logs: [
        LogEntry(phase: .executingTask, type: .info, message: "Starting task execution..."),
        LogEntry(phase: .executingTask, type: .output, message: "Reading file: /src/main.swift"),
        LogEntry(phase: .executingTask, type: .toolUse, message: "Read: ClaudeManager/Models/Plan.swift"),
        LogEntry(phase: .executingTask, type: .output, message: "Analyzing code structure and dependencies"),
        LogEntry(phase: .executingTask, type: .toolUse, message: "Edit: ClaudeManager/Views/SetupView.swift"),
        LogEntry(phase: .executingTask, type: .error, message: "Build failed: Type 'Foo' has no member 'bar'"),
        LogEntry(phase: .executingTask, type: .output, message: "Fixing compilation error..."),
        LogEntry(phase: .executingTask, type: .result, message: "Task completed successfully"),
    ])
    .frame(width: 800, height: 400)
}

#Preview("Log View Empty") {
    LogView(logs: [])
        .frame(width: 800, height: 400)
}
#endif
