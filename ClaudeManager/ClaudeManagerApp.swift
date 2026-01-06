import SwiftUI

@main
struct ClaudeManagerApp: App {
    @State private var appState: AppState

    init() {
        let config = TestModeConfiguration.shared
        if config.isUITesting, let scenario = config.scenario {
            _appState = State(initialValue: AppState.forUITesting(scenario: scenario))
        } else {
            _appState = State(initialValue: AppState())
        }
    }

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

                Divider()

                Button("Show Next Tab") {
                    appState.tabManager.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(appState.tabManager.tabs.count < 2)

                Button("Show Previous Tab") {
                    appState.tabManager.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(appState.tabManager.tabs.count < 2)
            }

            CommandGroup(after: .appSettings) {
                Section {
                    let context = appState.activeTab?.context
                    let canPauseOrResume = context?.canPause == true || context?.canResume == true

                    Button(context?.canResume == true ? "Resume" : "Pause") {
                        togglePauseResume()
                    }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(!canPauseOrResume)

                    Button("Stop Execution...") {
                        requestStop()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(context?.canStop != true)
                }
            }
        }
    }

    private func createNewTab() {
        appState.tabManager.createTab()
    }

    private func closeCurrentTab() {
        guard let tab = appState.activeTab else { return }
        Task {
            try? await appState.tabManager.closeTab(tab)
        }
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
