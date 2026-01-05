import SwiftUI

struct TabContentView: View {
    // MARK: - Properties

    @Environment(Tab.self) private var tab

    // MARK: - Body

    var body: some View {
        Group {
            if tab.context.phase == .idle {
                SetupView()
            } else {
                ExecutionView()
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .sheet(item: Bindable(tab.context).pendingQuestion) { question in
            UserQuestionView(pendingQuestion: question)
        }
        .sheet(item: Bindable(tab.context).pendingTaskFailure) { failure in
            TaskFailureView(failure: failure)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Tab Content - Setup") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.phase = .idle

    return TabContentView()
        .environment(tab)
        .frame(width: 800, height: 600)
}

#Preview("Tab Content - Execution") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.phase = .executingTask

    return TabContentView()
        .environment(tab)
        .frame(width: 800, height: 600)
}
#endif
