import SwiftUI

struct EmptyTabView: View {
    // MARK: - Properties

    @Environment(AppState.self) private var appState

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Open Tabs")
                .font(.title2)
                .foregroundStyle(.secondary)

            Button("Create New Tab") {
                appState.tabManager.createTab()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Empty Tab View") {
    let userPreferences = UserPreferences()
    let tabManager = TabManager(userPreferences: userPreferences)
    let appState = AppState(tabManager: tabManager, userPreferences: userPreferences)

    if let tab = tabManager.tabs.first {
        tabManager.closeTab(tab)
    }

    return EmptyTabView()
        .environment(appState)
        .frame(width: 600, height: 400)
}
#endif
