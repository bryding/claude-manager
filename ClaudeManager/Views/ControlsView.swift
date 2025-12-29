import SwiftUI

struct ControlsView: View {
    // MARK: - Environment

    @Environment(AppState.self) private var appState

    // MARK: - Local State

    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var context: ExecutionContext {
        appState.context
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            pauseResumeButton
            stopButton
            Spacer()
            costDisplay
        }
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

    private var pauseResumeButton: some View {
        Button(action: togglePauseResume) {
            HStack(spacing: 6) {
                Image(systemName: context.canResume ? "play.circle.fill" : "pause.circle.fill")
                Text(context.canResume ? "Resume" : "Pause")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!context.canPause && !context.canResume)
    }

    private var stopButton: some View {
        Button(action: stop) {
            HStack(spacing: 6) {
                Image(systemName: "stop.circle.fill")
                Text("Stop")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(.red)
        .disabled(!context.canStop)
    }

    private var costDisplay: some View {
        HStack(spacing: 4) {
            Text("Cost:")
                .foregroundStyle(.secondary)
            Text(formattedCost)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.callout)
    }

    // MARK: - Helpers

    private var formattedCost: String {
        String(format: "$%.2f", context.totalCost)
    }

    // MARK: - Actions

    private func togglePauseResume() {
        if context.canResume {
            Task {
                do {
                    try await appState.stateMachine.resume()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } else if context.canPause {
            appState.stateMachine.pause()
        }
    }

    private func stop() {
        appState.stateMachine.stop()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Controls - Running") {
    let appState = AppState()
    appState.context.phase = .executingTask
    appState.context.totalCost = 0.42
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - Paused") {
    let appState = AppState()
    appState.context.phase = .paused
    appState.context.totalCost = 1.25
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - Idle") {
    let appState = AppState()
    appState.context.phase = .idle
    appState.context.totalCost = 0.0
    return ControlsView()
        .environment(appState)
        .padding()
}
#endif
