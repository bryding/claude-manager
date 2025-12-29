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
            elapsedTimeDisplay
            contextIndicator
            costDisplay
        }
        .alert("Error", isPresented: showingError, actions: {}) {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Stop Execution?",
            isPresented: showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                appState.stateMachine.stop()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop? Current task progress will be lost.")
        }
    }

    private var showStopConfirmation: Binding<Bool> {
        Binding(
            get: { appState.context.showStopConfirmation },
            set: { appState.context.showStopConfirmation = $0 }
        )
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
        Button(action: requestStop) {
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

    private var elapsedTimeDisplay: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(formattedElapsedTime)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            .font(.callout)
        }
    }

    private var contextIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(contextStatusColor)
                .frame(width: 8, height: 8)

            Text("Context:")
                .foregroundStyle(.secondary)

            Text(formattedContextUsage)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(contextTextColor)
        }
        .font(.callout)
        .help("Context window usage: \(formattedContextUsage) used")
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

    private var formattedElapsedTime: String {
        guard let elapsed = context.elapsedTime else { return "--:--" }
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private var formattedContextUsage: String {
        let percentage = Int(context.contextPercentUsed * 100)
        return "\(percentage)%"
    }

    private var contextStatusColor: Color {
        let remaining = context.contextPercentRemaining
        if remaining < 0.10 {
            return .red
        } else if remaining < 0.25 {
            return .orange
        } else {
            return .green
        }
    }

    private var contextTextColor: Color {
        let remaining = context.contextPercentRemaining
        if remaining < 0.10 {
            return .red
        } else if remaining < 0.25 {
            return .orange
        } else {
            return .primary
        }
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

    private func requestStop() {
        appState.context.showStopConfirmation = true
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Controls - Running") {
    let appState = AppState()
    appState.context.phase = .executingTask
    appState.context.totalCost = 0.42
    appState.context.startTime = Date().addingTimeInterval(-125)
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

#Preview("Controls - High Context Usage") {
    let appState = AppState()
    appState.context.phase = .executingTask
    appState.context.totalCost = 0.42
    appState.context.lastInputTokenCount = 180_000
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - Medium Context Usage") {
    let appState = AppState()
    appState.context.phase = .executingTask
    appState.context.totalCost = 0.25
    appState.context.lastInputTokenCount = 160_000
    return ControlsView()
        .environment(appState)
        .padding()
}
#endif
