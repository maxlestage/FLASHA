import Observation
import SwiftUI

/// Tout ce que l'app enregistre, en un seul bloc chiffré dans le coffre.
nonisolated struct SavedState: Codable, Sendable {
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
    // Réseau (facultatifs : absents des états enregistrés avant le relais).
    var relayURL: String?
    var followerIDs: Set<FlashaID>?
    var followingIDs: Set<FlashaID>?
    var requestedIDs: Set<FlashaID>?
    var requests: [Friend]?
    var outbox: [Outgoing]?
    var seenParcels: [UUID]?
}

extension AppStore {
    /// L'état enregistré sur le téléphone ; à la toute première ouverture, les données
    /// de démonstration, aussitôt chiffrées.
    static func load() -> AppStore {
        let store: AppStore
        if let savedState = Vault.shared.load(SavedState.self, name: SavedState.name) {
            store = AppStore(
                friends: savedState.friends,
                receivedFlashs: savedState.receivedFlashs,
                conversations: savedState.conversations,
                clips: savedState.clips,
                feed: savedState.feed
            )
            store.apply(savedState)
        } else {
            store = preview()
            store.persist()
        }
        store.autosave()
        store.startNetwork()
        return store
    }

    var savedState: SavedState {
        SavedState(
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
            screenshotAlerts: screenshotAlerts,
            relayURL: relayURL,
            followerIDs: followerIDs,
            followingIDs: followingIDs,
            requestedIDs: requestedIDs,
            requests: requests,
            outbox: outbox,
            seenParcels: seenParcels
        )
    }

    private func apply(_ savedState: SavedState) {
        me = savedState.me
        following = savedState.following
        sentFlashs = savedState.sentFlashs
        publishedStories = savedState.publishedStories
        whoCanSendFlashs = savedState.whoCanSendFlashs
        whoCanMessage = savedState.whoCanMessage
        whoCanSeeStories = savedState.whoCanSeeStories
        whoCanCall = savedState.whoCanCall
        showsOnlineStatus = savedState.showsOnlineStatus
        sharesLocation = savedState.sharesLocation
        screenshotAlerts = savedState.screenshotAlerts
        relayURL = savedState.relayURL ?? ""
        followerIDs = savedState.followerIDs ?? []
        followingIDs = savedState.followingIDs ?? []
        requestedIDs = savedState.requestedIDs ?? []
        requests = savedState.requests ?? []
        outbox = savedState.outbox ?? []
        seenParcels = savedState.seenParcels ?? []
    }

    /// Chiffre et enregistre l'état.
    func persist() {
        Vault.shared.save(savedState, as: SavedState.name)
    }

    /// Enregistre l'état après chaque changement, quel qu'il soit (un abonnement, un
    /// message, un réglage…).
    func autosave() {
        withObservationTracking {
            _ = savedState
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
        followerIDs = []
        followingIDs = []
        requestedIDs = []
        requests = []
        outbox = []
        sentFlashs = 0
        publishedStories = 0
        refreshStorage()
    }
}
