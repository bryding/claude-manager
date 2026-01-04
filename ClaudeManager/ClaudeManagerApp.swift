import SwiftUI

@main
struct ClaudeManagerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Section {
                    Button(appState.context?.canResume == true ? "Resume" : "Pause") {
                        togglePauseResume()
                    }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(appState.context?.canPause != true && appState.context?.canResume != true)

                    Button("Stop Execution...") {
                        requestStop()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(appState.context?.canStop != true)
                }
            }
        }
    }

    private func togglePauseResume() {
        guard let context = appState.context, let stateMachine = appState.stateMachine else { return }
        if context.canResume {
            Task {
                try? await stateMachine.resume()
            }
        } else if context.canPause {
            stateMachine.pause()
        }
    }

    private func requestStop() {
        appState.context?.showStopConfirmation = true
    }
}
