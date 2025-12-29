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

## Task 1: Create Xcode Project Structure

**Description:** Set up the Xcode project with proper folder organization.

**Acceptance Criteria:**
- [ ] Create new SwiftUI macOS app named "ClaudeManager"
- [ ] Set deployment target to macOS 14.0+
- [ ] Create folder structure: Models/, Services/, State/, Views/
- [ ] Add empty placeholder files for organization

---

## Task 2: Implement Claude Stream Message Models

**Description:** Create Codable types that match Claude's `--output-format stream-json` output.

**Acceptance Criteria:**
- [ ] Create `ClaudeStreamMessage` enum with cases: system, assistant, user, result
- [ ] Create `SystemMessage` struct with sessionId, cwd, tools, model, permissionMode
- [ ] Create `AssistantMessage` struct with content blocks array
- [ ] Create `ContentBlock` enum with text and toolUse cases
- [ ] Create `ToolUseContent` struct with id, name, input dictionary
- [ ] Create `ResultMessage` struct with result, totalCostUsd, durationMs, isError
- [ ] Create `AskUserQuestionInput` struct for parsing question tool calls
- [ ] Add AnyCodable helper for dynamic JSON values

**File:** `ClaudeManager/Models/ClaudeStreamMessage.swift`

---

## Task 3: Implement Plan and Task Models

**Description:** Create models for representing parsed plan.md content.

**Acceptance Criteria:**
- [ ] Create `Plan` struct with rawText and tasks array
- [ ] Create `PlanTask` struct with id, number, title, description, status, subtasks
- [ ] Create `TaskStatus` enum: pending, inProgress, completed, failed, skipped
- [ ] Make models Identifiable and Equatable as needed

**File:** `ClaudeManager/Models/Plan.swift`

---

## Task 4: Implement Execution Phase Model

**Description:** Create enum representing all phases of the execution loop.

**Acceptance Criteria:**
- [ ] Create `ExecutionPhase` enum with all phases: idle, generatingInitialPlan, rewritingPlan, executingTask, committingImplementation, reviewingCode, committingReview, writingTests, committingTests, clearingContext, waitingForUser, paused, completed, failed
- [ ] Add `permissionMode` computed property returning "plan" or "acceptEdits"
- [ ] Add `isTerminal` computed property for completed/failed states

**File:** `ClaudeManager/Models/ExecutionPhase.swift`

---

## Task 5: Implement Log Entry Model

**Description:** Create model for structured log entries.

**Acceptance Criteria:**
- [ ] Create `LogEntry` struct with id, timestamp, phase, type, message
- [ ] Create `LogType` enum: output, toolUse, result, error, info
- [ ] Add color property to LogType for UI display

**File:** `ClaudeManager/Models/LogEntry.swift`

---

## Task 6: Implement Claude Message Parser

**Description:** Create JSONL parser for Claude's streaming output.

**Acceptance Criteria:**
- [ ] Create `ClaudeMessageParser` class
- [ ] Implement `parse(line:)` method returning optional ClaudeStreamMessage
- [ ] Handle malformed JSON gracefully (log and skip)
- [ ] Use JSONDecoder with appropriate settings

**File:** `ClaudeManager/Services/ClaudeMessageParser.swift`

---

## Task 7: Implement Claude Process Wrapper

**Description:** Create async wrapper for running Claude CLI as subprocess.

**Acceptance Criteria:**
- [ ] Create `ClaudeProcess` class with executablePath, arguments, workingDirectory
- [ ] Implement `run()` returning AsyncThrowingStream of ClaudeStreamMessage
- [ ] Set up stdout/stderr pipes on Foundation Process
- [ ] Read stdout line-by-line and parse each line
- [ ] Implement `terminate()` and `interrupt()` methods
- [ ] Handle process exit codes

**File:** `ClaudeManager/Services/ClaudeProcess.swift`

---

## Task 8: Implement Claude CLI Service

**Description:** Main service for executing Claude with different modes.

**Acceptance Criteria:**
- [ ] Create `ClaudeCLIService` class with claude executable path
- [ ] Create `PermissionMode` enum: plan, acceptEdits, default
- [ ] Create `ClaudeExecutionResult` struct with result, sessionId, totalCost, durationMs
- [ ] Implement `execute(prompt:workingDirectory:permissionMode:sessionId:onMessage:)` async method
- [ ] Build correct CLI arguments for each permission mode
- [ ] Support session resumption with --resume flag
- [ ] Return structured result after completion

**File:** `ClaudeManager/Services/ClaudeCLIService.swift`

---

## Task 9: Implement Plan Service

**Description:** Service for parsing and managing plan.md files.

**Acceptance Criteria:**
- [ ] Create `PlanService` class
- [ ] Implement `parsePlanFromFile(at:)` to read and parse plan.md
- [ ] Implement `parsePlanFromText(_:)` using regex to extract tasks
- [ ] Parse task headers: `## Task N: Title`
- [ ] Parse descriptions: `**Description:** ...`
- [ ] Parse acceptance criteria: `- [ ] ...`
- [ ] Implement `savePlan(_:to:)` to write plan.md

**File:** `ClaudeManager/Services/PlanService.swift`

---

## Task 10: Implement Git Service

**Description:** Simple wrapper for git commit operations.

**Acceptance Criteria:**
- [ ] Create `GitService` class
- [ ] Implement `commitAll(message:in:)` that stages and commits all changes
- [ ] Run `git add -A` then `git commit -m "message"`
- [ ] Handle case where there are no changes to commit
- [ ] Return success/failure result

**File:** `ClaudeManager/Services/GitService.swift`

---

## Task 11: Implement Execution Context

**Description:** Observable state container for current execution.

**Acceptance Criteria:**
- [ ] Create `ExecutionContext` class with @Observable macro
- [ ] Add properties: projectPath, featureDescription, plan, currentTaskIndex, phase, sessionId, logs, pendingQuestion, totalCost, startTime, errors
- [ ] Add computed `currentTask` property
- [ ] Add computed `progress` property (0.0 to 1.0)
- [ ] Create `PendingQuestion` struct for user input requests
- [ ] Create `ExecutionError` struct for error tracking

**File:** `ClaudeManager/State/ExecutionContext.swift`

---

## Task 12: Implement Execution State Machine - Core Structure

**Description:** Create the state machine class with control methods.

**Acceptance Criteria:**
- [ ] Create `ExecutionStateMachine` class with context, services as dependencies
- [ ] Add private state: currentProcess, isPaused, shouldStop
- [ ] Implement `start()` async method that begins the loop
- [ ] Implement `pause()` method
- [ ] Implement `resume()` async method
- [ ] Implement `stop()` method that terminates current process
- [ ] Implement `answerQuestion(_:)` async method

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 13: Implement Execution State Machine - Main Loop

**Description:** Implement the main execution loop and phase transitions.

**Acceptance Criteria:**
- [ ] Implement `runLoop()` that executes phases until terminal state
- [ ] Implement `executeCurrentPhase()` with switch over all phases
- [ ] Implement `transitionToNextPhase()` with correct phase flow
- [ ] Add `shouldWriteTests()` heuristic (skip for UI-related tasks)
- [ ] Add `advanceToNextTask()` to move to next task or complete

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 14: Implement Execution State Machine - Phase Handlers

**Description:** Implement individual phase execution methods.

**Acceptance Criteria:**
- [ ] Implement `generateInitialPlan()` - run Claude in plan mode with feature description
- [ ] Implement `rewritePlanToFormat()` - have Claude rewrite plan with discrete tasks
- [ ] Implement `executeCurrentTask()` - run Claude to implement current task
- [ ] Implement `runCodeReview()` - run Claude to review and fix code
- [ ] Implement `writeTestsIfNeeded()` - run Claude to write tests for core logic
- [ ] Implement `commitChanges(message:)` - call git service
- [ ] Implement `clearContext()` - reset session for next task

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 15: Implement Execution State Machine - Message Handling

**Description:** Handle incoming Claude messages and detect user questions.

**Acceptance Criteria:**
- [ ] Implement `handleMessage(_:)` async method
- [ ] Log text content to context.logs
- [ ] Log tool uses to context.logs
- [ ] Detect AskUserQuestion tool calls and extract questions
- [ ] Implement `handleUserQuestion(_:toolUseId:)` to pause and show UI
- [ ] Track total cost from result messages
- [ ] Implement `handleError(_:)` with error categorization

**File:** `ClaudeManager/State/ExecutionStateMachine.swift`

---

## Task 16: Implement App State

**Description:** Create global app state container.

**Acceptance Criteria:**
- [ ] Create `AppState` class with @Observable macro
- [ ] Add context: ExecutionContext property
- [ ] Add stateMachine: ExecutionStateMachine property
- [ ] Initialize services and wire dependencies

**File:** `ClaudeManager/State/AppState.swift`

---

## Task 17: Implement Setup View

**Description:** Initial view for project selection and feature input.

**Acceptance Criteria:**
- [ ] Create `SetupView` with @Environment access to AppState
- [ ] Add directory picker using NSOpenPanel
- [ ] Add TextEditor for feature description
- [ ] Add "Start Development Loop" button
- [ ] Disable button until project selected and description entered
- [ ] Call stateMachine.start() on button press

**File:** `ClaudeManager/Views/SetupView.swift`

---

## Task 18: Implement Phase Indicator View

**Description:** Visual indicator showing current execution phase.

**Acceptance Criteria:**
- [ ] Create `PhaseIndicatorView` taking ExecutionPhase
- [ ] Show colored status dot (gray=idle, blue=working, yellow=waiting, green=done, red=failed)
- [ ] Show phase name as headline
- [ ] Show phase description as caption
- [ ] Add pulsing animation for active phases

**File:** `ClaudeManager/Views/PhaseIndicatorView.swift`

---

## Task 19: Implement Task List View

**Description:** View showing all tasks with completion status.

**Acceptance Criteria:**
- [ ] Create `TaskListView` taking array of PlanTask
- [ ] Create `TaskRowView` for individual task display
- [ ] Show task number and title
- [ ] Show status icon: circle (pending), spinner (in progress), checkmark (completed), X (failed)
- [ ] Dim completed tasks
- [ ] Expand description for in-progress task

**File:** `ClaudeManager/Views/TaskListView.swift`

---

## Task 20: Implement Log View

**Description:** Real-time scrolling log of Claude's output.

**Acceptance Criteria:**
- [ ] Create `LogView` taking array of LogEntry
- [ ] Add search field for filtering
- [ ] Add type filter picker (All, Output, Tool Use, Error)
- [ ] Add auto-scroll toggle
- [ ] Create `LogEntryView` showing timestamp, type badge, message
- [ ] Use monospace font for messages
- [ ] Auto-scroll to bottom on new entries when enabled

**File:** `ClaudeManager/Views/LogView.swift`

---

## Task 21: Implement User Question View

**Description:** Modal sheet for answering Claude's questions.

**Acceptance Criteria:**
- [ ] Create `UserQuestionView` taking PendingQuestion
- [ ] Show question header and text
- [ ] If options provided, show selectable option buttons with descriptions
- [ ] If no options, show TextEditor for freeform input
- [ ] Add Skip and Submit buttons
- [ ] Call stateMachine.answerQuestion() on submit

**File:** `ClaudeManager/Views/UserQuestionView.swift`

---

## Task 22: Implement Controls View

**Description:** Pause/resume/stop controls with cost display.

**Acceptance Criteria:**
- [ ] Create `ControlsView` with @Environment access to AppState
- [ ] Add Pause/Resume toggle button
- [ ] Add Stop button
- [ ] Show total cost with dollar formatting
- [ ] Disable controls appropriately based on phase

**File:** `ClaudeManager/Views/ControlsView.swift`

---

## Task 23: Implement Execution View

**Description:** Main dashboard view during execution.

**Acceptance Criteria:**
- [ ] Create `ExecutionView` with HSplitView layout
- [ ] Left side: PhaseIndicatorView, ProgressView, TaskListView, ControlsView
- [ ] Right side: LogView
- [ ] Wire up data from AppState context

**File:** `ClaudeManager/Views/ExecutionView.swift`

---

## Task 24: Implement Main View and App Entry

**Description:** Root view and app entry point.

**Acceptance Criteria:**
- [ ] Create `MainView` with NavigationSplitView
- [ ] Show SetupView when no project selected
- [ ] Show ExecutionView when project selected
- [ ] Add sheet modifier for UserQuestionView bound to pendingQuestion
- [ ] Create `ClaudeManagerApp` with @main
- [ ] Initialize and inject AppState as environment

**Files:** `ClaudeManager/Views/MainView.swift`, `ClaudeManager/ClaudeManagerApp.swift`

---

## Task 25: Integration Testing and Error Handling

**Description:** Test the full loop and add robust error handling.

**Acceptance Criteria:**
- [ ] Test full execution loop with a simple feature
- [ ] Add retry logic for transient failures
- [ ] Handle empty plan gracefully
- [ ] Handle failed tasks (skip vs retry)
- [ ] Add timeout handling for long-running operations
- [ ] Test pause/resume/stop functionality

---

## Task 26: Polish and UX Improvements

**Description:** Final polish and user experience improvements.

**Acceptance Criteria:**
- [ ] Add app icon
- [ ] Add keyboard shortcuts (Cmd+P pause, Cmd+. stop)
- [ ] Add recent projects list in sidebar
- [ ] Persist last used project path
- [ ] Add elapsed time display
- [ ] Add confirmation dialog before stopping mid-task
