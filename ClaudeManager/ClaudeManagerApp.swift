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
                    Button(appState.context.canResume ? "Resume" : "Pause") {
                        togglePauseResume()
                    }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(!appState.context.canPause && !appState.context.canResume)

                    Button("Stop Execution...") {
                        requestStop()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!appState.context.canStop)
                }
            }
        }
    }

    private func togglePauseResume() {
        if appState.context.canResume {
            Task {
                try? await appState.stateMachine.resume()
            }
        } else if appState.context.canPause {
            appState.stateMachine.pause()
        }
    }

    private func requestStop() {
        appState.context.showStopConfirmation = true
    }
}
