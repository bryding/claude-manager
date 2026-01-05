import SwiftUI

struct ContentView: View {
    @Environment(Tab.self) private var tab

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
            TaskFailureView(failure: failure) { response in
                Task {
                    await tab.stateMachine.handleTaskFailureResponse(response)
                }
            }
        }
    }
}

#if DEBUG
#Preview("ContentView - Setup") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.phase = .idle

    return ContentView()
        .environment(tab)
        .frame(width: 800, height: 600)
}

#Preview("ContentView - Execution") {
    let tab = Tab.create(userPreferences: UserPreferences())
    tab.context.phase = .executingTask

    return ContentView()
        .environment(tab)
        .frame(width: 800, height: 600)
}
#endif
