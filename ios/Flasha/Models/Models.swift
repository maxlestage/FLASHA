import SwiftUI

/// Combien de temps un Flash reste à l'écran.
enum FlashDuration: Int, CaseIterable, Identifiable {
    case one = 1
    case three = 3
    case five = 5
    case ten = 10
    case thirty = 30
    case unlimited = 0

    var id: Int { rawValue }

    var label: String {
        self == .unlimited ? "∞" : "\(rawValue) s"
    }

    /// `nil` : le Flash reste affiché jusqu'à sa fermeture.
    var seconds: Double? {
        self == .unlimited ? nil : Double(rawValue)
    }
}

/// Qui peut voir une publication, ou faire une action.
enum Audience: String, CaseIterable, Identifiable {
    case everyone = "Tout le monde"
    case friends = "Mes amis"
    case bestFriends = "Mes meilleurs amis"
    case custom = "Une liste personnalisée"
    case nobody = "Personne"

    var id: String { rawValue }
}

struct Friend: Identifiable, Hashable {
    let id: UUID
    var name: String
    var username: String
    var color: Color
    var isBestFriend: Bool
    var hasNewStory: Bool

    init(
        name: String,
        username: String,
        color: Color,
        isBestFriend: Bool = false,
        hasNewStory: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.username = username
        self.color = color
        self.isBestFriend = isBestFriend
        self.hasNewStory = hasNewStory
    }

    var initial: String { String(name.prefix(1)) }
}

/// Un Flash : une photo éphémère, avec ses règles d'expiration.
struct Flash: Identifiable {
    let id = UUID()
    var from: Friend
    var image: UIImage?
    var caption: String
    var duration: FlashDuration
    var allowsReplay: Bool
    var sentAt: Date
    var opened = false
    var replayed = false

    /// Le Flash peut-il encore être ouvert ?
    var canOpen: Bool {
        !opened || (allowsReplay && !replayed)
    }
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    var fromMe: Bool
    var text: String
    var date: Date
    var reaction: String?
}

struct Conversation: Identifiable {
    let id = UUID()
    var friend: Friend
    var messages: [Message]
    var isMuted = false

    var lastMessage: Message? { messages.last }
}

/// Un commentaire, sur un Clip ou une publication du Fil.
struct Comment: Identifiable, Equatable {
    let id = UUID()
    var author: String
    var text: String
    var likes = 0
}

/// Un Clip : une vidéo courte et verticale de Découvrir.
struct Clip: Identifiable {
    let id = UUID()
    var creator: String
    var caption: String
    var sound: String
    var colors: [Color]
    var symbol: String
    var likes: Int
    var comments: [Comment]
    var shares: Int
    var liked = false
    var saved = false
}

/// Une photo d'une publication du Fil (dessinée : pas encore de serveur de médias).
struct Slide: Identifiable {
    let id = UUID()
    var colors: [Color]
    var symbol: String
}

/// Une publication du Fil : un carrousel de photos, avec ses réactions.
struct FeedPost: Identifiable {
    let id = UUID()
    var author: Friend
    var place: String?
    var caption: String
    var slides: [Slide]
    var likes: Int
    var comments: [Comment]
    var date: Date
    var liked = false
    var saved = false
}
