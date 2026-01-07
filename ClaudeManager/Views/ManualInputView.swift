import SwiftUI

struct ManualInputView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab

    // MARK: - Local State

    @State private var inputText: String = ""
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var context: ExecutionContext {
        tab.context
    }

    private var stateMachine: ExecutionStateMachine {
        tab.stateMachine
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                .disabled(!context.isManualInputAvailable)
                .onSubmit {
                    if canSubmit {
                        submit()
                    }
                }

            Button(action: submit) {
                Image(systemName: "paperplane.fill")
            }
            .frame(width: 32, height: 32)
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .padding(8)
        .onChange(of: context.suggestedManualInput) { _, newValue in
            if !newValue.isEmpty {
                inputText = newValue
                context.suggestedManualInput = ""
            }
        }
        .alert("Error", isPresented: showingError) {
            Button("OK", role: .cancel) {}
        } message: {
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

        Task {
            do {
                try await stateMachine.sendManualInput(text)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Manual Input Available") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.sessionId = "test-session"
    tab.context.phase = .executingTask

    return ManualInputView()
        .environment(tab)
        .frame(width: 600)
        .padding()
}

#Preview("Manual Input Disabled") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)

    return ManualInputView()
        .environment(tab)
        .frame(width: 600)
        .padding()
}

#Preview("With Suggested Input") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.sessionId = "test-session"
    tab.context.phase = .conductingInterview
    tab.context.suggestedManualInput = "Please continue with the interview."

    return ManualInputView()
        .environment(tab)
        .frame(width: 600)
        .padding()
}
#endif
