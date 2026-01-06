# Claude Manager

A macOS app that automates software development by orchestrating Claude Code CLI in a structured execution loop. Describe a feature, and Claude Manager handles implementation, code review, testing, and commits automatically.

## Features

- **Automated Development Loop** - From feature description to committed code with minimal intervention
- **Plan-Driven Execution** - Tasks are broken down into a plan.md file and executed sequentially
- **Interactive Questioning** - Claude can ask clarifying questions during execution, presented via native UI
- **Real-Time Streaming** - Watch Claude's actions in a live log view
- **Multi-Tab Workflow** - Work on multiple projects simultaneously with automatic git worktree support
- **Cost & Context Tracking** - Monitor API costs and context window usage during execution
- **Image Support** - Include screenshots or diagrams with feature descriptions
- **Error Recovery** - Automatic retry and fixing of build/test failures

## Requirements

- macOS 14.0 (Sonoma) or later
- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- Git (for version control integration)

## Installation

### From Source

```bash
git clone https://github.com/yourusername/claude-manager.git
cd claude-manager

# Build the app
xcodebuild -project ClaudeManager.xcodeproj -scheme ClaudeManager build

# Or open in Xcode
open ClaudeManager.xcodeproj
```

The built app will be in `build/Release/Claude Manager.app`.

## Usage

1. **Select a Project** - Choose a folder containing your codebase
2. **Describe Your Feature** - Enter what you want to build (optionally paste images)
3. **Start Execution** - Claude will:
   - Conduct an interview to clarify requirements
   - Generate a task plan
   - Implement each task
   - Review and test the code
   - Commit changes to git
4. **Answer Questions** - Respond to any clarifying questions Claude asks
5. **Review Results** - Check the committed code when complete

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Cmd+]` / `Cmd+[` | Next/Previous tab |
| `Cmd+P` | Pause/Resume execution |
| `Cmd+.` | Stop execution |

### Using an Existing Plan

If your project already has a `plan.md` file, Claude Manager will detect it and offer to continue from where you left off.

## Development

### Build Commands

```bash
# Build
xcodebuild -project ClaudeManager.xcodeproj -scheme ClaudeManager build

# Run tests
xcodebuild -project ClaudeManager.xcodeproj -scheme ClaudeManager test

# Release build
xcodebuild -project ClaudeManager.xcodeproj -scheme ClaudeManager -configuration Release build
```

### Project Structure

```
ClaudeManager/
├── Models/          # Data types and state enums
├── Services/        # CLI integration, parsing, git operations
├── State/           # App state and execution state machine
└── Views/           # SwiftUI views
```

See [CLAUDE.md](CLAUDE.md) for architecture details.

## License

MIT
