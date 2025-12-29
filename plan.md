# Claude Manager - Implementation Plan

A SwiftUI macOS app that orchestrates Claude Code CLI in an automated development loop.

## Workflow

```
User describes feature → Claude generates plan → Plan rewritten to tasks → Loop:
  → Execute task (plan mode) → Accept & implement
  → Commit → Code review → Commit
  → (maybe) Write tests → Commit
  → Clear context → Repeat until done
```

---

## Task 1: Create Xcode Project Structure ✅

**Description:** Set up the Xcode project with proper folder organization.

**Acceptance Criteria:**
- [x] Create new SwiftUI macOS app named "ClaudeManager"
- [x] Set deployment target to macOS 14.0+
- [x] Create folder structure: Models/, Services/, State/, Views/
- [x] Add empty placeholder files for organization

---

## Task 2: Implement Claude Stream Message Models ✅

**Description:** Create Codable types that match Claude's `--output-format stream-json` output.

**Acceptance Criteria:**
- [x] Create `ClaudeStreamMessage` enum with cases: system, assistant, user, result
- [x] Create `SystemMessage` struct with sessionId, cwd, tools, model, permissionMode
- [x] Create `AssistantMessage` struct with content blocks array
- [x] Create `ContentBlock` enum with text and toolUse cases
- [x] Create `ToolUseContent` struct with id, name, input dictionary
- [x] Create `ResultMessage` struct with result, totalCostUsd, durationMs, isError
- [x] Create `AskUserQuestionInput` struct for parsing question tool calls
- [x] Add AnyCodable helper for dynamic JSON values

**File:** `ClaudeManager/Models/ClaudeStreamMessage.swift`

---

## Task 3: Implement Plan and Task Models ✅

**Description:** Create models for representing parsed plan.md content.

**Acceptance Criteria:**
- [x] Create `Plan` struct with rawText and tasks array
- [x] Create `PlanTask` struct with id, number, title, description, status, subtasks
- [x] Create `TaskStatus` enum: pending, inProgress, completed, failed, skipped
- [x] Make models Identifiable and Equatable as needed

**File:** `ClaudeManager/Models/Plan.swift`

---

## Task 4: Implement Execution Phase Model ✅

**Description:** Create enum representing all phases of the execution loop.

**Acceptance Criteria:**
- [x] Create `ExecutionPhase` enum with all phases: idle, generatingInitialPlan, rewritingPlan, executingTask, committingImplementation, reviewingCode, committingReview, writingTests, committingTests, clearingContext, waitingForUser, paused, completed, failed
- [x] Add `permissionMode` computed property returning "plan" or "acceptEdits"
- [x] Add `isTerminal` computed property for completed/failed states

**File:** `ClaudeManager/Models/ExecutionPhase.swift`

---

## Task 5: Implement Log Entry Model ✅

**Description:** Create model for structured log entries.

**Acceptance Criteria:**
- [x] Create `LogEntry` struct with id, timestamp, phase, type, message
- [x] Create `LogType` enum: output, toolUse, result, error, info
- [x] Add color property to LogType for UI display

**File:** `ClaudeManager/Models/LogEntry.swift`

---

## Task 6: Implement Claude Message Parser ✅

**Description:** Create JSONL parser for Claude's streaming output.

**Acceptance Criteria:**
- [x] Create `ClaudeMessageParser` class
- [x] Implement `parse(line:)` method returning optional ClaudeStreamMessage
- [x] Handle malformed JSON gracefully (log and skip)
- [x] Use JSONDecoder with appropriate settings

**File:** `ClaudeManager/Services/ClaudeMessageParser.swift`

---

## Task 7: Implement Claude Process Wrapper ✅

**Description:** Create async wrapper for running Claude CLI as subprocess.

**Acceptance Criteria:**
- [x] Create `ClaudeProcess` class with executablePath, arguments, workingDirectory
- [x] Implement `run()` returning AsyncThrowingStream of ClaudeStreamMessage
- [x] Set up stdout/stderr pipes on Foundation Process
- [x] Read stdout line-by-line and parse each line
- [x] Implement `terminate()` and `interrupt()` methods
- [x] Handle process exit codes

**File:** `ClaudeManager/Services/ClaudeProcess.swift`

---

## Task 8: Implement Claude CLI Service ✅

**Description:** Main service for executing Claude with different modes.

**Acceptance Criteria:**
- [x] Create `ClaudeCLIService` class with claude executable path
- [x] Create `PermissionMode` enum: plan, acceptEdits, default
- [x] Create `ClaudeExecutionResult` struct with result, sessionId, totalCost, durationMs
- [x] Implement `execute(prompt:workingDirectory:permissionMode:sessionId:onMessage:)` async method
- [x] Build correct CLI arguments for each permission mode
- [x] Support session resumption with --resume flag
- [x] Return structured result after completion

**File:** `ClaudeManager/Services/ClaudeCLIService.swift`

---

## Task 9: Implement Plan Service ✅

**Description:** Service for parsing and managing plan.md files.

**Acceptance Criteria:**
- [x] Create `PlanService` class
- [x] Implement `parsePlanFromFile(at:)` to read and parse plan.md
- [x] Implement `parsePlanFromText(_:)` using regex to extract tasks
- [x] Parse task headers: `## Task N: Title`
- [x] Parse descriptions: `**Description:** ...`
- [x] Parse acceptance criteria: `- [ ] ...`
- [x] Implement `savePlan(_:to:)` to write plan.md

**File:** `ClaudeManager/Services/PlanService.swift`

---

## Task 10: Implement Git Service ✅

**Description:** Simple wrapper for git commit operations.

**Acceptance Criteria:**
- [x] Create `GitService` class
- [x] Implement `commitAll(message:in:)` that stages and commits all changes
- [x] Run `git add -A` then `git commit -m "message"`
- [x] Handle case where there are no changes to commit
- [x] Return success/failure result

**File:** `ClaudeManager/Services/GitService.swift`

---

## Task 11: Implement Execution Context ✅

**Description:** Observable state container for current execution.

**Acceptance Criteria:**
- [x] Create `ExecutionContext` class with @Observable macro
- [x] Add properties: projectPath, featureDescription, plan, currentTaskIndex, phase, sessionId, logs, pendingQuestion, totalCost, startTime, errors
- [x] Add computed `currentTask` property
- [x] Add computed `progress` property (0.0 to 1.0)
- [x] Create `PendingQuestion` struct for user input requests
- [x] Create `ExecutionError` struct for error tracking

**File:** `ClaudeManager/State/ExecutionContext.swift`

---

## Task 12: Implement Execution State Machine - Core Structure ✅

**Description:** Create the state machine class with control methods.

**Acceptance Criteria:**
- [x] Create `ExecutionStateMachine` class with context, services as dependencies
- [x] Add private state: currentProcess, isPaused, shouldStop
- [x] Implement `start()` async method that begins the loop
- [x] Implement `pause()` method
- [x] Implement `resume()` async method
- [x] Implement `stop()` method that terminates current process
- [x] Implement `answerQuestion(_:)` async method

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 13: Implement Execution State Machine - Main Loop ✅

**Description:** Implement the main execution loop and phase transitions.

**Acceptance Criteria:**
- [x] Implement `runLoop()` that executes phases until terminal state
- [x] Implement `executeCurrentPhase()` with switch over all phases
- [x] Implement `transitionToNextPhase()` with correct phase flow
- [x] Add `shouldWriteTests()` heuristic (skip for UI-related tasks)
- [x] Add `advanceToNextTask()` to move to next task or complete

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 14: Implement Execution State Machine - Phase Handlers ✅

**Description:** Implement individual phase execution methods.

**Acceptance Criteria:**
- [x] Implement `generateInitialPlan()` - run Claude in plan mode with feature description
- [x] Implement `rewritePlanToFormat()` - have Claude rewrite plan with discrete tasks
- [x] Implement `executeCurrentTask()` - run Claude to implement current task
- [x] Implement `runCodeReview()` - run Claude to review and fix code
- [x] Implement `writeTestsIfNeeded()` - run Claude to write tests for core logic
- [x] Implement `commitChanges(message:)` - call git service
- [x] Implement `clearContext()` - reset session for next task

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 15: Implement Execution State Machine - Message Handling ✅

**Description:** Handle incoming Claude messages and detect user questions.

**Acceptance Criteria:**
- [x] Implement `handleMessage(_:)` async method
- [x] Log text content to context.logs
- [x] Log tool uses to context.logs
- [x] Detect AskUserQuestion tool calls and extract questions
- [x] Implement `handleUserQuestion(_:toolUseId:)` to pause and show UI
- [x] Track total cost from result messages
- [x] Implement `handleError(_:)` with error categorization

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 16: Implement App State ✅

**Description:** Create global app state container.

**Acceptance Criteria:**
- [x] Create `AppState` class with @Observable macro
- [x] Add context: ExecutionContext property
- [x] Add stateMachine: ExecutionStateMachine property
- [x] Initialize services and wire dependencies

**File:** `ClaudeManager/State/AppState.swift`

---

## Task 17: Implement Setup View ✅

**Description:** Initial view for project selection and feature input.

**Acceptance Criteria:**
- [x] Create `SetupView` with @Environment access to AppState
- [x] Add directory picker using NSOpenPanel
- [x] Add TextEditor for feature description
- [x] Add "Start Development Loop" button
- [x] Disable button until project selected and description entered
- [x] Call stateMachine.start() on button press

**File:** `ClaudeManager/Views/SetupView.swift`

---

## Task 18: Implement Phase Indicator View ✅

**Description:** Visual indicator showing current execution phase.

**Acceptance Criteria:**
- [x] Create `PhaseIndicatorView` taking ExecutionPhase
- [x] Show colored status dot (gray=idle, blue=working, yellow=waiting, green=done, red=failed)
- [x] Show phase name as headline
- [x] Show phase description as caption
- [x] Add pulsing animation for active phases

**File:** `ClaudeManager/Views/PhaseIndicatorView.swift`

---

## Task 19: Implement Task List View ✅

**Description:** View showing all tasks with completion status.

**Acceptance Criteria:**
- [x] Create `TaskListView` taking array of PlanTask
- [x] Create `TaskRowView` for individual task display
- [x] Show task number and title
- [x] Show status icon: circle (pending), spinner (in progress), checkmark (completed), X (failed)
- [x] Dim completed tasks
- [x] Expand description for in-progress task

**File:** `ClaudeManager/Views/TaskListView.swift`

---

## Task 20: Implement Log View ✅

**Description:** Real-time scrolling log of Claude's output.

**Acceptance Criteria:**
- [x] Create `LogView` taking array of LogEntry
- [x] Add search field for filtering
- [x] Add type filter picker (All, Output, Tool Use, Error)
- [x] Add auto-scroll toggle
- [x] Create `LogEntryView` showing timestamp, type badge, message
- [x] Use monospace font for messages
- [x] Auto-scroll to bottom on new entries when enabled

**File:** `ClaudeManager/Views/LogView.swift`

---

## Task 21: Implement User Question View ✅

**Description:** Modal sheet for answering Claude's questions.

**Acceptance Criteria:**
- [x] Create `UserQuestionView` taking PendingQuestion
- [x] Show question header and text
- [x] If options provided, show selectable option buttons with descriptions
- [x] If no options, show TextEditor for freeform input
- [x] Add Skip and Submit buttons
- [x] Call stateMachine.answerQuestion() on submit

**File:** `ClaudeManager/Views/UserQuestionView.swift`

---

## Task 22: Implement Controls View ✅

**Description:** Pause/resume/stop controls with cost display.

**Acceptance Criteria:**
- [x] Create `ControlsView` with @Environment access to AppState
- [x] Add Pause/Resume toggle button
- [x] Add Stop button
- [x] Show total cost with dollar formatting
- [x] Disable controls appropriately based on phase

**File:** `ClaudeManager/Views/ControlsView.swift`

---

## Task 23: Implement Execution View ✅

**Description:** Main dashboard view during execution.

**Acceptance Criteria:**
- [x] Create `ExecutionView` with HSplitView layout
- [x] Left side: PhaseIndicatorView, ProgressView, TaskListView, ControlsView
- [x] Right side: LogView
- [x] Wire up data from AppState context

**File:** `ClaudeManager/Views/ExecutionView.swift`

---

## Task 24: Implement Main View and App Entry ✅

**Description:** Root view and app entry point.

**Acceptance Criteria:**
- [x] Create `MainView` with NavigationSplitView (implemented as ContentView with Group)
- [x] Show SetupView when no project selected
- [x] Show ExecutionView when project selected
- [x] Add sheet modifier for UserQuestionView bound to pendingQuestion
- [x] Create `ClaudeManagerApp` with @main
- [x] Initialize and inject AppState as environment

**Files:** `ClaudeManager/ContentView.swift`, `ClaudeManager/ClaudeManagerApp.swift`

---

## Task 25: Context Window Management ✅

**Description:** Detect when context window is running low and gracefully handle it by creating a WIP commit and continuation summary before clearing context. Never use compaction - always clear and resume with summary.

**Acceptance Criteria:**
- [x] Track context usage from Claude's stream-json output (usage.input_tokens, usage.output_tokens)
- [x] Calculate approximate context percentage remaining
- [x] When below 10% remaining, trigger graceful handoff:
  1. Interrupt current Claude process
  2. Run Claude with prompt to create WIP commit with current progress
  3. Run Claude with prompt to generate concise continuation summary
  4. Store summary in ExecutionContext
  5. Clear context (new session)
  6. Resume task with continuation summary as context
- [x] Add `ContinuationSummary` struct with essential info fields
- [x] Add `contextPercentRemaining` computed property to ExecutionContext
- [x] Show context usage indicator in UI

**File:** `ClaudeManager/State/ExecutionStateMachine.swift` (extend existing)

---

## ✅ Task 26: Integration Testing and Error Handling

**Description:** Test the full loop and add robust error handling.

**Acceptance Criteria:**
- [x] Test full execution loop with a simple feature
- [x] Add retry logic for transient failures
- [x] Handle empty plan gracefully
- [x] Handle failed tasks (skip vs retry)
- [x] Add timeout handling for long-running operations
- [x] Test pause/resume/stop functionality

**Implementation Notes:**
- Added `TimeoutConfiguration` struct with configurable timeouts for plan/execution/commit
- All Claude CLI calls now pass appropriate timeouts based on operation type
- Added `PendingTaskFailure` to pause execution and ask user to retry/skip/stop on task failure
- Created `TaskFailureView` for user interaction when tasks fail
- Added 10 new tests for timeout/retry/task failure handling

---

## ✅ Task 27: Polish and UX Improvements

**Description:** Final polish and user experience improvements.

**Acceptance Criteria:**
- [x] Add app icon
- [x] Add keyboard shortcuts (Cmd+P pause, Cmd+. stop)
- [x] Add recent projects list in sidebar
- [x] Persist last used project path
- [x] Add elapsed time display
- [x] Add confirmation dialog before stopping mid-task

**Implementation Notes:**
- Created `UserPreferences.swift` for persisting last project path and recent projects (max 10)
- Added recent projects dropdown menu next to "Select Folder..." button in SetupView
- Added elapsed time display using `TimelineView` for live updates in ControlsView
- Added keyboard shortcuts via `.commands` modifier in ClaudeManagerApp (Cmd+P pause/resume, Cmd+. stop)
- Added `.confirmationDialog()` for stop confirmation with destructive action
- Generated SF Symbol-based app icon (terminal + gear motif) at all required macOS sizes

---

## Task 28: Support Existing plan.md Files

**Description:** Detect existing plan.md when a folder is selected and allow resuming from it instead of requiring a new feature description.

**Acceptance Criteria:**
- [ ] Add `existingPlan: Plan?` property to ExecutionContext
- [ ] Add `checkForExistingPlan()` method to SetupView that loads plan.md if it exists
- [ ] Call `checkForExistingPlan()` after folder selection and on appear
- [ ] Add `existingPlanSection` UI showing task count with "Resume Plan" / "Start Fresh" buttons
- [ ] Update `canStart` to allow starting when existingPlan is set (no feature description required)
- [ ] Add `startWithExistingPlan()` to ExecutionStateMachine that skips plan generation
- [ ] Add `findFirstPendingTask(in:)` helper to resume from first incomplete task

**Files:**
- `ClaudeManager/State/ExecutionContext.swift`
- `ClaudeManager/Views/SetupView.swift`
- `ClaudeManager/State/ExecutionStateMachine.swift`
