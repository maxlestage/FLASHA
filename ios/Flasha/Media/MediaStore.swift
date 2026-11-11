import Foundation
import UIKit

/// Les photos et vidéos gardées sur le téléphone, chiffrées en AES-256-GCM avec la clé du
/// coffre (`Vault`) : aucun fichier n'est jamais écrit en clair.
///
/// Une limite de place est fixée (1 Go par défaut, réglable dans le Profil). Quand elle
/// est dépassée, les médias les plus anciens sont effacés en premier. Les médias
/// épinglés (Souvenirs, brouillons, envois en attente) ne sont jamais effacés.
nonisolated final class MediaStore: @unchecked Sendable {
    static let shared = MediaStore()

    nonisolated enum Kind: String, Sendable {
        case photo
        case thumbnail = "thumb"
        case video
    }

    static let quotas: [Int64] = [250_000_000, 500_000_000, 1_000_000_000, 2_000_000_000]

    private let directory: URL
    private let lock = NSLock()
    private let defaults = UserDefaults.standard

    init() {
        var folder = Vault.shared.directory.appending(path: "Media", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Les médias sont lourds et chiffrés avec une clé liée à cet iPhone : une sauvegarde
        // ne pourrait pas les relire ailleurs, inutile de l'alourdir.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
        directory = folder
    }

    /// La place que les médias peuvent prendre, en octets.
    var quota: Int64 {
        get {
            let stored = defaults.object(forKey: "mediaQuota") as? NSNumber
            return stored?.int64Value ?? 1_000_000_000
        }
        set { defaults.set(NSNumber(value: newValue), forKey: "mediaQuota") }
    }

    func url(for id: UUID, kind: Kind) -> URL {
        directory.appending(path: "\(id.uuidString).\(kind.rawValue).flasha")
    }

    /// Un fichier temporaire, pour une vidéo en cours de conversion.
    func temporaryURL(kind: Kind) -> URL {
        let ext = kind == .video ? FlashaFormat.Video.fileExtension : FlashaFormat.Photo.fileExtension
        return FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).\(ext)")
    }

    private func write(_ data: Data, id: UUID, kind: Kind) throws {
        try Vault.shared.seal(data).write(to: url(for: id, kind: kind), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Le média déchiffré, ou `nil` s'il a été effacé ou modifié.
    func data(id: UUID, kind: Kind) -> Data? {
        guard let sealed = try? Data(contentsOf: url(for: id, kind: kind)) else { return nil }
        return try? Vault.shared.open(sealed)
    }

    /// Une photo, décodée seulement à la taille d'affichage.
    func image(id: UUID, kind: Kind = .photo, maxPixelSize: CGFloat) -> UIImage? {
        data(id: id, kind: kind).flatMap { ImageLoader.image(data: $0, maxPixelSize: maxPixelSize) }
    }

    /// Une vidéo, déchiffrée dans un fichier temporaire pour la lecture (à effacer après).
    func playableVideo(id: UUID) -> URL? {
        guard let plain = data(id: id, kind: .video) else { return nil }
        let target = temporaryURL(kind: .video)
        return (try? plain.write(to: target, options: [.atomic, .completeFileProtection])) == nil ? nil : target
    }

    /// Enregistre une photo et sa miniature.
    @discardableResult
    func save(_ photo: EncodedPhoto, id: UUID = UUID(), pinned: Bool = false) throws -> UUID {
        try write(photo.data, id: id, kind: .photo)
        try write(photo.thumbnail, id: id, kind: .thumbnail)
        if pinned { pin(id) }
        trim()
        return id
    }

    /// Range une vidéo déjà convertie dans le cache.
    @discardableResult
    func save(_ video: EncodedVideo, id: UUID = UUID(), pinned: Bool = false) throws -> UUID {
        let plain = try Data(contentsOf: video.url)
        try write(plain, id: id, kind: .video)
        try? FileManager.default.removeItem(at: video.url)
        if pinned { pin(id) }
        trim()
        return id
    }

    // MARK: Épingles

    private var pinned: Set<String> {
        get { Set(defaults.stringArray(forKey: "pinnedMedia") ?? []) }
        set { defaults.set(Array(newValue), forKey: "pinnedMedia") }
    }

    func pin(_ id: UUID) {
        _ = lock.withLock { pinned.insert(id.uuidString) }
    }

    func unpin(_ id: UUID) {
        _ = lock.withLock { pinned.remove(id.uuidString) }
        trim()
    }

    // MARK: Place

    private nonisolated struct Entry {
        let url: URL
        let created: Date
        let bytes: Int64
    }

    private func entries() -> [Entry] {
        let keys: [URLResourceKey] = [.creationDateKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let bytes = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            return Entry(url: url, created: values.creationDate ?? .distantPast, bytes: bytes)
        }
    }

    /// La place prise par les médias, en octets.
    var usedBytes: Int64 {
        lock.withLock { entries().reduce(0) { $0 + $1.bytes } }
    }

    /// Efface les médias les plus anciens jusqu'à repasser sous la limite. Renvoie le
    /// nombre de fichiers effacés.
    @discardableResult
    func trim() -> Int {
        lock.withLock {
            let limit = quota
            let keep = pinned
            let all = entries()
            var used = all.reduce(0) { $0 + $1.bytes }
            var removed = 0
            for entry in all.sorted(by: { $0.created < $1.created }) where used > limit {
                let id = entry.url.lastPathComponent.components(separatedBy: ".").first ?? ""
                guard !keep.contains(id) else { continue }
                if (try? FileManager.default.removeItem(at: entry.url)) != nil {
                    used -= entry.bytes
                    removed += 1
                }
            }
            return removed
        }
    }

    /// Efface tous les médias, épinglés compris.
    func removeAll() {
        lock.withLock {
            for entry in entries() {
                try? FileManager.default.removeItem(at: entry.url)
            }
            pinned = []
        }
    }

    /// Efface tout ce qui n'est pas épinglé.
    func removeUnpinned() {
        lock.withLock {
            let keep = pinned
            for entry in entries() {
                let id = entry.url.lastPathComponent.components(separatedBy: ".").first ?? ""
                if !keep.contains(id) {
                    try? FileManager.default.removeItem(at: entry.url)
                }
            }
        }
    }
}
