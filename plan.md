# Feature Interview Phase

Add a conversational interview step before plan generation. Claude asks clarifying questions about the feature, and the answers inform better plan creation.

## Flow
```
User clicks Start → .conductingInterview → (questions via UserQuestionView) → .generatingInitialPlan → ...
```

---

## Tasks

### Phase 1: Data Model

- [ ] **Task 1.1**: Create InterviewSession model
  - File: `ClaudeManager/Models/InterviewSession.swift` (new)
  - Create `InterviewQA` struct with: question, answer, timestamp
  - Create `InterviewSession` struct with: featureDescription, exchanges array, startedAt, completedAt
  - Add computed property `isComplete` (returns true if completedAt is set)
  - Add `mutating func addExchange(question:answer:)`
  - Add `mutating func markComplete()`

- [x] **Task 1.2**: Add promptContext computed property to InterviewSession
  - File: `ClaudeManager/Models/InterviewSession.swift`
  - Format all Q&A exchanges into a string for inclusion in plan generation prompt
  - Format: "Q1: ... A1: ... Q2: ... A2: ..."

---

### Phase 2: Execution Phase

- [x] **Task 2.1**: Add conductingInterview case to ExecutionPhase
  - File: `ClaudeManager/Models/ExecutionPhase.swift`
  - Add `case conductingInterview` after `idle`
  - Add to `permissionMode` switch: return `"plan"`
  - Add to `progressWeight` switch: return `0.05`
  - Add to `displayName` switch: return `"Interviewing"`
  - Add to `description` switch: return `"Claude is asking clarifying questions about your feature"`

---

### Phase 3: State Management

- [ ] **Task 3.1**: Add interview state to ExecutionContext
  - File: `ClaudeManager/State/ExecutionContext.swift`
  - Add property: `var interviewSession: InterviewSession?`
  - Add property: `var currentInterviewQuestion: String?` (tracks question being asked)

- [x] **Task 3.2**: Update reset methods to clear interview state
  - File: `ClaudeManager/State/ExecutionContext.swift`
  - In `reset()`: set `interviewSession = nil`, `currentInterviewQuestion = nil`
  - In `resetForNewFeature()`: set `interviewSession = nil`, `currentInterviewQuestion = nil`

---

### Phase 4: Interview Execution

- [x] **Task 4.1**: Modify start() to begin with interview phase
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - After `resetState()`, initialize: `context.interviewSession = InterviewSession(featureDescription: context.featureDescription)`
  - Change: `context.phase = .conductingInterview` (instead of `.generatingInitialPlan`)
  - Update log message: "Starting feature interview"

- [x] **Task 4.2**: Add conductInterview() method
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - Build prompt that asks Claude to analyze feature and ask ONE clarifying question
  - Include previous Q&A exchanges in prompt if any
  - Instruct Claude to respond "INTERVIEW_COMPLETE" if feature is clear
  - Max 5 questions limit
  - Call claudeService.execute() with plan permission mode

- [x] **Task 4.3**: Add interview case to executeCurrentPhase()
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - Add case: `.conductingInterview: try await executeWithRetry(operationName: "Interview") { try await conductInterview() }`

- [x] **Task 4.4**: Handle interview messages for AskUserQuestion detection
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - In conductInterview's message handler: detect AskUserQuestion tool use
  - Store question text in `context.currentInterviewQuestion`
  - Create PendingQuestion and set `context.pendingQuestion`
  - Set `context.phase = .waitingForUser`

- [x] **Task 4.5**: Handle "INTERVIEW_COMPLETE" signal
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - In conductInterview's message handler: check for "INTERVIEW_COMPLETE" in text
  - If found, call `context.interviewSession?.markComplete()`

---

### Phase 5: Answer Handling

- [ ] **Task 5.1**: Update answerQuestion() to record interview answers
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - Before existing logic, check if we're coming from interview phase
  - If `currentInterviewQuestion` is set and `interviewSession` exists and not complete:
    - Call `interviewSession.addExchange(question:answer:)`
    - Clear `currentInterviewQuestion`
    - Set `context.phase = .conductingInterview` (to continue interview)

---

### Phase 6: Phase Transitions

- [ ] **Task 6.1**: Add interview phase transition
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - In `transitionToNextPhase()`, add case for `.conductingInterview`:
    - If `context.interviewSession?.isComplete == true`: set phase to `.generatingInitialPlan`
    - Else: stay in `.conductingInterview` (will ask another question)

---

### Phase 7: Plan Generation Integration

- [x] **Task 7.1**: Include interview context in plan generation prompt
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`
  - In `generateInitialPlan()`, get: `let interviewContext = context.interviewSession?.promptContext ?? ""`
  - Insert `interviewContext` into the prompt after the feature description

---

## Interview Prompt Template

```
You are gathering requirements for a software feature. Analyze the following feature request and ask ONE clarifying question that would help create a better implementation plan.

## Feature Request
{featureDescription}

{previousExchanges if any}

## Instructions
1. If the feature request is clear enough to proceed with planning, respond with exactly: INTERVIEW_COMPLETE
2. Otherwise, use the AskUserQuestion tool to ask ONE important clarifying question
3. Focus on: ambiguous requirements, technical decisions, scope boundaries
4. Do NOT ask about implementation details you can decide yourself
5. Maximum 5 questions total. You have asked {count} so far.
```

---

## Critical Files
- `ClaudeManager/Models/InterviewSession.swift` - New model (to create)
- `ClaudeManager/Models/ExecutionPhase.swift` - Add new phase
- `ClaudeManager/State/ExecutionContext.swift` - Add interview state
- `ClaudeManager/State/ExecutionStateMachine.swift` - Core interview logic
