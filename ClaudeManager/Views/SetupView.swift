import SwiftUI
import AppKit

struct SetupView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab
    @Environment(AppState.self) private var appState

    // MARK: - Local State

    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var imageError: String?

    // MARK: - Dependencies

    private let planService = PlanService()
    private let imageProcessor = ImageProcessor()

    // MARK: - Computed Properties

    private var context: ExecutionContext {
        tab.context
    }

    private var stateMachine: ExecutionStateMachine {
        tab.stateMachine
    }

    private var hasProjectPath: Bool {
        context.projectPath != nil
    }

    private var canStart: Bool {
        let hasFeature = !context.featureDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasExistingPlan = context.existingPlan != nil
        return hasProjectPath && (hasExistingPlan || hasFeature) && !isStarting
    }

    private var projectPathDisplay: String {
        context.projectPath?.path(percentEncoded: false) ?? "No project selected"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    existingPlanBanner
                    projectSelectionSection
                    featureDescriptionSection
                }
                .padding(24)
            }
            .frame(maxHeight: .infinity)
            .scrollContentBackground(.hidden)

            Divider()

            startButton
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        }
        .alert("Error", isPresented: showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            if context.projectPath == nil,
               let lastPath = appState.userPreferences.lastProjectPath {
                await setProjectPath(lastPath)
            } else if context.projectPath != nil {
                checkForExistingPlan()
            }
        }
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - View Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Claude Manager")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Automated development with Claude Code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var projectSelectionSection: some View {
        GroupBox("Project Directory") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Select Folder...") {
                        Task {
                            await selectDirectory()
                        }
                    }

                    if !appState.userPreferences.recentProjects.isEmpty {
                        recentProjectsMenu
                    }

                    Spacer()
                }

                HStack {
                    Image(systemName: hasProjectPath ? "folder.fill" : "folder")
                        .foregroundStyle(hasProjectPath ? .blue : .secondary)
                    Text(projectPathDisplay)
                        .foregroundStyle(hasProjectPath ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .font(.callout)
            }
            .padding(.vertical, 4)
        }
    }

    private var featureDescriptionSection: some View {
        GroupBox("Feature Description") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe the feature you want to implement:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !context.attachedImages.isEmpty {
                    AttachedImagesView(
                        images: context.attachedImages,
                        onRemove: { id in
                            context.removeImage(id: id)
                        },
                        onRemoveAll: {
                            context.removeAllImages()
                        }
                    )
                }

                PastableTextEditor(text: Bindable(tab.context).featureDescription) { image in
                    handleImagePaste(image)
                }
                .frame(minHeight: 150)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text("You can paste or drag images (PNG, JPEG) to include with your description")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let imageError = imageError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(imageError)
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Image Handling

    private func handleImagePaste(_ image: NSImage) {
        imageError = nil

        switch imageProcessor.process(image: image) {
        case .success(let attachedImage):
            context.addImage(attachedImage)
        case .failure(let error):
            imageError = error.displayMessage
        }
    }

    @ViewBuilder
    private var existingPlanBanner: some View {
        if let plan = context.existingPlan {
            let taskCount = plan.tasks.count
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.blue)

                Text("Found plan.md with \(taskCount) task\(taskCount == 1 ? "" : "s")")
                    .font(.callout)

                Spacer()

                Button("Use Existing Plan") {
                    startWithExistingPlan()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Dismiss") {
                    context.existingPlan = nil
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var recentProjectsMenu: some View {
        Menu {
            ForEach(appState.userPreferences.recentProjects, id: \.self) { url in
                Button(action: { selectRecentProject(url) }) {
                    Label(url.lastPathComponent, systemImage: "folder")
                }
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .menuStyle(.borderlessButton)
        .help("Recent Projects")
    }

    private var startButton: some View {
        Button(action: startDevelopmentLoop) {
            HStack(spacing: 8) {
                if isStarting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
                Text("Start Development Loop")
            }
            .frame(minWidth: 200)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canStart)
    }

    // MARK: - Actions

    private func selectDirectory() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory"
        panel.prompt = "Select"

        let response = await panel.begin()
        if response == .OK, let url = panel.url {
            await setProjectPath(url)
        }
    }

    private func selectRecentProject(_ url: URL) {
        Task {
            await setProjectPath(url)
        }
    }

    private func setProjectPath(_ url: URL) async {
        do {
            try await appState.tabManager.setProjectPath(url, for: tab)
            appState.userPreferences.lastProjectPath = url
            checkForExistingPlan()
        } catch {
            errorMessage = "Failed to set project path: \(error.localizedDescription)"
        }
    }

    private func checkForExistingPlan() {
        guard let projectPath = context.projectPath else {
            context.existingPlan = nil
            return
        }

        let planURL = projectPath.appendingPathComponent("plan.md")

        if FileManager.default.fileExists(atPath: planURL.path) {
            do {
                let plan = try planService.parsePlanFromFile(at: planURL)
                context.existingPlan = plan
            } catch {
                context.existingPlan = nil
            }
        } else {
            context.existingPlan = nil
        }
    }

    private func startWithExistingPlan() {
        isStarting = true

        Task {
            do {
                try await stateMachine.startWithExistingPlan()
            } catch {
                errorMessage = error.localizedDescription
            }
            isStarting = false
        }
    }

    private func startDevelopmentLoop() {
        isStarting = true

        Task {
            do {
                let hasFeature = !context.featureDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                if !hasFeature, let projectPath = context.projectPath {
                    let planURL = projectPath.appendingPathComponent("plan.md")
                    if FileManager.default.fileExists(atPath: planURL.path) {
                        let plan = try planService.parsePlanFromFile(at: planURL)
                        context.existingPlan = plan
                        try await stateMachine.startWithExistingPlan()
                        isStarting = false
                        return
                    }
                }

                try await stateMachine.start()
            } catch {
                errorMessage = error.localizedDescription
            }
            isStarting = false
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SetupView") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)

    return SetupView()
        .environment(tab)
        .environment(appState)
        .frame(width: 700, height: 600)
}
#endif
