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
                Text(phase.displayName)
                    .font(.headline)
                Text(phase.description)
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
        switch phase {
        case .idle, .paused:
            return .gray
        case .waitingForUser:
            return .yellow
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .blue
        }
    }

    private var isActive: Bool {
        switch phase {
        case .idle, .paused, .waitingForUser, .completed, .failed:
            return false
        default:
            return true
        }
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
#endif
