import SwiftUI
import AppKit

struct SetupView: View {
    // MARK: - Environment

    @Environment(AppState.self) private var appState

    // MARK: - Local State

    @State private var isStarting = false
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var hasProjectPath: Bool {
        appState.context.projectPath != nil
    }

    private var canStart: Bool {
        hasProjectPath &&
        !appState.context.featureDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isStarting
    }

    private var projectPathDisplay: String {
        appState.context.projectPath?.path(percentEncoded: false) ?? "No project selected"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            projectSelectionSection
            featureDescriptionSection
            startButton
            Spacer()
        }
        .padding(32)
        .frame(minWidth: 600, minHeight: 500)
        .alert("Error", isPresented: showingError, actions: {}) {
            Text(errorMessage ?? "")
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
            @Bindable var context = appState.context

            VStack(alignment: .leading, spacing: 8) {
                Text("Describe the feature you want to implement:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextEditor(text: $context.featureDescription)
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
        if response == .OK {
            appState.context.projectPath = panel.url
        }
    }

    private func startDevelopmentLoop() {
        isStarting = true

        Task {
            do {
                try await appState.stateMachine.start()
            } catch {
                errorMessage = error.localizedDescription
            }
            isStarting = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView()
            .environment(AppState())
    }
}
#endif
