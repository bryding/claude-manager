# Fix Interview Bugs and Add Manual User Input

Fix bugs in the interview/plan generation workflow and add manual user control.

## Problem Summary

1. **Duplicate question bug**: Interview question asked twice, dialog closes before user can answer
2. **Freeze bug**: Plan generation appears to freeze after interview
3. **Missing user control**: No way to send manual prompts to Claude when stuck

---

## Tasks

### Phase 1: Fix Duplicate Question Bug

- [x] **Task 1.1**: Add question tracking flag to ExecutionStateMachine
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - Add private property: `private var questionAskedDuringPhase = false`
  - Location: Around line 49 with other private properties

- [x] **Task 1.2**: Set flag when interview question is detected
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - In `handleAskUserQuestion()` (~line 697-700), for `.interview` case:
  - Add: `questionAskedDuringPhase = true` after setting `context.phase = .waitingForUser`

- [x] **Task 1.3**: Reset flag at start of conductInterview()
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - At the beginning of `conductInterview()` (~line 716):
  - Add: `questionAskedDuringPhase = false`

- [x] **Task 1.4**: Check flag in runLoop() and break if question asked
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - In `runLoop()` after `try await executeCurrentPhase()` (~line 339):
  - Add check: if `questionAskedDuringPhase` is true, set it false and `break`

---

### Phase 2: Fix Interview Freeze Bug

- [x] **Task 2.1**: Add auto-complete fallback in conductInterview()
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - After `claudeService.execute()` returns in `conductInterview()` (~line 776):
  - Check: if `isComplete == false` AND `pendingQuestion == nil` AND `questionAskedDuringPhase == false`
  - If all true: call `context.interviewSession?.markComplete()` with log message
  - Reason: Claude responded substantively without asking more questions

---

### Phase 3: Add Manual Input State

- [x] **Task 3.1**: Add isManualInputAvailable computed property
  - File: `ClaudeManager/State/ExecutionContext.swift`
  - Add computed property that returns true if:
  - `sessionId != nil && !phase.isTerminal && phase != .idle`

- [x] **Task 3.2**: Add suggestedManualInput property
  - File: `ClaudeManager/State/ExecutionContext.swift`
  - Add: `var suggestedManualInput: String = ""`
  - Used by Continue button to pre-fill the input field

- [x] **Task 3.3**: Add appearsStuck computed property
  - File: `ClaudeManager/State/ExecutionContext.swift`
  - Returns true if: `phase == .conductingInterview && pendingQuestion == nil && interviewSession?.isComplete != true`

---

### Phase 4: Add Manual Input Method

- [x] **Task 4.1**: Add sendManualInput() method to ExecutionStateMachine
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - New public method: `func sendManualInput(_ input: String) async throws`
  - Guard: projectPath and sessionId must exist
  - Log the user input
  - Determine permission mode from current phase
  - Call `claudeService.execute()` with user's prompt and current sessionId
  - Handle streaming messages with `handleStreamMessage()`
  - Resume `runLoop()` after completion if not waiting for user

---

### Phase 5: Create ManualInputView

- [x] **Task 5.1**: Create ManualInputView.swift file
  - File: `ClaudeManager/Views/ManualInputView.swift` (new)
  - SwiftUI view with Environment access to AppState
  - Local state: `inputText`, `isSubmitting`, `errorMessage`

- [x] **Task 5.2**: Add text field and send button
  - File: `ClaudeManager/Views/ManualInputView.swift`
  - TextField with placeholder "Send message to Claude..."
  - Send button with paperplane icon
  - Disable when: input empty, submitting, or `!isManualInputAvailable`

- [x] **Task 5.3**: Add submit logic
  - File: `ClaudeManager/Views/ManualInputView.swift`
  - On submit: trim input, clear field, set isSubmitting
  - Call `appState.stateMachine.sendManualInput(text)`
  - Handle errors with alert
  - Reset isSubmitting when done

- [x] **Task 5.4**: Add suggested text binding
  - File: `ClaudeManager/Views/ManualInputView.swift`
  - Watch `appState.context.suggestedManualInput`
  - When it changes to non-empty, populate inputText and clear the suggestion

---

### Phase 6: Integrate ManualInputView into LogView

- [x] **Task 6.1**: Add ManualInputView to LogView body
  - File: `ClaudeManager/Views/LogView.swift`
  - Add `Divider()` and `ManualInputView()` at the bottom of the VStack
  - After the ScrollViewReader, before closing brace

---

### Phase 7: Add Continue Button for Stuck States

- [x] **Task 7.1**: Add Continue button to ControlsView
  - File: `ClaudeManager/Views/ControlsView.swift`
  - Add computed property checking `context.appearsStuck`
  - Show orange "Continue" button when stuck

- [x] **Task 7.2**: Implement Continue button action
  - File: `ClaudeManager/Views/ControlsView.swift`
  - On click: set `context.suggestedManualInput` to nudge text
  - Nudge text: "Please continue with the interview or proceed to plan generation if you have enough information."
  - User edits and sends manually

---

### Phase 8: Improve Phase Indicator

- [x] **Task 8.1**: Add context parameters to PhaseIndicatorView
  - File: `ClaudeManager/Views/PhaseIndicatorView.swift`
  - Add optional parameters: `hasQuestion: Bool = false`, `isInterviewComplete: Bool = false`

- [x] **Task 8.2**: Show contextual status for interview phase
  - File: `ClaudeManager/Views/PhaseIndicatorView.swift`
  - If interview phase and `hasQuestion`: "Waiting for your answer..."
  - If interview phase and not complete: "Claude is gathering requirements..."

- [x] **Task 8.3**: Update ExecutionView to pass context
  - File: `ClaudeManager/Views/ExecutionView.swift`
  - Pass `hasQuestion: context.pendingQuestion != nil`
  - Pass `isInterviewComplete: context.interviewSession?.isComplete ?? false`

---

## Critical Files

| File | Changes |
|------|---------|
| `State/ExecutionStateMachine.swift` | Bug fixes (flag, auto-complete), sendManualInput() |
| `State/ExecutionContext.swift` | New properties for manual input state |
| `Views/ManualInputView.swift` | **NEW** - Manual input UI component |
| `Views/LogView.swift` | Integrate ManualInputView |
| `Views/ControlsView.swift` | Continue button |
| `Views/PhaseIndicatorView.swift` | Better interview status |
| `Views/ExecutionView.swift` | Pass context to PhaseIndicatorView |
