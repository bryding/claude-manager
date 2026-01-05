import SwiftUI

struct TabItemView: View {
    // MARK: - Properties

    let tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    // MARK: - Local State

    @State private var isHovering = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            statusDot
            labelText
            closeButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundFill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(borderColor, lineWidth: isActive ? 1 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: - Subviews

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var labelText: some View {
        Text(tab.label)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 120, alignment: .leading)
            .font(.callout)
            .foregroundStyle(isActive ? .primary : .secondary)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isHovering || isActive ? 1 : 0)
    }

    // MARK: - Styling

    private var backgroundFill: some View {
        Group {
            if isActive {
                Color.accentColor.opacity(0.15)
            } else if isHovering {
                Color.primary.opacity(0.05)
            } else {
                Color.clear
            }
        }
    }

    private var borderColor: Color {
        isActive ? .accentColor.opacity(0.3) : .clear
    }

    private var statusColor: Color {
        let phase = tab.context.phase
        let hasQuestion = tab.context.pendingQuestion != nil

        if phase == .conductingInterview && hasQuestion {
            return .yellow
        }

        return phase.statusColor
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Active Tab") {
    let tab = Tab.create(
        label: "Feature Implementation",
        userPreferences: UserPreferences()
    )
    tab.context.phase = .executingTask

    return TabItemView(
        tab: tab,
        isActive: true,
        onSelect: {},
        onClose: {}
    )
    .padding()
}

#Preview("Inactive Tab") {
    let tab = Tab.create(
        label: "Another Feature",
        userPreferences: UserPreferences()
    )
    tab.context.phase = .idle

    return TabItemView(
        tab: tab,
        isActive: false,
        onSelect: {},
        onClose: {}
    )
    .padding()
}

#Preview("Tab States") {
    VStack(spacing: 12) {
        Group {
            makeTabItem(label: "Idle", phase: .idle, isActive: false)
            makeTabItem(label: "Executing", phase: .executingTask, isActive: true)
            makeTabItem(label: "Completed", phase: .completed, isActive: false)
            makeTabItem(label: "Failed", phase: .failed, isActive: false)
            makeTabItem(label: "Waiting", phase: .waitingForUser, isActive: false)
        }
    }
    .padding()
}

@MainActor
private func makeTabItem(label: String, phase: ExecutionPhase, isActive: Bool) -> some View {
    let tab = Tab.create(label: label, userPreferences: UserPreferences())
    tab.context.phase = phase
    return TabItemView(tab: tab, isActive: isActive, onSelect: {}, onClose: {})
}
#endif
