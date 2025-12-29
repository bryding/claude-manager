import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.context.phase == .idle && appState.context.projectPath == nil {
                SetupView()
            } else {
                // Placeholder for ExecutionView (Task 23)
                Text("Execution View - Phase: \(appState.context.phase.rawValue)")
                    .frame(minWidth: 800, minHeight: 600)
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
