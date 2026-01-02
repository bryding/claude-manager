import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.context.phase == .idle {
                SetupView()
            } else {
                ExecutionView()
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .sheet(item: Bindable(appState.context).pendingQuestion) { question in
            UserQuestionView(pendingQuestion: question)
        }
        .sheet(item: Bindable(appState.context).pendingTaskFailure) { failure in
            TaskFailureView(failure: failure) { response in
                Task {
                    await appState.stateMachine.handleTaskFailureResponse(response)
                }
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(AppState())
    }
}
#endif
