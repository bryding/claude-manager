import SwiftUI

struct PhaseIndicatorView: View {
    let phase: ExecutionPhase
    var hasQuestion: Bool = false
    var isInterviewComplete: Bool = false

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            statusDot
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            isPulsing = isActive
        }
        .onChange(of: phase) { _, _ in
            isPulsing = isActive
        }
    }

    private var displayName: String {
        if phase == .conductingInterview && hasQuestion {
            return "Waiting for Answer"
        }
        return phase.displayName
    }

    private var statusDescription: String {
        if phase == .conductingInterview {
            if hasQuestion {
                return "Waiting for your answer..."
            } else if !isInterviewComplete {
                return "Claude is gathering requirements..."
            }
        }
        return phase.description
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .animation(
                isPulsing
                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
    }

    private var statusColor: Color {
        if phase == .conductingInterview && hasQuestion {
            return .yellow
        }
        return phase.statusColor
    }

    private var isActive: Bool {
        if phase == .conductingInterview && hasQuestion {
            return false
        }
        return phase.isActivePhase
    }
}

// MARK: - Preview

#if DEBUG
#Preview("All Phases") {
    VStack(alignment: .leading, spacing: 16) {
        PhaseIndicatorView(phase: .idle)
        PhaseIndicatorView(phase: .generatingInitialPlan)
        PhaseIndicatorView(phase: .executingTask)
        PhaseIndicatorView(phase: .waitingForUser)
        PhaseIndicatorView(phase: .completed)
        PhaseIndicatorView(phase: .failed)
    }
    .padding()
}

#Preview("Interview States") {
    VStack(alignment: .leading, spacing: 16) {
        PhaseIndicatorView(phase: .conductingInterview)
        PhaseIndicatorView(phase: .conductingInterview, hasQuestion: true)
        PhaseIndicatorView(phase: .conductingInterview, isInterviewComplete: true)
    }
    .padding()
}
#endif
