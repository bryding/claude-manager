import SwiftUI

struct ManualInputView: View {
    // MARK: - Environment

    @Environment(AppState.self) private var appState

    // MARK: - Local State

    @State private var inputText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var context: ExecutionContext {
        appState.context
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
            && context.isManualInputAvailable
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            TextField("Send message to Claude...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .disabled(!context.isManualInputAvailable || isSubmitting)
                .onSubmit {
                    if canSubmit {
                        submit()
                    }
                }

            Button(action: submit) {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "paperplane.fill")
                }
            }
            .frame(width: 32, height: 32)
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .padding(8)
        .onChange(of: context.suggestedManualInput) { _, newValue in
            if !newValue.isEmpty {
                inputText = newValue
                appState.context.suggestedManualInput = ""
            }
        }
        .alert("Error", isPresented: showingError, actions: {}) {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Error Alert Binding

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - Actions

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        isSubmitting = true

        Task {
            do {
                try await appState.stateMachine.sendManualInput(text)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Manual Input Available") {
    let context = ExecutionContext()
    context.sessionId = "test-session"
    context.phase = .executingTask
    let appState = AppState(context: context)

    return ManualInputView()
        .environment(appState)
        .frame(width: 600)
        .padding()
}

#Preview("Manual Input Disabled") {
    let appState = AppState()

    return ManualInputView()
        .environment(appState)
        .frame(width: 600)
        .padding()
}

#Preview("With Suggested Input") {
    let context = ExecutionContext()
    context.sessionId = "test-session"
    context.phase = .conductingInterview
    context.suggestedManualInput = "Please continue with the interview."
    let appState = AppState(context: context)

    return ManualInputView()
        .environment(appState)
        .frame(width: 600)
        .padding()
}
#endif
