import SwiftUI

struct UserQuestionView: View {
    // MARK: - Environment

    @Environment(Tab.self) private var tab
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let pendingQuestion: PendingQuestion

    // MARK: - Local State

    @State private var selectedOptions: Set<String> = []
    @State private var freeformText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var stateMachine: ExecutionStateMachine {
        tab.stateMachine
    }

    private var question: AskUserQuestionInput.Question {
        pendingQuestion.question
    }

    private var hasOptions: Bool {
        !question.options.isEmpty
    }

    private var canSubmit: Bool {
        if hasOptions {
            return !selectedOptions.isEmpty
        } else {
            return !freeformText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            questionSection
            if hasOptions {
                optionsSection
            } else {
                freeformSection
            }
            Spacer()
            buttonSection
        }
        .padding(24)
        .frame(minWidth: 500, idealWidth: 550, minHeight: 400)
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

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            Text(question.header)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var questionSection: some View {
        Text(question.question)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var optionsSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                if question.multiSelect {
                    multiSelectOptions
                } else {
                    singleSelectOptions
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var singleSelectOptions: some View {
        ForEach(question.options, id: \.label) { option in
            OptionRow(
                option: option,
                isSelected: selectedOptions.contains(option.label),
                isMultiSelect: false,
                action: { selectedOptions = [option.label] }
            )
        }
    }

    private var multiSelectOptions: some View {
        ForEach(question.options, id: \.label) { option in
            OptionRow(
                option: option,
                isSelected: selectedOptions.contains(option.label),
                isMultiSelect: true,
                action: {
                    if selectedOptions.contains(option.label) {
                        selectedOptions.remove(option.label)
                    } else {
                        selectedOptions.insert(option.label)
                    }
                }
            )
        }
    }

    private var freeformSection: some View {
        GroupBox("Your Response") {
            TextEditor(text: $freeformText)
                .font(.body)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
    }

    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button("Skip") {
                skip()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isSubmitting)

            Button(action: submit) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                    Text("Submit")
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit || isSubmitting)
        }
    }

    // MARK: - Actions

    private func submit() {
        let answer: String
        if hasOptions {
            answer = selectedOptions.sorted().joined(separator: ", ")
        } else {
            answer = freeformText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        sendAnswer(answer)
    }

    private func skip() {
        sendAnswer("skipped")
    }

    private func sendAnswer(_ answer: String) {
        isSubmitting = true
        Task {
            do {
                try await stateMachine.answerQuestion(answer)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Option Row

private struct OptionRow: View {
    let option: AskUserQuestionInput.Option
    let isSelected: Bool
    let isMultiSelect: Bool
    let action: () -> Void

    private var iconName: String {
        if isMultiSelect {
            return isSelected ? "checkmark.square.fill" : "square"
        } else {
            return isSelected ? "circle.inset.filled" : "circle"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(option.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Single Select") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)

    let question = PendingQuestion(
        toolUseId: "test-1",
        question: AskUserQuestionInput.Question(
            question: "Which approach would you prefer for implementing the authentication system?",
            header: "Authentication Method",
            options: [
                AskUserQuestionInput.Option(
                    label: "OAuth 2.0",
                    description: "Industry standard protocol with support for third-party providers"
                ),
                AskUserQuestionInput.Option(
                    label: "JWT Tokens",
                    description: "Stateless authentication using JSON Web Tokens"
                ),
                AskUserQuestionInput.Option(
                    label: "Session-based",
                    description: "Traditional server-side session management"
                )
            ],
            multiSelect: false
        )
    )

    return UserQuestionView(pendingQuestion: question)
        .environment(tab)
}

#Preview("Multi Select") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)

    let question = PendingQuestion(
        toolUseId: "test-2",
        question: AskUserQuestionInput.Question(
            question: "Which features should be included in the initial release?",
            header: "Feature Selection",
            options: [
                AskUserQuestionInput.Option(
                    label: "User Profiles",
                    description: "Allow users to customize their profile"
                ),
                AskUserQuestionInput.Option(
                    label: "Dark Mode",
                    description: "Support for dark color scheme"
                ),
                AskUserQuestionInput.Option(
                    label: "Notifications",
                    description: "Push notification support"
                )
            ],
            multiSelect: true
        )
    )

    return UserQuestionView(pendingQuestion: question)
        .environment(tab)
}

#Preview("Freeform") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)

    let question = PendingQuestion(
        toolUseId: "test-3",
        question: AskUserQuestionInput.Question(
            question: "Please describe the specific behavior you'd like for the error handling system.",
            header: "Error Handling",
            options: [],
            multiSelect: false
        )
    )

    return UserQuestionView(pendingQuestion: question)
        .environment(tab)
}
#endif
