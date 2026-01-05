import SwiftUI

/// Main content view that displays the appropriate UI based on the current tab's execution phase.
/// This view delegates to `TabContentView` for the actual implementation.
struct ContentView: View {
    @Environment(Tab.self) private var tab

    var body: some View {
        TabContentView()
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
