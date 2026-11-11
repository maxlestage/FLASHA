import SwiftUI

/// FLASHA — Capture. Share. Connect.
@main
struct FlashaApp: App {
    @State private var store = AppStore.load()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.pink)
        }
    }
}
