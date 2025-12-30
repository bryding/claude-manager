# Full Autonomy for Claude Manager

Make the orchestrator run with full control like a human developer sitting there.

## Features
1. **Smart Auto-Answer** - When Claude asks questions, use AI to intelligently decide based on project context
2. **Auto-Handle Failures** - Retry failed tasks automatically, then skip and continue
3. **Run Build/Tests** - Add phases to run build & test commands, feed errors back to Claude
4. **Better Prompts** - Improve prompts for task execution, code review, and test writing

---

## Tasks

### Phase 1: Configuration Foundation

- [x] **Task 1.1**: Create AutonomousConfiguration model
  - File: `ClaudeManager/Models/AutonomousConfiguration.swift`
  - Properties: autoAnswerEnabled, autoFailureHandling, maxTaskRetries, runBuildAfterCommit, runTestsAfterCommit, projectContext
  - Enum: AutoFailureHandling (pauseForUser, retryThenSkip, retryThenStop)

- [x] **Task 1.2**: Create ProjectConfiguration model
  - File: `ClaudeManager/Models/ProjectConfiguration.swift`
  - Properties: projectType, buildCommand, testCommand
  - Enum: ProjectType (swift, xcode, typescript, javascript, python, rust, go, unknown)

- [x] **Task 1.3**: Add configuration persistence to UserPreferences
  - File: `ClaudeManager/State/UserPreferences.swift`
  - Add autonomousConfig property with UserDefaults storage

---

### Phase 2: Smart Auto-Answer

- [x] **Task 2.1**: Add generateSmartAnswer() method to ExecutionStateMachine
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - Use separate Claude call in plan mode to analyze question
  - Include project context, current plan, current task in prompt
  - Return the chosen option label

- [x] **Task 2.2**: Update handleStreamMessage() for auto-answer
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - When AskUserQuestion detected and autoAnswerEnabled:
    - Call generateSmartAnswer() instead of pausing
    - Log the auto-answer decision
    - Continue execution loop

---

### Phase 3: Auto-Handle Failures

- [ ] **Task 3.1**: Add failure tracking to ExecutionContext
  - File: `ClaudeManager/State/ExecutionContext.swift`
  - Add: taskFailureCount, autonomousConfig properties
  - Add reset in appropriate places

- [ ] **Task 3.2**: Update handlePhaseError() for autonomous failure handling
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - If autoFailureHandling != pauseForUser:
    - Increment taskFailureCount
    - If under maxTaskRetries: retry (phase = .executingTask)
    - If retryThenSkip: skip task and continue
    - If retryThenStop: fail execution

---

### Phase 4: Build/Test Integration

- [ ] **Task 4.1**: Add new execution phases
  - File: `ClaudeManager/Models/ExecutionPhase.swift`
  - Add: runningBuild, runningTests, fixingBuildErrors, fixingTestErrors
  - Add display names and progress weights

- [ ] **Task 4.2**: Create BuildTestService
  - File: `ClaudeManager/Services/BuildTestService.swift`
  - detectProjectType(in: URL) - check for Package.swift, package.json, Cargo.toml, etc.
  - runBuild(in: URL, config: ProjectConfiguration) -> BuildResult
  - runTests(in: URL, config: ProjectConfiguration) -> TestResult
  - BuildResult/TestResult structs with success, output, errorOutput, duration

- [ ] **Task 4.3**: Add build/test state to ExecutionContext
  - File: `ClaudeManager/State/ExecutionContext.swift`
  - Add: projectConfiguration, buildAttempts, testAttempts, lastBuildResult, lastTestResult
  - Add maxBuildFixAttempts, maxTestFixAttempts constants

- [ ] **Task 4.4**: Wire BuildTestService in AppState
  - File: `ClaudeManager/State/AppState.swift`
  - Add buildTestService property
  - Pass to ExecutionStateMachine

- [ ] **Task 4.5**: Add build/test phase handlers
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - runBuild() - execute build command, capture output
  - runTests() - execute test command, capture output
  - fixBuildErrors() - send errors to Claude, commit fix
  - fixTestErrors() - send test failures to Claude, commit fix

- [ ] **Task 4.6**: Update phase transitions for build/test
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - committingImplementation → runningBuild (if enabled) → reviewingCode
  - runningBuild → fixingBuildErrors (if failed) → runningBuild (loop)
  - committingTests → runningTests (if enabled) → clearingContext
  - runningTests → fixingTestErrors (if failed) → runningTests (loop)

---

### Phase 5: Better Prompts

- [ ] **Task 5.1**: Improve executeCurrentTask() prompt
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - Add context about previously completed tasks
  - Reference plan.md structure
  - Include project context from autonomous config

- [ ] **Task 5.2**: Improve runCodeReview() prompt
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - More specific review criteria (DRY, edge cases, error handling)
  - Reference the specific task being reviewed

- [ ] **Task 5.3**: Improve writeTests() prompt
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - Specific test requirements (happy path, edge cases, error conditions)
  - Arrange-Act-Assert pattern guidance

---

### Phase 6: UI Configuration

- [ ] **Task 6.1**: Add autonomous config section to SetupView
  - File: `ClaudeManager/Views/SetupView.swift`
  - Toggle: Enable Autonomous Mode
  - TextField: Project Context (e.g., "Mimicking BEYOND laser show UI")
  - Picker: On Failure (Retry then Skip / Retry then Stop)
  - Stepper: Max Retries (1-10)
  - Toggle: Run Build After Implementation
  - Toggle: Run Tests After Writing

---

## Critical Files
- `ClaudeManager/State/ExecutionStateMachine.swift` - Core loop logic
- `ClaudeManager/State/ExecutionContext.swift` - State properties
- `ClaudeManager/Models/ExecutionPhase.swift` - Phase definitions
- `ClaudeManager/Views/SetupView.swift` - Configuration UI
- `ClaudeManager/State/UserPreferences.swift` - Persistence
