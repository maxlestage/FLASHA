import Observation
import SwiftUI

/// Tout ce que l'app enregistre, en un seul bloc chiffré dans le coffre.
nonisolated struct Snapshot: Codable, Sendable {
    static let name = "state.v1"

    var me: Friend
    var friends: [Friend]
    var receivedFlashs: [Flash]
    var conversations: [Conversation]
    var clips: [Clip]
    var feed: [FeedPost]
    var following: Set<String>
    var sentFlashs: Int
    var publishedStories: Int
    var whoCanSendFlashs: Audience
    var whoCanMessage: Audience
    var whoCanSeeStories: Audience
    var whoCanCall: Audience
    var showsOnlineStatus: Bool
    var sharesLocation: Bool
    var screenshotAlerts: Bool
}

extension AppStore {
    /// L'état enregistré sur le téléphone ; à la toute première ouverture, les données
    /// de démonstration, aussitôt chiffrées.
    static func load() -> AppStore {
        let store: AppStore
        if let snapshot = Vault.shared.load(Snapshot.self, name: Snapshot.name) {
            store = AppStore(
                friends: snapshot.friends,
                receivedFlashs: snapshot.receivedFlashs,
                conversations: snapshot.conversations,
                clips: snapshot.clips,
                feed: snapshot.feed
            )
            store.apply(snapshot)
        } else {
            store = preview()
            store.persist()
        }
        store.autosave()
        return store
    }

    var snapshot: Snapshot {
        Snapshot(
            me: me,
            friends: friends,
            receivedFlashs: receivedFlashs,
            conversations: conversations,
            clips: clips,
            feed: feed,
            following: following,
            sentFlashs: sentFlashs,
            publishedStories: publishedStories,
            whoCanSendFlashs: whoCanSendFlashs,
            whoCanMessage: whoCanMessage,
            whoCanSeeStories: whoCanSeeStories,
            whoCanCall: whoCanCall,
            showsOnlineStatus: showsOnlineStatus,
            sharesLocation: sharesLocation,
            screenshotAlerts: screenshotAlerts
        )
    }

    private func apply(_ snapshot: Snapshot) {
        me = snapshot.me
        following = snapshot.following
        sentFlashs = snapshot.sentFlashs
        publishedStories = snapshot.publishedStories
        whoCanSendFlashs = snapshot.whoCanSendFlashs
        whoCanMessage = snapshot.whoCanMessage
        whoCanSeeStories = snapshot.whoCanSeeStories
        whoCanCall = snapshot.whoCanCall
        showsOnlineStatus = snapshot.showsOnlineStatus
        sharesLocation = snapshot.sharesLocation
        screenshotAlerts = snapshot.screenshotAlerts
    }

    /// Chiffre et enregistre l'état.
    func persist() {
        Vault.shared.save(snapshot, as: Snapshot.name)
    }

    /// Enregistre l'état après chaque changement, quel qu'il soit (un abonnement, un
    /// message, un réglage…).
    func autosave() {
        withObservationTracking {
            _ = snapshot
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.persist()
                self.autosave()
            }
        }
    }

    /// Efface toutes les données du téléphone : le coffre et les médias.
    func eraseEverything() {
        Vault.shared.eraseAll()
        MediaStore.shared.removeAll()
        friends = []
        receivedFlashs = []
        conversations = []
        clips = []
        feed = []
        following = []
        sentFlashs = 0
        publishedStories = 0
        refreshStorage()
    }
}
