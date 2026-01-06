# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Manager is a SwiftUI macOS app that orchestrates Claude Code CLI in an automated development loop. It runs Claude as a subprocess, parses streaming JSON output, and manages a task-based execution cycle.

## Build Commands

```bash
# Build the project
xcodebuild -project ClaudeManager.xcodeproj -scheme ClaudeManager build

# Run tests
xcodebuild -project ClaudeManager.xcodeproj -scheme ClaudeManager test

# Build for release
xcodebuild -project ClaudeManager.xcodeproj -scheme ClaudeManager -configuration Release build
```

## Architecture

### Core Layers

1. **Models** (`ClaudeManager/Models/`)
   - `ClaudeStreamMessage`: Codable types matching Claude's `--output-format stream-json`
   - `Plan`/`PlanTask`: Parsed representation of plan.md tasks
   - `ExecutionPhase`: State enum for the execution loop (idle → interview → planning → executing → committing → review → tests → completed)

2. **Services** (`ClaudeManager/Services/`)
   - `ClaudeCLIService`: Executes Claude CLI with different permission modes
   - `ClaudeProcess`: Async subprocess wrapper with streaming output via `AsyncThrowingStream`
   - `ClaudeMessageParser`: JSONL parser for stream-json format
   - `PlanService`: Parses and updates plan.md files
   - `GitService`: Git commit and worktree operations
   - `WorktreeService`: Manages git worktrees for parallel development on same project

3. **State** (`ClaudeManager/State/`)
   - `ExecutionStateMachine`: Core loop logic with phase transitions
   - `ExecutionContext`: Observable state container for a single tab's execution
   - `AppState`: Global app state with dependency wiring and multi-tab management
   - `TabState`: Per-tab state including project path, execution context, and logs

4. **Views** (`ClaudeManager/Views/`)
   - `MainView`: Tab bar and content routing
   - `SetupView`: Project selection and feature input with image paste support
   - `ExecutionView`: Split-pane dashboard with progress, tasks, and streaming logs
   - `UserQuestionView`: Modal for answering Claude's questions (single/multi-select or freeform)
   - `TaskFailureView`: Modal shown when a task fails

### Key Integration Points

**Claude CLI Invocation:**
```bash
# Plan mode (read-only analysis)
claude -p --output-format stream-json --permission-mode plan "prompt"

# Execute mode (allows edits)
claude -p --output-format stream-json --permission-mode acceptEdits "prompt"
```

**Detecting User Questions:** Look for `AskUserQuestion` tool in assistant message content blocks and pause execution to show UI.

**Task Completion:** A task is complete when the `result` message has `subtype: "success"`.

### Execution Phases

The state machine progresses through these phases:
- `idle` - Waiting for user to start
- `conductingInterview` - Claude asks clarifying questions
- `generatingInitialPlan` - Creating task breakdown in plan.md
- `executingTask` - Implementing the current task
- `committingImplementation` - Git commit of implementation
- `conductingCodeReview` - Claude reviews its own code
- `committingCodeReview` - Git commit of review fixes
- `writingTests` - Generating tests
- `committingTests` - Git commit of tests
- `runningBuild` / `runningTests` - Verification with auto-fix on failure
- `completed` / `failed` - Terminal states

## Development Workflow

This project uses a plan-driven development loop:

1. `/executeplan` - Identifies next task from plan.md and creates implementation plan
2. Accept plan and implement
3. `/commit` - Commit implementation
4. `/codereview` - Claude reviews its own code
5. `/commit` - Commit review fixes
6. `/writetests` (optional) - Write tests for core logic
7. `/commit` - Commit tests
8. Clear context and repeat

## Code Style

- Use Swift's `@Observable` macro for state management
- Prefer `AsyncThrowingStream` for streaming subprocess output
- Use Foundation `Process` for subprocess management
