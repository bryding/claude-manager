import SwiftUI

struct ControlsView: View {
    // MARK: - Environment

    @Environment(AppState.self) private var appState

    // MARK: - Local State

    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var context: ExecutionContext? {
        appState.context
    }

    private var showContinueButton: Bool {
        context?.appearsStuck ?? false
    }

    // MARK: - Body

    var body: some View {
        if let context {
            controlsContent(context: context)
        } else {
            Text("No active context")
        }
    }

    private func controlsContent(context: ExecutionContext) -> some View {
        HStack(spacing: 16) {
            if context.canStart {
                startButton
            } else {
                pauseResumeButton(context: context)
                stopButton(context: context)
                if showContinueButton {
                    continueButton
                }
            }
            Spacer()
            elapsedTimeDisplay(context: context)
            contextIndicator(context: context)
            costDisplay(context: context)
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
                appState.stateMachine?.stop()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop? Current task progress will be lost.")
        }
    }

    private var showStopConfirmation: Binding<Bool> {
        Binding(
            get: { appState.context?.showStopConfirmation ?? false },
            set: { appState.context?.showStopConfirmation = $0 }
        )
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - View Sections

    private func pauseResumeButton(context: ExecutionContext) -> some View {
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

    private func stopButton(context: ExecutionContext) -> some View {
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

    private var continueButton: some View {
        Button(action: nudgeContinue) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.forward.circle.fill")
                Text("Continue")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(.orange)
    }

    private var startButton: some View {
        Button(action: startExecution) {
            HStack(spacing: 6) {
                Image(systemName: "play.circle.fill")
                Text("Start")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }

    private func elapsedTimeDisplay(context: ExecutionContext) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(formattedElapsedTime(context: context))
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            .font(.callout)
        }
    }

    private func contextIndicator(context: ExecutionContext) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(contextStatusColor(context: context))
                .frame(width: 8, height: 8)

            Text("Context:")
                .foregroundStyle(.secondary)

            Text(formattedContextUsage(context: context))
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(contextTextColor(context: context))
        }
        .font(.callout)
        .help("Context window usage: \(formattedContextUsage(context: context)) used")
    }

    private func costDisplay(context: ExecutionContext) -> some View {
        HStack(spacing: 4) {
            Text("Cost:")
                .foregroundStyle(.secondary)
            Text(formattedCost(context: context))
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.callout)
    }

    // MARK: - Helpers

    private func formattedCost(context: ExecutionContext) -> String {
        String(format: "$%.2f", context.totalCost)
    }

    private func formattedElapsedTime(context: ExecutionContext) -> String {
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

    private func formattedContextUsage(context: ExecutionContext) -> String {
        let percentage = Int(context.contextPercentUsed * 100)
        return "\(percentage)%"
    }

    private func contextStatusColor(context: ExecutionContext) -> Color {
        let remaining = context.contextPercentRemaining
        if remaining < 0.10 {
            return .red
        } else if remaining < 0.25 {
            return .orange
        } else {
            return .green
        }
    }

    private func contextTextColor(context: ExecutionContext) -> Color {
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
        guard let context = appState.context, let stateMachine = appState.stateMachine else { return }
        if context.canResume {
            Task {
                do {
                    try await stateMachine.resume()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } else if context.canPause {
            stateMachine.pause()
        }
    }

    private func requestStop() {
        appState.context?.showStopConfirmation = true
    }

    private func nudgeContinue() {
        appState.context?.suggestedManualInput = "Please continue with the interview or proceed to plan generation if you have enough information."
    }

    private func startExecution() {
        guard let context = appState.context, let stateMachine = appState.stateMachine else { return }
        Task {
            do {
                let hasFeature = !context.featureDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                if !hasFeature, let projectPath = context.projectPath {
                    let planURL = projectPath.appendingPathComponent("plan.md")
                    if FileManager.default.fileExists(atPath: planURL.path) {
                        let planService = PlanService()
                        let plan = try planService.parsePlanFromFile(at: planURL)
                        context.existingPlan = plan
                        try await stateMachine.startWithExistingPlan()
                        return
                    }
                }

                try await stateMachine.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Controls - Running") {
    let appState = AppState()
    appState.context?.phase = .executingTask
    appState.context?.totalCost = 0.42
    appState.context?.startTime = Date().addingTimeInterval(-125)
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - Paused") {
    let appState = AppState()
    appState.context?.phase = .paused
    appState.context?.totalCost = 1.25
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - Idle") {
    let appState = AppState()
    appState.context?.phase = .idle
    appState.context?.totalCost = 0.0
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - High Context Usage") {
    let appState = AppState()
    appState.context?.phase = .executingTask
    appState.context?.totalCost = 0.42
    appState.context?.lastInputTokenCount = 180_000
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - Medium Context Usage") {
    let appState = AppState()
    appState.context?.phase = .executingTask
    appState.context?.totalCost = 0.25
    appState.context?.lastInputTokenCount = 160_000
    return ControlsView()
        .environment(appState)
        .padding()
}

#Preview("Controls - Stuck Interview") {
    let appState = AppState()
    appState.context?.phase = .conductingInterview
    appState.context?.interviewSession = InterviewSession(featureDescription: "Test feature")
    appState.context?.sessionId = "test-session"
    appState.context?.totalCost = 0.10
    return ControlsView()
        .environment(appState)
        .padding()
}
#endif
