import Observation
import SwiftUI

/// L'état de l'application. Les données sont locales tant que le serveur n'existe pas
/// (phase 1 de la feuille de route).
@Observable
final class AppStore {
    var me = Friend(name: "Moi", username: "moi", color: Theme.pink)
    var friends: [Friend]
    var receivedSnaps: [Snap]
    var conversations: [Conversation]
    var posts: [Post]
    var sentSnaps = 0
    var publishedStories = 0

    // Confidentialité : tout est restreint par défaut, la localisation coupée.
    var whoCanSendSnaps: Audience = .friends
    var whoCanMessage: Audience = .friends
    var whoCanSeeStories: Audience = .friends
    var whoCanCall: Audience = .bestFriends
    var showsOnlineStatus = true
    var sharesLocation = false
    var screenshotAlerts = true

    init(
        friends: [Friend],
        receivedSnaps: [Snap],
        conversations: [Conversation],
        posts: [Post]
    ) {
        self.friends = friends
        self.receivedSnaps = receivedSnaps
        self.conversations = conversations
        self.posts = posts
    }

    var bestFriends: [Friend] { friends.filter(\.isBestFriend) }

    // MARK: Snaps

    func send(image: UIImage?, caption: String, duration: SnapDuration, allowsReplay: Bool, to recipients: Set<Friend.ID>) {
        sentSnaps += recipients.count
        for id in recipients {
            guard let index = conversations.firstIndex(where: { $0.friend.id == id }) else { continue }
            conversations[index].messages.append(
                Message(fromMe: true, text: "📸 Snap envoyé (\(duration.label))", date: .now)
            )
        }
    }

    func markOpened(_ snap: Snap) {
        guard let index = receivedSnaps.firstIndex(where: { $0.id == snap.id }) else { return }
        if receivedSnaps[index].opened {
            receivedSnaps[index].replayed = true
        } else {
            receivedSnaps[index].opened = true
        }
    }

    // MARK: Talka

    private let replies = [
        "Trop bien ! Envoie-moi un Snap 📸",
        "Je t'appelle en vidéo dans 5 min ?",
        "Ajouté à notre album Talka Moments ✨",
        "Haha 😂 j'adore",
        "On se retrouve ce soir ?",
    ]

    func send(_ text: String, in conversationID: Conversation.ID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID })
        else { return }
        conversations[index].messages.append(Message(fromMe: true, text: trimmed, date: .now))
        let reply = replies[conversations[index].messages.count % replies.count]
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
            withAnimation(.spring) {
                conversations[index].messages.append(Message(fromMe: false, text: reply, date: .now))
            }
        }
    }

    func react(_ emoji: String, to messageID: Message.ID, in conversationID: Conversation.ID) {
        guard let c = conversations.firstIndex(where: { $0.id == conversationID }),
              let m = conversations[c].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        let current = conversations[c].messages[m].reaction
        conversations[c].messages[m].reaction = current == emoji ? nil : emoji
    }

    // MARK: Amis

    func addFriend(username: String) {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !friends.contains(where: { $0.username == name }) else { return }
        let friend = Friend(name: name.capitalized, username: name, color: Theme.violet)
        friends.append(friend)
        conversations.append(Conversation(friend: friend, messages: []))
    }

    func toggleBestFriend(_ friend: Friend) {
        guard let index = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        friends[index].isBestFriend.toggle()
    }

    // MARK: Découvrir

    func toggleLike(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].liked.toggle()
        posts[index].likes += posts[index].liked ? 1 : -1
    }
}

extension AppStore {
    /// Des données de démonstration.
    static func preview() -> AppStore {
        let lea = Friend(name: "Léa", username: "lea", color: Theme.pink, isBestFriend: true, hasNewStory: true)
        let sam = Friend(name: "Sam", username: "sam.photo", color: Theme.orange, isBestFriend: true, hasNewStory: true)
        let ines = Friend(name: "Inès", username: "ines", color: Theme.violet, hasNewStory: true)
        let noah = Friend(name: "Noah", username: "noah", color: .teal)
        let jade = Friend(name: "Jade", username: "jade", color: .indigo, hasNewStory: true)
        let friends = [lea, sam, ines, noah, jade]
        let now = Date.now
        return AppStore(
            friends: friends,
            receivedSnaps: [
                Snap(from: lea, image: nil, caption: "Coucou ✨", duration: .five, allowsReplay: true, sentAt: now.addingTimeInterval(-300)),
                Snap(from: sam, image: nil, caption: "Le coucher de soleil 🌅", duration: .ten, allowsReplay: false, sentAt: now.addingTimeInterval(-3600)),
            ],
            conversations: [
                Conversation(friend: lea, messages: [
                    Message(fromMe: false, text: "Salut ! Tu as vu la story de Sam ? 🌅", date: now.addingTimeInterval(-600)),
                    Message(fromMe: true, text: "Oui, le coucher de soleil était fou", date: now.addingTimeInterval(-540)),
                ]),
                Conversation(friend: sam, messages: [
                    Message(fromMe: false, text: "On fait un album Talka Moments pour le week-end ?", date: now.addingTimeInterval(-7200)),
                ]),
                Conversation(friend: ines, messages: []),
                Conversation(friend: noah, messages: []),
                Conversation(friend: jade, messages: []),
            ],
            posts: [
                Post(creator: "@sam.photo", title: "Golden hour à Biarritz", hashtag: "#goldenhour", colors: [Theme.orange, Theme.pink], symbol: "sun.horizon.fill", likes: 1_204),
                Post(creator: "@lea", title: "Défi : un Snap par heure", hashtag: "#flashachallenge", colors: [Theme.violet, Theme.pink], symbol: "bolt.fill", likes: 892),
                Post(creator: "@studio.flasha", title: "Nouveaux filtres néon", hashtag: "#neon", colors: [.indigo, Theme.violet], symbol: "sparkles", likes: 5_310),
                Post(creator: "@jade", title: "Concert ce soir 🎶", hashtag: "#live", colors: [Theme.pink, .red], symbol: "music.note", likes: 431),
            ]
        )
    }
}
