# Plan: Add Image Paste Support to Feature Description

Add the ability to paste/drag-drop PNG and JPEG images into the feature description input. Images are displayed as thumbnails and passed to Claude CLI via stdin as base64-encoded content blocks.

---

## Tasks

### Phase 1: Models

- [x] **Task 1.1**: Create `AttachedImage.swift` model
  - `id: UUID`, `data: Data`, `mediaType: ImageMediaType`, `thumbnail: NSImage`, `originalSize: CGSize`
  - Computed: `base64Encoded`, `fileSizeDescription`
  - File: `ClaudeManager/Models/AttachedImage.swift`

- [x] **Task 1.2**: Create `PromptContent.swift` model
  - `PromptContent` struct with `text: String`, `images: [AttachedImage]`
  - `ClaudeContentBlock` for building JSON stdin content
  - File: `ClaudeManager/Models/PromptContent.swift`

### Phase 2: Utility

- [x] **Task 2.1**: Create `ImageProcessor.swift` utility
  - Process NSImage from paste/drop
  - Validate PNG/JPEG, create thumbnails (120x120), enforce 20MB limit
  - File: `ClaudeManager/Utilities/ImageProcessor.swift`

### Phase 3: State Layer

- [x] **Task 3.1**: Update `ExecutionContext.swift`
  - Add `attachedImages: [AttachedImage]` property
  - Add `addImage()`, `removeImage(id:)`, `removeAllImages()` methods
  - Add `promptContent` computed property
  - Update `reset()` and `resetForNewFeature()` to clear images
  - File: `ClaudeManager/State/ExecutionContext.swift`

- [x] **Task 3.2**: Update `InterviewSession.swift`
  - Add `attachedImages: [AttachedImage]` property
  - Update init to accept images
  - File: `ClaudeManager/Models/InterviewSession.swift`

### Phase 4: Service Layer

- [x] **Task 4.1**: Add stdin support to `ClaudeProcess.swift`
  - Add `stdinData: Data?` parameter to init
  - Write stdin data after process.run(), close handle
  - File: `ClaudeManager/Services/ClaudeProcess.swift`

- [ ] **Task 4.2**: Update `ClaudeCLIServiceProtocol.swift`
  - Add `execute(content: PromptContent, ...)` method signature
  - File: `ClaudeManager/Services/Protocols/ClaudeCLIServiceProtocol.swift`

- [ ] **Task 4.3**: Update `ClaudeCLIService.swift`
  - Implement content-based execution
  - Build JSON content blocks for stdin when images present
  - Delegate to text-based method when no images
  - File: `ClaudeManager/Services/ClaudeCLIService.swift`

- [ ] **Task 4.4**: Update `MockClaudeCLIService.swift`
  - Add `lastContent` property and content-based execute method
  - File: `ClaudeManagerTests/Mocks/MockClaudeCLIService.swift`

### Phase 5: View Layer

- [x] **Task 5.1**: Create `PastableTextEditor.swift`
  - NSViewRepresentable wrapping NSTextView
  - Override paste to detect images from NSPasteboard
  - Support drag-and-drop via registerForDraggedTypes
  - Callback: `onImagePaste: (NSImage) -> Void`
  - File: `ClaudeManager/Views/Components/PastableTextEditor.swift`

- [ ] **Task 5.2**: Create `ImageThumbnailView.swift`
  - 80x80 thumbnail with hover-to-remove X button
  - Show file size and dimensions in tooltip
  - File: `ClaudeManager/Views/Components/ImageThumbnailView.swift`

- [ ] **Task 5.3**: Create `AttachedImagesView.swift`
  - Horizontal ScrollView of thumbnails
  - "Remove All" button, image count label
  - File: `ClaudeManager/Views/Components/AttachedImagesView.swift`

- [ ] **Task 5.4**: Update `SetupView.swift`
  - Replace TextEditor with PastableTextEditor
  - Add AttachedImagesView above text input
  - Add drop delegate for drag-and-drop
  - Add hint text and error display
  - File: `ClaudeManager/Views/SetupView.swift`

### Phase 6: Integration

- [ ] **Task 6.1**: Update `ExecutionStateMachine.swift`
  - In `start()`: pass `attachedImages` to InterviewSession
  - In `conductInterview()`: use `execute(content:...)` with images
  - In `generateInitialPlan()`: include images in first prompt
  - File: `ClaudeManager/State/ExecutionStateMachine.swift`

### Phase 7: Testing

- [ ] **Task 7.1**: Add `ImageProcessorTests.swift`
  - Test PNG/JPEG processing, thumbnail creation, size limits
  - File: `ClaudeManagerTests/ImageProcessorTests.swift`

---

## Key Implementation Notes

- **Stdin format:** Claude CLI accepts JSON content blocks via stdin with base64-encoded images
- **No temp files:** Images stored in memory, passed directly to CLI
- **Size limit:** 20MB per image (accounts for base64 expansion)
- **Supported formats:** PNG, JPEG
