import CryptoKit
import Foundation

/// L'identifiant public d'un utilisateur de FLASHA : sa clé de signature (Ed25519, qui
/// sert aussi d'adresse sur le relais) et sa clé de chiffrement (X25519). Il n'y a pas
/// d'annuaire : on se l'échange par QR code ou par lien, et personne ne peut l'usurper.
nonisolated struct FlashaID: Hashable, Codable, Sendable {
    static let prefix = "flasha:"

    let signing: Data
    let agreement: Data

    init(signing: Data, agreement: Data) {
        self.signing = signing
        self.agreement = agreement
    }

    /// Lit un identifiant `flasha:…` (copié, collé ou scanné).
    init?(_ text: String) {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix(Self.prefix) {
            value.removeFirst(Self.prefix.count)
        }
        value = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while value.count % 4 != 0 {
            value.append("=")
        }
        guard let raw = Data(base64Encoded: value), raw.count == 64 else { return nil }
        let signing = Data(raw.prefix(32))
        let agreement = Data(raw.suffix(32))
        guard (try? Curve25519.Signing.PublicKey(rawRepresentation: signing)) != nil,
              (try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: agreement)) != nil
        else { return nil }
        self.signing = signing
        self.agreement = agreement
    }

    /// `flasha:` suivi des deux clés, en base64 pour les URL.
    var string: String {
        Self.prefix + (signing + agreement).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Un court résumé lisible, pour vérifier un identifiant à voix haute.
    var fingerprint: String {
        SHA256.hash(data: signing + agreement)
            .prefix(6)
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")
    }
}

/// Mes clés, créées sur ce téléphone à la première ouverture et rangées dans le
/// trousseau. Elles ne le quittent jamais.
nonisolated final class Identity: @unchecked Sendable {
    static let shared = Identity()

    let signing: Curve25519.Signing.PrivateKey
    let agreement: Curve25519.KeyAgreement.PrivateKey

    init() {
        let signingData = Keychain.secret("app.flasha.identity.signing") {
            Curve25519.Signing.PrivateKey().rawRepresentation
        }
        let agreementData = Keychain.secret("app.flasha.identity.agreement") {
            Curve25519.KeyAgreement.PrivateKey().rawRepresentation
        }
        signing = (try? Curve25519.Signing.PrivateKey(rawRepresentation: signingData)) ?? Curve25519.Signing.PrivateKey()
        agreement = (try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementData)) ?? Curve25519.KeyAgreement.PrivateKey()
    }

    var id: FlashaID {
        FlashaID(signing: signing.publicKey.rawRepresentation, agreement: agreement.publicKey.rawRepresentation)
    }

    /// La réponse au défi du relais : `flasha-relay-v1` suivi du défi, signé.
    func signChallenge(_ nonce: Data) throws -> Data {
        try signing.signature(for: Data("flasha-relay-v1".utf8) + nonce)
    }
}
