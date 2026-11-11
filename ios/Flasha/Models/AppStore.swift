import Observation
import SwiftUI

/// L'état de l'application. Tout reste sur le téléphone, chiffré dans le coffre
/// (`Vault`) et enregistré après chaque changement (`Persistence.swift`).
@Observable
final class AppStore {
    var me = Friend(name: "Moi", username: "moi", color: Theme.pink)
    var friends: [Friend]
    var receivedFlashs: [Flash]
    var conversations: [Conversation]
    var clips: [Clip]
    var feed: [FeedPost]
    /// Les créateurs suivis (abonnements publics, distincts des amis).
    var following: Set<String> = ["@sam.photo", "@lea"]
    var sentFlashs = 0
    var publishedStories = 0

    // Confidentialité : tout est restreint par défaut, la localisation coupée.
    var whoCanSendFlashs: Audience = .friends
    var whoCanMessage: Audience = .friends
    var whoCanSeeStories: Audience = .friends
    var whoCanCall: Audience = .bestFriends
    var showsOnlineStatus = true
    var sharesLocation = false
    var screenshotAlerts = true

    init(
        friends: [Friend],
        receivedFlashs: [Flash],
        conversations: [Conversation],
        clips: [Clip],
        feed: [FeedPost]
    ) {
        self.friends = friends
        self.receivedFlashs = receivedFlashs
        self.conversations = conversations
        self.clips = clips
        self.feed = feed
    }

    var bestFriends: [Friend] { friends.filter(\.isBestFriend) }

    // MARK: Flashs

    func send(
        photo: EncodedPhoto?,
        video: EncodedVideo?,
        caption: String,
        duration: FlashDuration,
        allowsReplay: Bool,
        to recipients: Set<Friend.ID>
    ) {
        // Le média, déjà au format FLASHA, est gardé dans le cache et épinglé tant que
        // l'envoi n'est pas confirmé par le serveur.
        if let photo {
            _ = try? MediaStore.shared.save(photo, pinned: true)
        } else if let video {
            _ = try? MediaStore.shared.save(video, pinned: true)
        }
        refreshStorage()
        sentFlashs += recipients.count
        for id in recipients {
            guard let index = conversations.firstIndex(where: { $0.friend.id == id }) else { continue }
            conversations[index].messages.append(
                Message(fromMe: true, text: "📸 Flash envoyé (\(duration.label))", date: .now)
            )
        }
    }

    // MARK: Stockage

    /// La place prise par les photos et vidéos sur le téléphone.
    var mediaBytes: Int64 = MediaStore.shared.usedBytes

    /// La limite : au-delà, les médias les plus anciens sont effacés en premier.
    var mediaQuota: Int64 = MediaStore.shared.quota

    func setMediaQuota(_ quota: Int64) {
        mediaQuota = quota
        MediaStore.shared.quota = quota
        trimMedia()
    }

    func trimMedia() {
        MediaStore.shared.trim()
        refreshStorage()
    }

    func clearMediaCache() {
        MediaStore.shared.removeUnpinned()
        refreshStorage()
    }

    func refreshStorage() {
        mediaBytes = MediaStore.shared.usedBytes
    }

    func markOpened(_ flash: Flash) {
        guard let index = receivedFlashs.firstIndex(where: { $0.id == flash.id }) else { return }
        if receivedFlashs[index].opened {
            receivedFlashs[index].replayed = true
        } else {
            receivedFlashs[index].opened = true
        }
    }

    // MARK: Talka

    private let replies = [
        "Trop bien ! Envoie-moi un Flash 📸",
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

    // MARK: Clips

    func isFollowing(_ creator: String) -> Bool { following.contains(creator) }

    func toggleFollow(_ creator: String) {
        if following.contains(creator) {
            following.remove(creator)
        } else {
            following.insert(creator)
        }
    }

    func toggleLike(clip id: Clip.ID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].liked.toggle()
        clips[index].likes += clips[index].liked ? 1 : -1
    }

    func toggleSave(clip id: Clip.ID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].saved.toggle()
    }

    func comment(_ text: String, onClip id: Clip.ID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].comments.append(Comment(author: me.username, text: trimmed))
    }

    // MARK: Fil

    func toggleLike(post id: FeedPost.ID) {
        guard let index = feed.firstIndex(where: { $0.id == id }) else { return }
        feed[index].liked.toggle()
        feed[index].likes += feed[index].liked ? 1 : -1
    }

    /// Le double toucher : il aime, il n'enlève jamais le « J'aime ».
    func like(post id: FeedPost.ID) {
        guard let index = feed.firstIndex(where: { $0.id == id }), !feed[index].liked else { return }
        feed[index].liked = true
        feed[index].likes += 1
    }

    func toggleSave(post id: FeedPost.ID) {
        guard let index = feed.firstIndex(where: { $0.id == id }) else { return }
        feed[index].saved.toggle()
    }

    func comment(_ text: String, onPost id: FeedPost.ID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = feed.firstIndex(where: { $0.id == id }) else { return }
        feed[index].comments.append(Comment(author: me.username, text: trimmed))
    }

    func publish(caption: String, slides: [Slide]) {
        feed.insert(
            FeedPost(author: me, place: nil, caption: caption, slides: slides, likes: 0, comments: [], date: .now),
            at: 0
        )
    }

    /// Mes publications, pour la grille du profil.
    var myPosts: [FeedPost] { feed.filter { $0.author.id == me.id } }
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
            receivedFlashs: [
                Flash(from: lea, image: nil, caption: "Coucou ✨", duration: .five, allowsReplay: true, sentAt: now.addingTimeInterval(-300)),
                Flash(from: sam, image: nil, caption: "Le coucher de soleil 🌅", duration: .ten, allowsReplay: false, sentAt: now.addingTimeInterval(-3600)),
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
            clips: [
                Clip(creator: "@sam.photo", caption: "Golden hour sur la plage 🌅 #goldenhour", sound: "Son original — sam.photo", colors: [Theme.orange, Theme.pink], symbol: "sun.horizon.fill", likes: 12_400, comments: [Comment(author: "lea", text: "Cette lumière 😍", likes: 42)], shares: 310),
                Clip(creator: "@lea", caption: "Défi : un Flash par heure ⚡ #flashachallenge", sound: "Neon Nights — Studio FLASHA", colors: [Theme.violet, Theme.pink], symbol: "bolt.fill", likes: 8_920, comments: [Comment(author: "sam.photo", text: "Je relève le défi !", likes: 12)], shares: 204),
                Clip(creator: "@ines.danse", caption: "Remix de la chorégraphie de Jade 💃 #remix", sound: "Pulse — Les Ondes", colors: [Theme.pink, .indigo], symbol: "figure.dance", likes: 30_100, comments: [Comment(author: "jade", text: "Trop fort le remix 🔥", likes: 230)], shares: 1_204),
                Clip(creator: "@noah.cuisine", caption: "Des crêpes en 30 secondes 🥞 #recette", sound: "Son original — noah.cuisine", colors: [.orange, .yellow], symbol: "frying.pan.fill", likes: 5_310, comments: [], shares: 96),
            ],
            feed: [
                FeedPost(
                    author: sam,
                    place: "Refuge des Lacs, Pyrénées",
                    caption: "Trois jours là-haut, sans réseau, et un ciel comme ça 🏔️ #rando",
                    slides: [
                        Slide(colors: [Theme.pink, Theme.orange], symbol: "mountain.2.fill"),
                        Slide(colors: [Theme.violet, Theme.pink], symbol: "water.waves"),
                        Slide(colors: [.indigo, .black], symbol: "moon.stars.fill"),
                    ],
                    likes: 2_841,
                    comments: [
                        Comment(author: "lea", text: "Magnifique 😍"),
                        Comment(author: "ines.danse", text: "On y va cet été ?"),
                    ],
                    date: now.addingTimeInterval(-5400)
                ),
                FeedPost(
                    author: lea,
                    place: nil,
                    caption: "Nouveau filtre néon testé ce soir ✨",
                    slides: [Slide(colors: [Theme.violet, .indigo], symbol: "sparkles")],
                    likes: 512,
                    comments: [],
                    date: now.addingTimeInterval(-86_400)
                ),
            ]
        )
    }
}
