import SwiftUI

struct MainView: View {
    // MARK: - Properties

    @Environment(AppState.self) private var appState

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(tabManager: appState.tabManager)

            Divider()

            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentArea: some View {
        if let activeTab = appState.activeTab {
            TabContentView()
                .environment(activeTab)
        } else {
            EmptyTabView()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Main View with Tabs") {
    let appState = AppState()
    appState.tabManager.tabs[0].label = "Feature A"

    return MainView()
        .environment(appState)
        .frame(width: 900, height: 700)
}

#Preview("Main View Empty") {
    let tabManager = TabManager(userPreferences: UserPreferences())
    let appState = AppState(tabManager: tabManager)

    return MainView()
        .environment(appState)
        .frame(width: 900, height: 700)
}
#endif
