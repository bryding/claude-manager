import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.context.phase == .idle && appState.context.projectPath == nil {
                SetupView()
            } else {
                ExecutionView()
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
