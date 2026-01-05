import Foundation

@MainActor
@Observable
final class AppState {
    // MARK: - Properties

    let tabManager: TabManager
    let userPreferences: UserPreferences

    // MARK: - Computed Properties (backward compatibility)

    var activeTab: Tab? {
        tabManager.activeTab
    }

    var context: ExecutionContext? {
        activeTab?.context
    }

    var stateMachine: ExecutionStateMachine? {
        activeTab?.stateMachine
    }

    // MARK: - Initialization

    init(
        tabManager: TabManager? = nil,
        userPreferences: UserPreferences? = nil,
        createInitialTab: Bool = true
    ) {
        let resolvedPreferences = userPreferences ?? UserPreferences()
        self.userPreferences = resolvedPreferences
        self.tabManager = tabManager ?? TabManager(userPreferences: resolvedPreferences)

        // Create initial tab if none exist and flag is set
        if createInitialTab && self.tabManager.tabs.isEmpty {
            self.tabManager.createTab()
        }
    }
}
