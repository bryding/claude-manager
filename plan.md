# Add XCUITest UI Testing

Add XCUITest UI testing to Claude Manager. Since XCUITest runs in a separate process, we use launch arguments to detect test mode and configure mock services.

## Task 1: Create XCUITest Target ✅
**Description:** Create the ClaudeManagerUITests target and directory structure.

- [x] Create `/ClaudeManagerUITests/` directory
- [x] Add XCUITest bundle target to Xcode project via pbxproj
- [x] Configure target with host application ClaudeManager
- [x] Verify target builds with `xcodebuild -scheme ClaudeManager test`

## Task 2: Create Shared AccessibilityIdentifiers ✅
**Description:** Create centralized accessibility identifier constants shared between main app and UI tests.

- [x] Create `/ClaudeManager/Testing/AccessibilityIdentifiers.swift`
- [x] Add enums for each view: MainView, TabBar, SetupView, ExecutionView, ControlsView, UserQuestionView, LogView, TaskListView
- [x] Add file to both ClaudeManager and ClaudeManagerUITests targets

## Task 3: Create Test Mode Configuration ✅
**Description:** Add test mode detection so the app can configure itself differently when running under XCUITest.

- [x] Create `/ClaudeManager/Testing/TestModeConfiguration.swift`
- [x] Add `TestScenario` enum with cases: idle, setupWithProject, executingTask, waitingForUserQuestion, completed, failed
- [x] Add `TestModeConfiguration` singleton that reads `--uitesting` arg and `TEST_SCENARIO` env var

## Task 4: Create Mock Claude Service for UI Tests ✅
**Description:** Create a mock ClaudeCLIService that can be bundled with the app for UI testing.

- [x] Create `/ClaudeManager/Testing/MockClaudeCLIServiceForUITests.swift`
- [x] Implement `ClaudeCLIServiceProtocol` with predetermined responses based on test scenario
- [x] Add simulated delays for realistic behavior
- [x] Add ability to trigger user questions based on scenario

## Task 5: Modify AppState for Test Mode ✅
**Description:** Add factory method to AppState for creating test-configured instances.

- [x] Add `static func forUITesting(scenario: TestScenario) -> AppState` to AppState
- [x] Configure TabManager with mock services based on scenario
- [x] Set up initial state (project path, phase, etc.) based on scenario

## Task 6: Modify ClaudeManagerApp for Test Mode ✅
**Description:** Detect test mode at app launch and configure accordingly.

- [x] Check `ProcessInfo.processInfo.arguments` for `--uitesting`
- [x] Read `TEST_SCENARIO` from environment
- [x] Use `AppState.forUITesting()` when in test mode

## Task 7: Add Accessibility Identifiers to Tab Views ✅
**Description:** Add identifiers to MainView, TabBarView, and TabItemView.

- [x] MainView: `mainView`, `tabBar`, `contentArea`
- [x] TabBarView: `addTabButton`
- [x] TabItemView: `tab_{id}`, `tabCloseButton_{id}`, `tabStatusDot_{id}`

## Task 8: Add Accessibility Identifiers to SetupView ✅
**Description:** Add identifiers to SetupView elements.

- [x] `setupView`, `selectFolderButton`, `projectPathDisplay`
- [x] `featureDescriptionEditor`, `attachedImagesView`
- [x] `existingPlanBanner`, `useExistingPlanButton`, `dismissPlanButton`
- [x] `startButton`

## Task 9: Add Accessibility Identifiers to ExecutionView and ControlsView ✅
**Description:** Add identifiers to execution dashboard elements.

- [x] ExecutionView: `executionView`, `phaseIndicator`, `progressBar`, `progressPercentage`
- [x] ControlsView: `controlsView`, `pauseButton`, `resumeButton`, `stopButton`, `continueButton`
- [x] `elapsedTimeDisplay`, `costDisplay`, `stopConfirmationDialog`

## Task 10: Add Accessibility Identifiers to UserQuestionView ✅
**Description:** Add identifiers to question modal elements.

- [x] `userQuestionView`, `questionHeader`, `questionText`
- [x] `optionsSection`, `option_{index}` for each option
- [x] `freeformTextEditor`, `skipButton`, `submitButton`

## Task 11: Add Accessibility Identifiers to LogView and TaskListView ✅
**Description:** Add identifiers to log and task list elements.

- [x] LogView: `logView`, `logSearchField`, `logFilterPicker`, `autoScrollToggle`
- [x] TaskListView: `taskListView`, `task_{number}`, `taskStatus_{number}`

## Task 12: Create Base UI Test Case ✅
**Description:** Create base test class with common setup and helpers.

- [x] Create `/ClaudeManagerUITests/ClaudeManagerUITestCase.swift`
- [x] Add `app` property and launch configuration with `--uitesting` arg
- [x] Add `launch(scenario:)` method to set TEST_SCENARIO env var
- [x] Add `waitForElement(_:timeout:)` helper

## Task 13: Write Tab Management UI Tests
**Description:** Write tests for tab creation, switching, and closing.

- [ ] Create `/ClaudeManagerUITests/TabManagementUITests.swift`
- [ ] `testCreateNewTab`: tap add button, verify new tab appears
- [ ] `testSwitchTabs`: create tabs, tap each, verify content changes
- [ ] `testCloseTab`: create tab, close it, verify removed

## Task 14: Write Setup Flow UI Tests
**Description:** Write tests for the setup view interactions.

- [ ] Create `/ClaudeManagerUITests/SetupFlowUITests.swift`
- [ ] `testFeatureDescriptionInput`: type text, verify appears
- [ ] `testStartButtonDisabledWithoutProject`: verify disabled state
- [ ] `testStartButtonEnabledWithProjectAndDescription`: verify enabled
- [ ] `testExistingPlanBannerAppears`: verify banner with plan scenario

## Task 15: Write Execution View UI Tests
**Description:** Write tests for execution dashboard interactions.

- [ ] Create `/ClaudeManagerUITests/ExecutionViewUITests.swift`
- [ ] `testExecutionViewDisplaysProgress`: verify progress bar
- [ ] `testPauseButton`: tap pause, verify state changes
- [ ] `testResumeButton`: from paused, tap resume
- [ ] `testStopButtonShowsConfirmation`: verify dialog appears

## Task 16: Write User Question UI Tests
**Description:** Write tests for question modal interactions.

- [ ] Create `/ClaudeManagerUITests/UserQuestionUITests.swift`
- [ ] `testSingleSelectQuestionDisplay`: verify UI elements
- [ ] `testSingleSelectOptionSelection`: tap option, verify selected
- [ ] `testFreeformQuestionDisplay`: verify text editor appears
- [ ] `testSubmitButtonDisabledWithoutSelection`: verify disabled
- [ ] `testSubmitButtonEnabledAfterSelection`: verify enabled
