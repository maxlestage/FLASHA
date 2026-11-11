import CryptoKit
import Foundation

/// Le chiffrement de bout en bout de FLASHA. Seul le destinataire peut ouvrir un
/// paquet, et il sait qui l'a envoyé :
///
/// - une clé X25519 éphémère par paquet, combinée à la clé du destinataire (ECDH), puis
///   dérivée avec HKDF-SHA256 : chaque paquet a sa propre clé (confidentialité persistante
///   côté expéditeur) ;
/// - le contenu est signé par l'expéditeur (Ed25519), puis chiffré et authentifié avec
///   ChaCha20-Poly1305 ;
/// - à l'ouverture, la signature est vérifiée, et l'expéditeur doit être celui que le
///   relais a authentifié.
///
/// Format : clé éphémère (32 octets) | boîte ChaCha20-Poly1305 de
/// [identifiant de l'expéditeur (64) | signature (64) | contenu].
nonisolated enum Sealing {
    private static let info = Data("flasha-e2e-v1".utf8)

    enum Failure: Error {
        case malformed
        case forged
    }

    static func seal(_ content: Data, to recipient: FlashaID, from identity: Identity) throws -> Data {
        let recipientKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipient.agreement)
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let key = try derive(
            ephemeral.sharedSecretFromKeyAgreement(with: recipientKey),
            ephemeral: ephemeral.publicKey.rawRepresentation,
            recipient: recipient.agreement
        )
        let me = identity.id
        let signature = try identity.signing.signature(for: content)
        let inner = me.signing + me.agreement + signature + content
        let box = try ChaChaPoly.seal(inner, using: key).combined
        return ephemeral.publicKey.rawRepresentation + box
    }

    /// Ouvre un paquet ; `relaySender` est l'adresse garantie par le relais.
    static func open(_ payload: Data, relaySender: Data, identity: Identity) throws -> (FlashaID, Data) {
        guard payload.count > 32 + 128 else { throw Failure.malformed }
        let ephemeralRaw = Data(payload.prefix(32))
        let ephemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralRaw)
        let key = try derive(
            identity.agreement.sharedSecretFromKeyAgreement(with: ephemeral),
            ephemeral: ephemeralRaw,
            recipient: identity.agreement.publicKey.rawRepresentation
        )
        let inner = try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: Data(payload.dropFirst(32))), using: key)
        guard inner.count >= 128 else { throw Failure.malformed }
        let sender = FlashaID(signing: Data(inner.prefix(32)), agreement: Data(inner.dropFirst(32).prefix(32)))
        let signature = Data(inner.dropFirst(64).prefix(64))
        let content = Data(inner.dropFirst(128))
        let signingKey = try Curve25519.Signing.PublicKey(rawRepresentation: sender.signing)
        guard sender.signing == relaySender, signingKey.isValidSignature(signature, for: content) else {
            throw Failure.forged
        }
        return (sender, content)
    }

    private static func derive(_ secret: SharedSecret, ephemeral: Data, recipient: Data) -> SymmetricKey {
        secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: ephemeral + recipient,
            sharedInfo: info,
            outputByteCount: 32
        )
    }
}
