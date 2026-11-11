import SwiftUI

/// FLASHA — Capture. Share. Connect.
@main
struct FlashaApp: App {
    @State private var store = AppStore.preview()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.pink)
        }
    }
}
