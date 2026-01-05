import SwiftUI
import AppKit

struct SetupView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab
    @Environment(AppState.self) private var appState

    // MARK: - Local State

    @State private var isStarting = false
    @State private var errorMessage: String?

    // MARK: - Dependencies

    private let planService = PlanService()

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

    // MARK: - Binding Helpers

    private func binding<T>(for keyPath: WritableKeyPath<AutonomousConfiguration, T>) -> Binding<T> {
        Binding(
            get: { appState.userPreferences.autonomousConfig[keyPath: keyPath] },
            set: { newValue in
                var config = appState.userPreferences.autonomousConfig
                config[keyPath: keyPath] = newValue
                appState.userPreferences.autonomousConfig = config
            }
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            projectSelectionSection
            if context.existingPlan != nil {
                existingPlanSection
            }
            featureDescriptionSection
            autonomousConfigSection
            startButton
            Spacer()
        }
        .padding(32)
        .frame(minWidth: 600, minHeight: 500)
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
            .padding(.vertical, 8)
        }
    }

    private var featureDescriptionSection: some View {
        GroupBox("Feature Description") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe the feature you want to implement:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextEditor(text: Bindable(context).featureDescription)
                    .font(.body)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }
            .padding(.vertical, 8)
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

    private var existingPlanSection: some View {
        GroupBox("Existing Plan Detected") {
            VStack(alignment: .leading, spacing: 12) {
                if let plan = context.existingPlan {
                    let taskCount = plan.tasks.count
                    Text("Found plan.md with \(taskCount) task\(taskCount == 1 ? "" : "s")")
                        .font(.callout)

                    HStack {
                        Button("Resume Plan") {
                            startWithExistingPlan()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Start Fresh") {
                            context.existingPlan = nil
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var autonomousConfigSection: some View {
        let config = appState.userPreferences.autonomousConfig

        return GroupBox("Autonomous Mode") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Autonomous Mode", isOn: binding(for: \.autoAnswerEnabled))

                if config.autoAnswerEnabled {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Project Context")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Mimicking BEYOND laser show UI", text: binding(for: \.projectContext))
                            .textFieldStyle(.roundedBorder)
                    }

                    Picker("On Failure", selection: binding(for: \.autoFailureHandling)) {
                        ForEach(AutoFailureHandling.allCases, id: \.self) { handling in
                            Text(handling.displayName).tag(handling)
                        }
                    }

                    Stepper("Max Retries: \(config.maxTaskRetries)",
                            value: binding(for: \.maxTaskRetries),
                            in: 1...10)

                    Divider()

                    Toggle("Run Build After Implementation", isOn: binding(for: \.runBuildAfterCommit))
                    Toggle("Run Tests After Writing", isOn: binding(for: \.runTestsAfterCommit))
                }
            }
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.2), value: config.autoAnswerEnabled)
        }
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
