import SwiftUI

@main
struct ClaudeManagerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    createNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Close Tab") {
                    closeCurrentTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.activeTab == nil)
            }

            CommandGroup(after: .appSettings) {
                Section {
                    Button(appState.activeTab?.context.canResume == true ? "Resume" : "Pause") {
                        togglePauseResume()
                    }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(appState.activeTab?.context.canPause != true && appState.activeTab?.context.canResume != true)

                    Button("Stop Execution...") {
                        requestStop()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(appState.activeTab?.context.canStop != true)
                }
            }
        }
    }

    private func createNewTab() {
        appState.tabManager.createTab()
    }

    private func closeCurrentTab() {
        guard let tab = appState.activeTab else { return }
        appState.tabManager.closeTab(tab)
    }

    private func togglePauseResume() {
        guard let tab = appState.activeTab else { return }
        if tab.context.canResume {
            Task {
                try? await tab.stateMachine.resume()
            }
        } else if tab.context.canPause {
            tab.stateMachine.pause()
        }
    }

    private func requestStop() {
        appState.activeTab?.context.showStopConfirmation = true
    }
}
