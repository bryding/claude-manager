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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .idle

    return TabContentView()
        .environment(tab)
        .environment(appState)
        .frame(width: 800, height: 600)
}

#Preview("Tab Content - Setup (Small)") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .idle

    return TabContentView()
        .environment(tab)
        .environment(appState)
        .frame(width: 500, height: 400)
}

#Preview("Tab Content - Execution") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .executingTask
    tab.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")

    return TabContentView()
        .environment(tab)
        .environment(appState)
        .frame(width: 900, height: 600)
}

#Preview("Tab Content - Execution (Small)") {
    let appState = AppState()
    let tab = Tab.create(userPreferences: appState.userPreferences)
    tab.context.phase = .executingTask
    tab.context.projectPath = URL(fileURLWithPath: "/Users/demo/MyProject")

    return TabContentView()
        .environment(tab)
        .environment(appState)
        .frame(width: 600, height: 400)
}
#endif
