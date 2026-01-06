import SwiftUI

struct ControlsView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab

    // MARK: - Local State

    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var context: ExecutionContext {
        tab.context
    }

    private var stateMachine: ExecutionStateMachine {
        tab.stateMachine
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            if context.canStart {
                startButton
            } else {
                pauseResumeButton
                stopButton
                if context.appearsStuck {
                    continueButton
                }
            }
            Spacer()
            elapsedTimeDisplay
            contextIndicator
            costDisplay
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.ControlsView.controlsView)
        .alert("Error", isPresented: showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Stop Execution?",
            isPresented: showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                stateMachine.stop()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.ControlsView.stopConfirmationDialog)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop? Current task progress will be lost.")
        }
    }

    private var showStopConfirmation: Binding<Bool> {
        Binding(
            get: { context.showStopConfirmation },
            set: { context.showStopConfirmation = $0 }
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
        .accessibilityIdentifier(
            context.canResume
                ? AccessibilityIdentifiers.ControlsView.resumeButton
                : AccessibilityIdentifiers.ControlsView.pauseButton
        )
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
        .accessibilityIdentifier(AccessibilityIdentifiers.ControlsView.stopButton)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.ControlsView.continueButton)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.ControlsView.startButton)
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
            .accessibilityIdentifier(AccessibilityIdentifiers.ControlsView.elapsedTimeDisplay)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.ControlsView.costDisplay)
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
        contextColor(forRemaining: context.contextPercentRemaining, defaultColor: .green)
    }

    private var contextTextColor: Color {
        contextColor(forRemaining: context.contextPercentRemaining, defaultColor: .primary)
    }

    private func contextColor(forRemaining remaining: Double, defaultColor: Color) -> Color {
        if remaining < 0.10 {
            return .red
        } else if remaining < 0.25 {
            return .orange
        } else {
            return defaultColor
        }
    }

    // MARK: - Actions

    private func togglePauseResume() {
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
        context.showStopConfirmation = true
    }

    private func nudgeContinue() {
        context.suggestedManualInput = "Please continue with the interview or proceed to plan generation if you have enough information."
    }

    private func startExecution() {
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
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .executingTask
    tab.context.totalCost = 0.42
    tab.context.startTime = Date().addingTimeInterval(-125)
    return ControlsView()
        .environment(tab)
        .padding()
}

#Preview("Controls - Paused") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .paused
    tab.context.totalCost = 1.25
    return ControlsView()
        .environment(tab)
        .padding()
}

#Preview("Controls - Idle") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .idle
    tab.context.totalCost = 0.0
    return ControlsView()
        .environment(tab)
        .padding()
}

#Preview("Controls - High Context Usage") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .executingTask
    tab.context.totalCost = 0.42
    tab.context.lastInputTokenCount = 180_000
    return ControlsView()
        .environment(tab)
        .padding()
}

#Preview("Controls - Medium Context Usage") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .executingTask
    tab.context.totalCost = 0.25
    tab.context.lastInputTokenCount = 160_000
    return ControlsView()
        .environment(tab)
        .padding()
}

#Preview("Controls - Stuck Interview") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .conductingInterview
    tab.context.interviewSession = InterviewSession(featureDescription: "Test feature")
    tab.context.sessionId = "test-session"
    tab.context.totalCost = 0.10
    return ControlsView()
        .environment(tab)
        .padding()
}
#endif
