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

    private var isWaitingForInterviewAnswer: Bool {
        context.hasPendingInterviewQuestion
    }

    private var canSubmit: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Allow submission if waiting for interview answer OR if manual input is available
        return hasText && (isWaitingForInterviewAnswer || context.isManualInputAvailable)
    }

    private var placeholderText: String {
        if isWaitingForInterviewAnswer {
            return "Type your answer..."
        }
        return "Send message to Claude..."
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if isWaitingForInterviewAnswer {
                interviewPromptBar
            }

            HStack(spacing: 8) {
                TextField(placeholderText, text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isWaitingForInterviewAnswer ? Color.orange : Color(nsColor: .separatorColor),
                                lineWidth: isWaitingForInterviewAnswer ? 2 : 1
                            )
                    )
                    .disabled(!canSubmit && !isWaitingForInterviewAnswer)
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
        }
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

    private var interviewPromptBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.orange)
            Text("Answer the question above")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Skip") {
                skipInterviewQuestion()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
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
                if isWaitingForInterviewAnswer {
                    // Answer the interview question
                    try await stateMachine.answerInterviewQuestion(text)
                } else {
                    // Regular manual input
                    try await stateMachine.sendManualInput(text)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func skipInterviewQuestion() {
        inputText = ""

        Task {
            do {
                try await stateMachine.answerInterviewQuestion("skipped")
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

#Preview("Interview Question Pending") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.sessionId = "test-session"
    tab.context.phase = .waitingForUser
    tab.context.pendingInterviewQuestion = PendingQuestion(
        toolUseId: "test-1",
        question: AskUserQuestionInput.Question(
            question: "Which approach would you prefer?",
            header: "Implementation",
            options: [],
            multiSelect: false
        )
    )

    return ManualInputView()
        .environment(tab)
        .frame(width: 600)
        .padding()
}
#endif
