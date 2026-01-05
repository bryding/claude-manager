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

    /// Creates a new tab with a project path.
    /// If the project path is already in use by another tab, a worktree is created.
    @discardableResult
    func createTab(projectPath: URL) async throws -> Tab {
        let tab = Tab.create(userPreferences: userPreferences)
        tabs.append(tab)
        activeTabId = tab.id
        try await setProjectPath(projectPath, for: tab)
        return tab
    }

    /// Creates a new tab synchronously without worktree support.
    /// Use this only when no project path is needed at creation time.
    @discardableResult
    func createTab() -> Tab {
        let tab = Tab.create(userPreferences: userPreferences)
        tabs.append(tab)
        activeTabId = tab.id
        return tab
    }

    /// Sets the project path for a tab, creating a worktree if the project is already in use.
    func setProjectPath(_ projectPath: URL, for tab: Tab) async throws {
        let isDuplicate = tabs.contains { existingTab in
            guard existingTab.id != tab.id else { return false }
            return existingTab.context.projectPath == projectPath ||
                   existingTab.worktreeInfo?.originalRepoPath == projectPath
        }

        if isDuplicate {
            let worktreeInfo = try await worktreeService.createWorktree(from: projectPath)
            tab.worktreeInfo = worktreeInfo
            tab.context.projectPath = worktreeInfo.worktreePath
        } else {
            tab.worktreeInfo = nil
            tab.context.projectPath = projectPath
        }
    }

    /// Closes a tab, stopping any running execution and cleaning up its worktree if present.
    func closeTab(_ tab: Tab) async throws {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }

        if tab.context.canStop {
            tab.stateMachine.stop()
        }

        if let worktreeInfo = tab.worktreeInfo {
            try await worktreeService.removeWorktree(worktreeInfo)
        }

        let wasActive = activeTabId == tab.id
        tabs.remove(at: index)

        if wasActive {
            if tabs.indices.contains(index) {
                activeTabId = tabs[index].id
            } else {
                activeTabId = tabs.last?.id
            }
        }
    }

    func selectTab(_ tab: Tab) {
        guard tabs.contains(where: { $0.id == tab.id }) else { return }
        activeTabId = tab.id
    }
}
