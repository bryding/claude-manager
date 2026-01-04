import Foundation

@MainActor
@Observable
final class TabManager {
    // MARK: - Properties

    private(set) var tabs: [Tab] = []
    var activeTabId: UUID?

    private let userPreferences: UserPreferences
    private let worktreeService: any WorktreeServiceProtocol

    // MARK: - Computed Properties

    var activeTab: Tab? {
        guard let activeTabId else { return nil }
        return tabs.first { $0.id == activeTabId }
    }

    // MARK: - Initialization

    init(
        userPreferences: UserPreferences? = nil,
        worktreeService: (any WorktreeServiceProtocol)? = nil
    ) {
        self.userPreferences = userPreferences ?? UserPreferences()
        self.worktreeService = worktreeService ?? WorktreeService()
    }

    // MARK: - Tab Management

    @discardableResult
    func createTab(projectPath: URL? = nil) -> Tab {
        let tab = Tab.create(userPreferences: userPreferences)

        if let projectPath {
            tab.context.projectPath = projectPath
        }

        tabs.append(tab)
        activeTabId = tab.id

        return tab
    }

    func closeTab(_ tab: Tab) {
        tabs.removeAll { $0.id == tab.id }

        if activeTabId == tab.id {
            activeTabId = tabs.first?.id
        }
    }

    func selectTab(_ tab: Tab) {
        activeTabId = tab.id
    }
}
