import SwiftUI
import UIKit

// Toutes les données sont enregistrées, chiffrées, sur le téléphone (voir `Vault`) :
// les modèles sont `Codable`, et `nonisolated` pour être chiffrés hors du fil principal.

/// Une couleur enregistrable : rouge, vert, bleu et opacité, en sRGB.
nonisolated struct RGBA: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    @MainActor
    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// Combien de temps un Flash reste à l'écran.
nonisolated enum FlashDuration: Int, CaseIterable, Identifiable, Codable, Sendable {
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
nonisolated enum Audience: String, CaseIterable, Identifiable, Codable, Sendable {
    case everyone = "Tout le monde"
    case friends = "Mes amis"
    case bestFriends = "Mes meilleurs amis"
    case custom = "Une liste personnalisée"
    case nobody = "Personne"

    var id: String { rawValue }
}

nonisolated struct Friend: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var username: String
    var rgba: RGBA
    var isBestFriend: Bool
    var hasNewStory: Bool

    @MainActor
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
        self.rgba = RGBA(color)
        self.isBestFriend = isBestFriend
        self.hasNewStory = hasNewStory
    }

    var color: Color { rgba.color }

    var initial: String { String(name.prefix(1)) }
}

/// Un Flash : une photo éphémère, avec ses règles d'expiration. Le média est rangé,
/// chiffré, dans `MediaStore` ; l'image n'est jamais écrite en clair.
nonisolated struct Flash: Identifiable, Codable, Sendable {
    var id = UUID()
    var from: Friend
    var image: UIImage?
    var mediaID: UUID?
    var caption: String
    var duration: FlashDuration
    var allowsReplay: Bool
    var sentAt: Date
    var opened = false
    var replayed = false

    init(
        from: Friend,
        image: UIImage?,
        mediaID: UUID? = nil,
        caption: String,
        duration: FlashDuration,
        allowsReplay: Bool,
        sentAt: Date
    ) {
        self.from = from
        self.image = image
        self.mediaID = mediaID
        self.caption = caption
        self.duration = duration
        self.allowsReplay = allowsReplay
        self.sentAt = sentAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, from, mediaID, caption, duration, allowsReplay, sentAt, opened, replayed
    }

    /// Le Flash peut-il encore être ouvert ?
    var canOpen: Bool {
        !opened || (allowsReplay && !replayed)
    }
}

nonisolated struct Message: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var fromMe: Bool
    var text: String
    var date: Date
    var reaction: String?
}

nonisolated struct Conversation: Identifiable, Codable, Sendable {
    var id = UUID()
    var friend: Friend
    var messages: [Message]
    var isMuted = false

    var lastMessage: Message? { messages.last }
}

/// Un commentaire, sur un Clip ou une publication du Fil.
nonisolated struct Comment: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var author: String
    var text: String
    var likes = 0
}

/// Un Clip : une vidéo courte et verticale de Découvrir.
nonisolated struct Clip: Identifiable, Codable, Sendable {
    var id = UUID()
    var creator: String
    var caption: String
    var sound: String
    var palette: [RGBA]
    var symbol: String
    var likes: Int
    var comments: [Comment]
    var shares: Int
    var liked = false
    var saved = false

    @MainActor
    init(
        creator: String,
        caption: String,
        sound: String,
        colors: [Color],
        symbol: String,
        likes: Int,
        comments: [Comment],
        shares: Int
    ) {
        self.creator = creator
        self.caption = caption
        self.sound = sound
        self.palette = colors.map { RGBA($0) }
        self.symbol = symbol
        self.likes = likes
        self.comments = comments
        self.shares = shares
    }

    var colors: [Color] { palette.map(\.color) }
}

/// Une photo d'une publication du Fil (dessinée tant qu'il n'y a pas de média).
nonisolated struct Slide: Identifiable, Codable, Sendable {
    var id = UUID()
    var palette: [RGBA]
    var symbol: String
    var mediaID: UUID?

    @MainActor
    init(colors: [Color], symbol: String, mediaID: UUID? = nil) {
        self.palette = colors.map { RGBA($0) }
        self.symbol = symbol
        self.mediaID = mediaID
    }

    var colors: [Color] { palette.map(\.color) }
}

/// Une publication du Fil : un carrousel de photos, avec ses réactions.
nonisolated struct FeedPost: Identifiable, Codable, Sendable {
    var id = UUID()
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
