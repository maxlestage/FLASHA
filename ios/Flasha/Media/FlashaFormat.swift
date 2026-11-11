import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// Les formats FLASHA : une seule taille et un seul réglage pour tout le monde.
///
/// Les fichiers restent des formats standards (HEIC pour les photos, MP4 HEVC pour les
/// vidéos) : la puce de l'iPhone les encode et les décode elle-même, sans user la
/// batterie, et ils se lisent partout (Android, navigateurs, serveur). Ce qui fait le
/// format FLASHA, ce sont les réglages fixes ci-dessous, choisis pour l'écran d'un
/// téléphone : aussi légers que possible sans perte visible.
nonisolated enum FlashaFormat {
    /// FLASHA Photo : 1080 × 1440 (3:4, le format du capteur : une photo prise avec
    /// l'appareil n'est pas recadrée), HEIC, sans métadonnées (ni position GPS, ni
    /// modèle d'appareil). Environ 150 à 300 Ko, contre 2 à 4 Mo pour l'original.
    nonisolated enum Photo {
        static let size = CGSize(width: 1080, height: 1440)
        static let quality: CGFloat = 0.6
        /// La miniature des grilles et des listes : environ 10 Ko.
        static let thumbnailSize = CGSize(width: 270, height: 360)
        static let thumbnailQuality: CGFloat = 0.5
        static let fileExtension = "heic"
    }

    /// FLASHA Vidéo : 1080 × 1920 (9:16, plein écran vertical), HEVC à 2,5 Mbit/s,
    /// 30 images par seconde, son AAC stéréo à 96 kbit/s, 60 secondes au plus, lecture
    /// immédiate en streaming. Environ 19 Mo par minute, contre 170 Mo en 4K.
    nonisolated enum Video {
        static let size = CGSize(width: 1080, height: 1920)
        static let frameRate: Int32 = 30
        static let bitRate = 2_500_000
        /// Une image clé toutes les 2 secondes : on peut avancer dans la vidéo sans attendre.
        static let keyFrameInterval = 60
        static let audioBitRate = 96_000
        static let audioSampleRate = 44_100.0
        static let maxDuration = 60.0
        static let fileExtension = "mp4"
    }

    /// `UIImage.Orientation` → l'orientation d'ImageIO et de Core Image.
    static func orientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

nonisolated enum FlashaMediaError: Error {
    case unreadable
    case encoder
}

/// Une photo au format FLASHA, et sa miniature.
nonisolated struct EncodedPhoto: Sendable {
    let data: Data
    let thumbnail: Data
    let size: CGSize
}

/// Une vidéo au format FLASHA.
nonisolated struct EncodedVideo: Sendable, Identifiable {
    var id: URL { url }
    let url: URL
    let bytes: Int64
    let duration: Double
    let size: CGSize
}

extension Int64 {
    /// « 212 Ko », « 18,4 Mo ».
    nonisolated var fileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
