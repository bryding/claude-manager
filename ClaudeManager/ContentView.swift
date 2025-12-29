import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Claude Manager")
            .frame(minWidth: 800, minHeight: 600)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
