# Chat Interface UI Cleanup Plan

## Summary
Clean up the chat interface UI to make Claude's activity clearer, enable multi-line log selection with copy functionality, and fix the broken context indicator display.

---

## Task 1: Fix Context Usage Display (Always Shows 0%)
**Description:** The context percentage is always 0% because `lastInputTokenCount` is overwritten with each individual message's tokens instead of accumulating within a session.

**Files to modify:**
- `ClaudeManager/State/ExecutionContext.swift`

**Changes:**
- [ ] Update `contextPercentRemaining` to use `totalInputTokens` (which already accumulates correctly) instead of `lastInputTokenCount`
- [ ] Remove or repurpose `lastInputTokenCount` since it's redundant with `totalInputTokens`

**Root cause (line 426):**
```swift
lastInputTokenCount = inputTokens  // Overwrites instead of accumulating
```

**Fix:** Use `totalInputTokens` in the percentage calculation instead.

---

## Task 2: Fix ControlsView Layout (Smushed/Cut-off Labels)
**Description:** The context label gets cut off and elements are smushed because there are no minimum width constraints on the stats display.

**Files to modify:**
- `ClaudeManager/Views/ControlsView.swift`

**Changes:**
- [ ] Add `.fixedSize()` to prevent text truncation on labels
- [ ] Group the stats (time, context, cost) with proper spacing
- [ ] Use `.layoutPriority(1)` on the stats group to prevent compression

---

## Task 3: Add "Copy All" Button to Log View
**Description:** Add a button to copy all visible/filtered log entries to clipboard for easy sharing and debugging.

**Files to modify:**
- `ClaudeManager/Views/LogView.swift`

**Changes:**
- [ ] Add "Copy" button to the filter bar
- [ ] Implement copy functionality that formats filtered logs as text
- [ ] Include timestamp, type, and message in copied output

---

## Task 4: Enable Multi-Line Log Selection
**Description:** Currently `.textSelection(.enabled)` is applied per-`Text` view, limiting selection to single log entries. Users should be able to drag-select across multiple entries.

**Files to modify:**
- `ClaudeManager/Views/LogView.swift`

**Changes:**
- [ ] Replace `LazyVStack` + individual `Text` views with a single selectable `Text` view containing all formatted log content
- [ ] Or use `NSTextView` wrapper for proper multi-line selection on macOS
- [ ] Maintain visual formatting (timestamps, colors) while enabling cross-entry selection

---

## Task 5: Improve Log Clarity (Less Abstraction)
**Description:** Make it easier to see what Claude is actually doing by improving log message visibility.

**Files to modify:**
- `ClaudeManager/Views/LogView.swift`

**Changes:**
- [ ] Increase message text prominence (slightly larger or bolder)
- [ ] Consider making type badges smaller/more subtle so messages stand out
- [ ] Ensure long messages wrap properly and are fully readable

---

## Files Summary

| File | Changes |
|------|---------|
| `ClaudeManager/State/ExecutionContext.swift` | Fix context % calculation to use accumulated tokens |
| `ClaudeManager/Views/ControlsView.swift` | Fix layout constraints, prevent label truncation |
| `ClaudeManager/Views/LogView.swift` | Add copy button, enable multi-line selection, improve clarity |
