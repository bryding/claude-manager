import SwiftUI

struct PhaseIndicatorView: View {
    let phase: ExecutionPhase

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
            isPulsing = phase.isActive
        }
        .onChange(of: phase) { _, newPhase in
            isPulsing = newPhase.isActive
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(phase.statusColor)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .animation(
                isPulsing
                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
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
