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
    func createTab(projectPath: URL? = nil) async throws -> Tab {
        var worktreeInfo: WorktreeInfo?
        var effectivePath = projectPath

        if let projectPath {
            let isDuplicate = tabs.contains { tab in
                tab.context.projectPath == projectPath ||
                tab.worktreeInfo?.originalRepoPath == projectPath
            }

            if isDuplicate {
                worktreeInfo = try await worktreeService.createWorktree(from: projectPath)
                effectivePath = worktreeInfo?.worktreePath
            }
        }

        let tab = Tab.create(
            userPreferences: userPreferences,
            worktreeInfo: worktreeInfo
        )

        if let effectivePath {
            tab.context.projectPath = effectivePath
        }

        tabs.append(tab)
        activeTabId = tab.id

        return tab
    }

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
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }

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
