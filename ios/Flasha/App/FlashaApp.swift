import SwiftUI

/// FLASHA — Capture. Share. Connect.
@main
struct FlashaApp: App {
    @State private var store = AppStore.load()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.pink)
        }
        .onChange(of: scenePhase) {
            // De retour au premier plan : on se reconnecte et on renvoie ce qui attend.
            if scenePhase == .active {
                store.connectRelay()
                store.flushOutbox()
            }
        }
    }
}
