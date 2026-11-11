import CryptoKit
import Foundation
import Security
import SQLite3

/// Le coffre de FLASHA : toutes les données de l'app, chiffrées, dans une base SQLite
/// sur le téléphone. Aucun serveur, aucune base de données externe.
///
/// - Chaque enregistrement est chiffré en AES-256-GCM (chiffré et authentifié : une
///   donnée modifiée hors de l'app est rejetée).
/// - Même les noms des enregistrements sont masqués (HMAC-SHA256) : le fichier ne
///   contient que des empreintes et des blocs chiffrés.
/// - La clé est créée sur le téléphone et rangée dans le trousseau (Keychain), liée à
///   cet appareil : elle ne quitte jamais l'iPhone, ni par iCloud ni par une sauvegarde.
/// - SQLite efface réellement les données supprimées (`secure_delete`), et le fichier
///   profite en plus de la protection des données d'iOS.
nonisolated final class Vault: @unchecked Sendable {
    static let shared = Vault()

    private nonisolated(unsafe) static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let key: SymmetricKey
    private let lock = NSLock()
    private var db: OpaquePointer?

    /// Le dossier des données de l'app (le coffre et les médias chiffrés).
    let directory: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appending(path: "Flasha", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        key = Keychain.vaultKey()
        let path = directory.appending(path: "flasha.vault").path
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            sqlite3_close(db)
            db = nil
        }
        execute("""
            PRAGMA journal_mode = WAL;
            PRAGMA secure_delete = ON;
            CREATE TABLE IF NOT EXISTS vault (tag TEXT PRIMARY KEY NOT NULL, sealed BLOB NOT NULL);
            """)
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: Chiffrement

    /// Chiffre des données avec la clé du coffre (nonce aléatoire + texte chiffré + tag).
    func seal(_ data: Data) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key).combined else {
            throw FlashaMediaError.encoder
        }
        return combined
    }

    /// Déchiffre et vérifie des données chiffrées par `seal`.
    func open(_ data: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
    }

    /// Le nom masqué d'un enregistrement.
    private func tag(_ name: String) -> String {
        HMAC<SHA256>.authenticationCode(for: Data(name.utf8), using: key)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: Enregistrements

    /// Enregistre une valeur, chiffrée, sous un nom.
    func save<T: Encodable>(_ value: T, as name: String) {
        guard let plain = try? JSONEncoder().encode(value), let sealed = try? seal(plain) else { return }
        let tag = tag(name)
        lock.withLock {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO vault (tag, sealed) VALUES (?, ?)", -1, &statement, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, tag, -1, Self.transient)
            _ = sealed.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, 2, bytes.baseAddress, Int32(bytes.count), Self.transient)
            }
            _ = sqlite3_step(statement)
        }
    }

    /// Lit une valeur enregistrée sous un nom ; `nil` si elle n'existe pas ou si elle a
    /// été modifiée.
    func load<T: Decodable>(_ type: T.Type, name: String) -> T? {
        let tag = tag(name)
        let sealed: Data? = lock.withLock {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT sealed FROM vault WHERE tag = ?", -1, &statement, nil) == SQLITE_OK else {
                return nil
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, tag, -1, Self.transient)
            guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else {
                return nil
            }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
        }
        guard let sealed, let plain = try? open(sealed) else { return nil }
        return try? JSONDecoder().decode(T.self, from: plain)
    }

    /// Efface tout : le coffre ne contient plus rien.
    func eraseAll() {
        lock.withLock { execute("DELETE FROM vault; VACUUM;") }
    }

    private func execute(_ sql: String) {
        _ = sqlite3_exec(db, sql, nil, nil, nil)
    }
}

/// La clé du coffre, dans le trousseau d'iOS.
nonisolated enum Keychain {
    private static let account = "app.flasha.vault.key"

    static func vaultKey() -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        // Première ouverture : une clé de 256 bits, tirée au hasard sur le téléphone.
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Liée à cet iPhone : pas de copie dans iCloud ni dans les sauvegardes.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
        SecItemAdd(attributes as CFDictionary, nil)
        return key
    }
}
