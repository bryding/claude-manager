# Anthropic Teams to AWS Bedrock Mode Switching - Implementation Tasks

## Overview
Implement the ability to switch between Anthropic Teams API and AWS Bedrock when usage limits are reached.

**User Requirements:**
- Storage: Session only (credentials in memory, not persisted)
- Scope: Global for all tabs
- Recovery: Pause and retry current phase after switch
- Fallback: Offer to switch back to Teams if Bedrock hits limits

---

## Phase 1: Models & Configuration

### Task 1.1: Create APIMode.swift model file
- [ ] Create file `ClaudeManager/Models/APIMode.swift`
- [ ] Define `APIMode` enum with cases: `.anthropicTeams`, `.awsBedrock`
- [ ] Define `BedrockCredentials` struct with properties:
  - `accessKeyId: String`
  - `secretAccessKey: String`
  - `sessionToken: String?`
- [ ] Add `environmentVariables: [String: String]` computed property to `BedrockCredentials`
  - Returns dict with `CLAUDE_CODE_USE_BEDROCK=1`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
- [ ] Define `APIConfiguration` struct with:
  - `mode: APIMode`
  - `bedrockCredentials: BedrockCredentials?`
  - `static let default = APIConfiguration(mode: .anthropicTeams, bedrockCredentials: nil)`
- [ ] Add `environmentVariables() -> [String: String]` method that returns appropriate env vars based on mode
- [ ] Test: Verify environment variable generation for both modes

### Task 1.2: Update UserPreferences with API configuration
- [ ] Open `ClaudeManager/State/UserPreferences.swift`
- [ ] Add property: `var apiConfiguration: APIConfiguration = .default`
- [ ] Add property: `var bedrockCredentials: BedrockCredentials?` (in-memory only, not persisted to UserDefaults)
- [ ] Ensure `bedrockCredentials` is NOT included in UserDefaults persistence
- [ ] Test: Verify credentials stay in memory only

---

## Phase 2: Process Environment Management

### Task 2.1: Add custom environment support to ClaudeProcess
- [ ] Open `ClaudeManager/Services/ClaudeProcess.swift`
- [ ] Add init parameter: `customEnvironment: [String: String]? = nil`
- [ ] Store `customEnvironment` as property
- [ ] In `run()` method, after existing environment setup:
  - Merge custom environment: `environment.merge(customEnvironment ?? [:]) { _, new in new }`
- [ ] Test: Verify custom env vars are passed to subprocess

### Task 2.2: Update ClaudeCLIService to pass API configuration
- [ ] Open `ClaudeManager/Services/ClaudeCLIService.swift`
- [ ] Change init to accept `userPreferences: UserPreferences` parameter
- [ ] Store `userPreferences` as property
- [ ] In `executeInternal()`, read `userPreferences.apiConfiguration`
- [ ] Pass `apiConfiguration.environmentVariables()` to `ClaudeProcess` as `customEnvironment`
- [ ] Add log message: "Executing Claude in {mode} mode"
- [ ] Test: Verify correct env vars passed based on API mode

### Task 2.3: Update Tab creation to pass UserPreferences to ClaudeCLIService
- [ ] Open `ClaudeManager/Models/Tab.swift`
- [ ] Update `ClaudeCLIService` initialization to pass `userPreferences`
- [ ] Ensure all tabs share the same global API configuration
- [ ] Test: Verify tabs use global API mode

---

## Phase 3: Error Detection

### Task 3.1: Add usage limit detection to ClaudeProcessError
- [ ] Open `ClaudeManager/Services/ClaudeProcess.swift`
- [ ] Add computed property `isUsageLimit: Bool` to `ClaudeProcessError` enum
- [ ] For `.nonZeroExitCode(_, let stderr)` case, check stderr for patterns:
  - "usage limit", "rate limit", "quota exceeded", "too many requests", "monthly limit"
- [ ] Use case-insensitive matching
- [ ] Return true if any pattern found in stderr
- [ ] Test: Verify detection with mock stderr containing usage error

### Task 3.2: Add API switch prompt state to ExecutionContext
- [ ] Open `ClaudeManager/State/ExecutionContext.swift`
- [ ] Define struct `PendingAPISwitchPrompt` with:
  - `id: UUID = UUID()`
  - `error: String`
  - `fromMode: APIMode`
  - `timestamp: Date = Date()`
- [ ] Add property: `var pendingAPISwitchPrompt: PendingAPISwitchPrompt?`
- [ ] Test: Verify state updates observable in SwiftUI

---

## Phase 4: State Machine Integration

### Task 4.1: Add usage limit detection to error handling
- [ ] Open `ClaudeManager/State/ExecutionStateMachine.swift`
- [ ] In `handlePhaseError(_ error:)` method, after existing error checks:
  - Check if `(error as? ClaudeProcessError)?.isUsageLimit == true`
  - If true, create `PendingAPISwitchPrompt` with current mode from `userPreferences.apiConfiguration.mode`
  - Set `context.pendingAPISwitchPrompt = PendingAPISwitchPrompt(...)`
  - Store current phase to retry later (add property `phaseBeforeAPISwitch: ExecutionPhase?`)
  - Set `context.phase = .waitingForUser`
  - Return false to stop execution
- [ ] Test: Verify execution pauses on usage limit error

### Task 4.2: Add API switch response handler
- [ ] In `ExecutionStateMachine.swift`, add new method:
  ```swift
  func handleAPISwitchResponse(switchMode: Bool, credentials: BedrockCredentials?) async
  ```
- [ ] Guard against missing `pendingAPISwitchPrompt`, return early if nil
- [ ] Clear `context.pendingAPISwitchPrompt = nil`
- [ ] If `switchMode == false`, set phase to failed and return
- [ ] If switching from Teams to Bedrock:
  - Validate credentials not nil
  - Set `userPreferences.bedrockCredentials = credentials`
  - Set `userPreferences.apiConfiguration.mode = .awsBedrock`
  - Log: "Switched to AWS Bedrock mode"
- [ ] If switching from Bedrock to Teams:
  - Clear `userPreferences.bedrockCredentials = nil`
  - Set `userPreferences.apiConfiguration.mode = .anthropicTeams`
  - Log: "Switched back to Anthropic Teams mode"
- [ ] Clear `context.sessionId = nil` (session invalid across backends)
- [ ] Log warning: "Session context reset due to API mode switch"
- [ ] Restore phase from `phaseBeforeAPISwitch`
- [ ] Resume execution with `await runLoop()`
- [ ] Test: Verify mode switch and execution resume

---

## Phase 5: User Interface - API Switch Modal

### Task 5.1: Create APISwitchPromptView for Teams → Bedrock
- [ ] Create file `ClaudeManager/Views/APISwitchPromptView.swift`
- [ ] Define `APISwitchPromptView: View` struct
- [ ] Add `@Environment(Tab.self) private var tab`
- [ ] Add `@Environment(\.dismiss) private var dismiss`
- [ ] Add property `let prompt: PendingAPISwitchPrompt`
- [ ] Add `@State` variables:
  - `accessKeyId: String = ""`
  - `secretAccessKey: String = ""`
  - `sessionToken: String = ""`
  - `isSubmitting: Bool = false`
  - `errorMessage: String?`
- [ ] Build UI layout:
  - Title: "API Usage Limit Reached" or "AWS Bedrock Usage Limit Reached" (based on `prompt.fromMode`)
  - Display `prompt.error` message
  - If from Teams: Show 3 text fields (Access Key, Secret Key, Session Token)
  - If from Bedrock: Show message "Switch back to Anthropic Teams?"
  - Buttons: "Cancel" and "Switch to {mode}"
- [ ] Add validation for required fields (accessKeyId, secretAccessKey)
- [ ] Implement cancel action: dismiss and call `stateMachine.handleAPISwitchResponse(false, nil)`
- [ ] Implement submit action:
  - Create `BedrockCredentials` from form fields
  - Call `await stateMachine.handleAPISwitchResponse(true, credentials)`
  - Dismiss modal
- [ ] Use `SecureField` for secretAccessKey and sessionToken
- [ ] Test: Verify modal displays correctly for both directions

### Task 5.2: Integrate modal into ExecutionView
- [ ] Open `ClaudeManager/Views/ExecutionView.swift`
- [ ] Add `.sheet` modifier bound to `context.pendingAPISwitchPrompt`:
  ```swift
  .sheet(item: Binding(
      get: { context.pendingAPISwitchPrompt },
      set: { _ in }
  )) { prompt in
      APISwitchPromptView(prompt: prompt)
          .environment(tab)
  }
  ```
- [ ] Test: Verify modal appears when `pendingAPISwitchPrompt` is set

---

## Phase 6: User Interface - Mode Indicator & Settings

### Task 6.1: Add API mode indicator to UI
- [ ] Open `ClaudeManager/Views/ControlsView.swift` (or appropriate view)
- [ ] Add small badge showing current mode:
  - Text: "Teams" or "Bedrock"
  - Color: blue for Teams, orange for Bedrock
  - Position: near project path or status area
- [ ] Read mode from `userPreferences.apiConfiguration.mode`
- [ ] Test: Verify indicator updates when mode changes

### Task 6.2: Create APISettingsView for manual control
- [ ] Create file `ClaudeManager/Views/APISettingsView.swift`
- [ ] Define `APISettingsView: View` struct
- [ ] Add `@Environment(AppState.self) private var appState`
- [ ] Add `@State` for mode picker and credentials form
- [ ] Build UI:
  - Picker for API mode (Teams / Bedrock)
  - If Bedrock selected, show credentials form (same fields as modal)
  - Warning: "Switching modes will reset conversation context"
  - "Apply" button to update `userPreferences`
  - Show current mode indicator
- [ ] Implement apply action: update UserPreferences and show confirmation
- [ ] Test: Verify manual mode switching works

### Task 6.3: Add Settings access to MainView
- [ ] Open `ClaudeManager/Views/MainView.swift`
- [ ] Add `@State private var showSettings = false`
- [ ] Add toolbar button or menu item: "Settings"
- [ ] Add `.sheet(isPresented: $showSettings)` with `APISettingsView()`
- [ ] Pass `appState` environment
- [ ] Test: Verify Settings opens from toolbar

---

## Phase 7: Edge Cases & Polish

### Task 7.1: Add credential validation
- [ ] In `APISwitchPromptView`, add validation logic:
  - Check accessKeyId and secretAccessKey are non-empty
  - Validate format: access key starts with "AKIA" or "ASIA"
  - Show inline error messages for invalid input
- [ ] Disable submit button until validation passes
- [ ] Test: Verify validation prevents invalid submissions

### Task 7.2: Improve error messages
- [ ] Review all error messages for clarity:
  - Teams limit: "Your Anthropic Teams usage limit has been reached. Switch to AWS Bedrock to continue?"
  - Bedrock limit: "AWS Bedrock usage limit reached. Switch back to Teams mode?"
  - Invalid credentials: "Failed to connect with provided AWS credentials. Please verify and try again."
- [ ] Ensure errors are actionable and user-friendly
- [ ] Test: Verify error messages display correctly

### Task 7.3: Add security safeguards
- [ ] Audit logging: ensure no credential values are logged (only keys like "AWS_ACCESS_KEY_ID=***")
- [ ] Verify credentials cleared from memory when switching back to Teams
- [ ] Ensure `SecureField` used for all sensitive inputs
- [ ] Test: Review logs to confirm no credentials leaked

### Task 7.4: Handle session reset gracefully
- [ ] Ensure `sessionId` cleared on mode switch (already in Task 4.2)
- [ ] Add user notification/log that conversation context will be lost
- [ ] Consider showing alert: "Switching will reset conversation context"
- [ ] Test: Verify session properly reset

---

## Phase 8: Testing & Validation

### Task 8.1: Manual testing - Teams to Bedrock
- [ ] Simulate Teams usage limit error (inject stderr or exhaust real quota)
- [ ] Verify modal appears with correct messaging
- [ ] Fill out Bedrock credentials form
- [ ] Submit and verify:
  - Mode switches to Bedrock
  - Environment variables set correctly (`CLAUDE_CODE_USE_BEDROCK=1`, AWS keys)
  - Execution resumes from correct phase
  - Logs show mode switch
- [ ] Verify credentials not persisted after app restart

### Task 8.2: Manual testing - Bedrock to Teams
- [ ] With Bedrock mode active, simulate Bedrock usage limit
- [ ] Verify modal offers to switch back to Teams
- [ ] Accept switch and verify:
  - Mode switches back to Teams
  - Bedrock credentials cleared from memory
  - Execution resumes
- [ ] Test: Verify credentials removed

### Task 8.3: Manual testing - Settings UI
- [ ] Open Settings view
- [ ] Manually switch between modes
- [ ] Verify mode indicator updates
- [ ] Test invalid credentials handling
- [ ] Test with missing session token (should work, it's optional)

### Task 8.4: Edge case testing
- [ ] Test with invalid/malformed credentials
- [ ] Test canceling the switch modal (should fail execution)
- [ ] Test switching modes mid-execution
- [ ] Test multiple tabs with global mode
- [ ] Test app restart (credentials should be gone)

---

## Completion Checklist

**Core Functionality:**
- [ ] Detects API usage limits from Claude CLI stderr
- [ ] Prompts user with modal when limit hit
- [ ] Collects AWS credentials securely
- [ ] Sets correct environment variables for Bedrock
- [ ] Restarts Claude subprocess with new environment
- [ ] Resumes execution from paused phase
- [ ] Allows switching back from Bedrock to Teams
- [ ] Always asks user before switching (no automatic switches)

**Requirements Met:**
- [ ] Credentials stored in memory only (session-based)
- [ ] Global mode applies to all tabs
- [ ] Session context reset on switch (sessionId cleared)
- [ ] Visual indicator shows current API mode
- [ ] Manual settings allow pre-configuring mode

**Polish:**
- [ ] Error messages clear and actionable
- [ ] Credential validation prevents bad input
- [ ] No credentials logged to console/files
- [ ] UI responsive and intuitive
- [ ] Documentation updated (if needed)

---

## Notes

- Use `/executeplan` to work through tasks incrementally
- Check off tasks as completed with `[x]`
- Add notes for blockers or decisions needed
- Reference file paths included in each task
