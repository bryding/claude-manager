import SwiftUI

struct TabBarView: View {
    // MARK: - Properties

    @Bindable var tabManager: TabManager

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabManager.tabs) { tab in
                    TabItemView(
                        tab: tab,
                        isActive: tab.id == tabManager.activeTabId,
                        onSelect: { tabManager.selectTab(tab) },
                        onClose: {
                            Task {
                                try? await tabManager.closeTab(tab)
                            }
                        }
                    )
                }

                addTabButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Subviews

    private var addTabButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .onTapGesture {
                tabManager.createTab()
            }
            .help("New Tab")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Tab Bar") {
    let tabManager = TabManager(userPreferences: UserPreferences())
    tabManager.createTab()
    tabManager.tabs[0].label = "Feature A"
    tabManager.tabs[0].context.phase = .executingTask

    tabManager.createTab()
    tabManager.tabs[1].label = "Feature B"
    tabManager.tabs[1].context.phase = .idle

    tabManager.activeTabId = tabManager.tabs[0].id

    return TabBarView(tabManager: tabManager)
        .frame(width: 400)
}

#Preview("Single Tab") {
    let tabManager = TabManager(userPreferences: UserPreferences())
    tabManager.createTab()
    tabManager.tabs[0].label = "My Feature"

    return TabBarView(tabManager: tabManager)
        .frame(width: 400)
}

#Preview("Many Tabs") {
    let tabManager = TabManager(userPreferences: UserPreferences())
    let phases: [ExecutionPhase] = [.idle, .executingTask, .completed, .failed, .waitingForUser]

    for i in 0..<8 {
        tabManager.createTab()
        tabManager.tabs[i].label = "Feature \(i + 1)"
        tabManager.tabs[i].context.phase = phases[i % phases.count]
    }

    tabManager.activeTabId = tabManager.tabs[2].id

    return TabBarView(tabManager: tabManager)
        .frame(width: 500)
}
#endif
