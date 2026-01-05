# Plan: Multi-Tab Support

Add custom in-app tabs to run multiple Claude Code CLI instances simultaneously. Auto-create git worktrees when opening same repo in a new tab.

---

## Tasks

### Phase 1: Models

- [x] **Task 1.1**: Create `WorktreeInfo.swift` model
  - Struct with: `id: UUID`, `originalRepoPath: URL`, `worktreePath: URL`, `branchName: String`, `createdAt: Date`
  - Conform to `Identifiable`, `Sendable`, `Equatable`
  - File: `ClaudeManager/Models/WorktreeInfo.swift`

- [x] **Task 1.2**: Create `Tab.swift` model
  - `@MainActor @Observable` class with: `id: UUID`, `label: String`, `context: ExecutionContext`, `stateMachine: ExecutionStateMachine`, `worktreeInfo: WorktreeInfo?`
  - Computed `effectiveProjectPath: URL?` returns worktree path if present, else context.projectPath
  - Factory `init` that creates fresh services (ClaudeCLIService, PlanService, GitService, BuildTestService)
  - File: `ClaudeManager/Models/Tab.swift`

### Phase 2: Services

- [x] **Task 2.1**: Create `WorktreeServiceProtocol.swift`
  - Protocol with: `createWorktree(from: URL) async throws -> WorktreeInfo`, `removeWorktree(_: WorktreeInfo) async throws`, `listWorktrees(in: URL) async throws -> [WorktreeInfo]`
  - File: `ClaudeManager/Services/Protocols/WorktreeServiceProtocol.swift`

- [x] **Task 2.2**: Create `WorktreeService.swift`
  - Implements WorktreeServiceProtocol
  - `createWorktree`: runs `git worktree add .worktrees/<uuid> -b claude-worktree-<uuid>`
  - `removeWorktree`: runs `git worktree remove <path>`
  - `listWorktrees`: runs `git worktree list --porcelain`
  - File: `ClaudeManager/Services/WorktreeService.swift`

- [x] **Task 2.3**: Create `MockWorktreeService.swift`
  - Mock implementation for testing
  - File: `ClaudeManagerTests/Mocks/MockWorktreeService.swift`

### Phase 3: State Layer

- [x] **Task 3.1**: Create `TabManager.swift`
  - `@MainActor @Observable` class
  - Properties: `tabs: [Tab]`, `activeTabId: UUID?`
  - Computed: `activeTab: Tab?`
  - Methods: `createTab(projectPath: URL?, userPreferences: UserPreferences) -> Tab`, `closeTab(_: Tab)`, `selectTab(_: Tab)`
  - Inject WorktreeService, detect duplicate projectPath before creating tab
  - File: `ClaudeManager/State/TabManager.swift`

- [x] **Task 3.2**: Refactor `AppState.swift`
  - Replace `context` and `stateMachine` with `tabManager: TabManager`
  - Keep `userPreferences` as shared
  - Add computed `activeTab: Tab?`, `context: ExecutionContext?`, `stateMachine: ExecutionStateMachine?`
  - Update init to create TabManager with one initial tab
  - File: `ClaudeManager/State/AppState.swift`

### Phase 4: Tab Bar UI

- [x] **Task 4.1**: Create `TabItemView.swift`
  - Parameters: `tab: Tab`, `isActive: Bool`, `onSelect: () -> Void`, `onClose: () -> Void`
  - Display: label (truncated), status dot (color by phase), close button (X)
  - Styling: highlight background when active, hover effects
  - File: `ClaudeManager/Views/Components/TabItemView.swift`

- [x] **Task 4.2**: Create `TabBarView.swift`
  - Horizontal ScrollView of TabItemView for each tab
  - "+" button at end to create new tab
  - Wire up selection and close actions to TabManager
  - File: `ClaudeManager/Views/Components/TabBarView.swift`

### Phase 5: View Integration

- [ ] **Task 5.1**: Create `MainView.swift`
  - VStack: TabBarView, Divider, content area
  - Content: if activeTab exists show TabContentView, else show EmptyTabView
  - Pass activeTab into environment for child views
  - File: `ClaudeManager/Views/MainView.swift`

- [ ] **Task 5.2**: Create `TabContentView.swift`
  - Accepts Tab via environment
  - Contains existing ContentView logic (SetupView vs ExecutionView switch)
  - Handles sheets for pendingQuestion and pendingTaskFailure
  - File: `ClaudeManager/Views/TabContentView.swift`

- [ ] **Task 5.3**: Create `EmptyTabView.swift`
  - Shown when no tabs exist
  - "Create New Tab" button
  - File: `ClaudeManager/Views/EmptyTabView.swift`

- [ ] **Task 5.4**: Update `ClaudeManagerApp.swift`
  - Use MainView as root instead of ContentView
  - Update menu commands to use `appState.activeTab?.context` and `appState.activeTab?.stateMachine`
  - Add New Tab command (⌘T)
  - Add Close Tab command (⌘W)
  - File: `ClaudeManager/ClaudeManagerApp.swift`

- [x] **Task 5.5**: Update `ContentView.swift`
  - Accept Tab via `@Environment(Tab.self)` instead of AppState
  - Use `tab.context` and `tab.stateMachine`
  - File: `ClaudeManager/ContentView.swift`

### Phase 6: Child View Updates

- [x] **Task 6.1**: Update `SetupView.swift`
  - Use `@Environment(Tab.self)` to access tab.context and tab.stateMachine
  - File: `ClaudeManager/Views/SetupView.swift`

- [ ] **Task 6.2**: Update `ExecutionView.swift`
  - Use `@Environment(Tab.self)` to access tab.context
  - Add worktree indicator badge next to project name if tab.worktreeInfo != nil
  - File: `ClaudeManager/Views/ExecutionView.swift`

- [x] **Task 6.3**: Update `ControlsView.swift`
  - Use `@Environment(Tab.self)` to access tab.context and tab.stateMachine
  - File: `ClaudeManager/Views/ControlsView.swift`

- [x] **Task 6.4**: Update `UserQuestionView.swift`
  - Use `@Environment(Tab.self)` to access tab.stateMachine
  - File: `ClaudeManager/Views/UserQuestionView.swift`

- [ ] **Task 6.5**: Update `TaskFailureView.swift`
  - Use `@Environment(Tab.self)` to access tab.stateMachine
  - File: `ClaudeManager/Views/TaskFailureView.swift`

- [ ] **Task 6.6**: Update `LogView.swift`
  - Use `@Environment(Tab.self)` to access tab.context
  - File: `ClaudeManager/Views/LogView.swift`

- [ ] **Task 6.7**: Update `ManualInputView.swift`
  - Use `@Environment(Tab.self)` to access tab.context and tab.stateMachine
  - File: `ClaudeManager/Views/ManualInputView.swift`

### Phase 7: Worktree Integration

- [ ] **Task 7.1**: Integrate worktree creation in TabManager.createTab
  - Check if any existing tab has same projectPath
  - If duplicate, call worktreeService.createWorktree()
  - Set new tab's context.projectPath to worktree path
  - Store WorktreeInfo in tab
  - File: `ClaudeManager/State/TabManager.swift`

- [ ] **Task 7.2**: Implement worktree cleanup in TabManager.closeTab
  - If tab.worktreeInfo != nil, stop execution first
  - Call worktreeService.removeWorktree()
  - File: `ClaudeManager/State/TabManager.swift`

### Phase 8: Keyboard Shortcuts

- [ ] **Task 8.1**: Add tab navigation shortcuts in ClaudeManagerApp
  - Next Tab: ⌘⇧]
  - Previous Tab: ⌘⇧[
  - Add methods in TabManager: selectNextTab(), selectPreviousTab()
  - File: `ClaudeManager/ClaudeManagerApp.swift`, `ClaudeManager/State/TabManager.swift`

### Phase 9: Testing

- [ ] **Task 9.1**: Add `WorktreeServiceTests.swift`
  - Test createWorktree, removeWorktree, listWorktrees
  - File: `ClaudeManagerTests/WorktreeServiceTests.swift`

- [ ] **Task 9.2**: Add `TabManagerTests.swift`
  - Test createTab, closeTab, selectTab, duplicate detection
  - File: `ClaudeManagerTests/TabManagerTests.swift`

---

## Key Implementation Notes

- **Per-tab isolation:** Each Tab owns its own ExecutionContext, ExecutionStateMachine, and ClaudeCLIService
- **Shared state:** UserPreferences remains app-level and shared across tabs
- **Worktree location:** `.worktrees/<uuid>/` in the original repo
- **Environment injection:** Views use `@Environment(Tab.self)` for tab-level state
