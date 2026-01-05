# Fix Interview Process and Execution Transition Bugs

Fix bugs in the interview modal, question handling, and transition to autonomous execution mode.

## Task 1: Add Question Queue to ExecutionContext ✅
**Description:** Add a question queue property to ExecutionContext to store incoming questions instead of overwriting them.

- [x] Add `var questionQueue: [PendingQuestion] = []` property after `pendingQuestion`
- [x] Add `var hasQueuedQuestions: Bool` computed property
- [x] Update `reset()` method to clear `questionQueue = []`
- [x] Update `resetForNewFeature()` method to clear `questionQueue = []`

## Task 2: Fix Session Resume for Interview Follow-ups
**Description:** Stop resuming the Claude session for subsequent interview calls to prevent tool result confusion.

- [ ] In `conductInterview()`, change `isFirstCall` check to only look at `interviewSession.exchanges.isEmpty`
- [ ] Create `effectiveSessionId` that is `nil` for non-first calls
- [ ] Pass `effectiveSessionId` instead of `context.sessionId` to `claudeService.execute()`
- [ ] Verify previous Q&A is included in prompt text via `previousExchanges`

## Task 3: Implement Question Queuing in handleAskUserQuestion
**Description:** Replace direct assignment of pendingQuestion with queue-based approach that handles multiple questions.

- [ ] Extract ALL questions from `input.questions`, not just first
- [ ] Append each question to `context.questionQueue`
- [ ] Only call `showNextQueuedQuestion()` if `context.pendingQuestion == nil`
- [ ] Add new helper method `showNextQueuedQuestion(mode:)` that dequeues and displays

## Task 4: Process Question Queue After Answering
**Description:** Modify answerQuestion to check queue before resuming the main loop.

- [ ] After clearing `pendingQuestion`, check `context.hasQueuedQuestions`
- [ ] If queue has items, call `showNextQueuedQuestion()` and return early
- [ ] Only call `runLoop()` when queue is empty
- [ ] Remove `guard context.sessionId != nil` check (may not have sessionId on subsequent calls)

## Task 5: Add Unit Tests for Question Queue
**Description:** Write tests to verify the question queuing behavior works correctly.

- [ ] Test multiple questions in single message are queued
- [ ] Test answering question shows next from queue
- [ ] Test all Q&A pairs recorded in interviewSession.exchanges
- [ ] Test empty queue resumes main loop
- [ ] Test queue cleared on reset

## Task 6: End-to-End Verification
**Description:** Manually test the complete flow from feature description to execution.

- [ ] Start new feature description and verify interview questions appear one at a time
- [ ] Verify modal stays open until submit button is pressed
- [ ] Verify Claude doesn't spam the same question after answering
- [ ] Verify interview completes and transitions to plan generation
- [ ] Verify plan generation creates valid tasks
- [ ] Verify execution starts with tasks visible in left panel
