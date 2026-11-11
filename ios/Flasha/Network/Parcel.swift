import Foundation

/// Ce que s'envoient deux téléphones, chiffré de bout en bout par `Sealing`. Encodé en
/// liste de propriétés binaire : les photos et vidéos y restent en octets bruts.
nonisolated struct Parcel: Codable, Sendable {
    var id = UUID()
    var sentAt = Date()
    var body: Body

    nonisolated enum Body: Codable, Sendable {
        /// « Je voudrais te suivre » : mon nom et mon pseudo.
        case followRequest(Profile)
        /// « D'accord, tu me suis » : mes publications t'arriveront.
        case followAccepted(Profile)
        /// « Je ne te suis plus ».
        case unfollow
        /// Une publication du Fil, avec ses photos au format FLASHA Photo.
        case post(PostPayload)
        /// Un Flash, photo ou vidéo, au format FLASHA.
        case flash(FlashPayload)
        /// Un message Talka.
        case chat(String)
        /// « Bien reçu » : l'expéditeur peut retirer le paquet de sa boîte d'envoi.
        case receipt(UUID)
    }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Parcel {
        try PropertyListDecoder().decode(Parcel.self, from: data)
    }
}

nonisolated struct Profile: Codable, Sendable {
    var name: String
    var username: String
}

nonisolated struct PostPayload: Codable, Sendable {
    var postID: UUID
    var caption: String
    var place: String?
    var date: Date
    /// Les photos, au format FLASHA Photo (HEIC 1080 × 1440).
    var photos: [Data]
}

nonisolated struct FlashPayload: Codable, Sendable {
    var caption: String
    var duration: FlashDuration
    var allowsReplay: Bool
    var isVideo: Bool
    /// La photo ou la vidéo, au format FLASHA.
    var media: Data?
}

/// Un paquet dans la boîte d'envoi : déjà chiffré pour son destinataire, gardé (chiffré
/// une seconde fois avec la clé du coffre) jusqu'à son accusé de réception.
nonisolated struct Outgoing: Codable, Sendable, Identifiable {
    var id: UUID
    var to: FlashaID
    var createdAt: Date
    var lastSent: Date?
}
