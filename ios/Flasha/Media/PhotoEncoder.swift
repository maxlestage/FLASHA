import CoreImage
import ImageIO
import UIKit

/// Convertit une photo au format FLASHA Photo : recadrée au centre pour remplir
/// 1080 × 1440, réduite avec un filtre Lanczos (net, sans crénelage), encodée en HEIC
/// sans aucune métadonnée. Le travail se fait hors du fil principal.
nonisolated enum PhotoEncoder {
    private nonisolated(unsafe) static let context = CIContext(options: [.cacheIntermediates: false])

    @concurrent static func encode(_ image: UIImage) async throws -> EncodedPhoto {
        guard let cgImage = image.cgImage else { throw FlashaMediaError.unreadable }
        let source = CIImage(cgImage: cgImage)
            .oriented(FlashaFormat.orientation(image.imageOrientation))
        let full = try heic(fill(source, to: FlashaFormat.Photo.size), quality: FlashaFormat.Photo.quality)
        let thumbnail = try heic(
            fill(source, to: FlashaFormat.Photo.thumbnailSize),
            quality: FlashaFormat.Photo.thumbnailQuality
        )
        return EncodedPhoto(data: full, thumbnail: thumbnail, size: FlashaFormat.Photo.size)
    }

    /// Remplit exactement `size` : mise à l'échelle, puis recadrage au centre.
    static func fill(_ image: CIImage, to size: CGSize) -> CIImage {
        let extent = image.extent
        let scale = max(size.width / extent.width, size.height / extent.height)
        let scaled = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .applyingFilter(
                "CILanczosScaleTransform",
                parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1.0]
            )
        let x = scaled.extent.minX + ((scaled.extent.width - size.width) / 2).rounded(.down)
        let y = scaled.extent.minY + ((scaled.extent.height - size.height) / 2).rounded(.down)
        return scaled
            .cropped(to: CGRect(x: x, y: y, width: size.width, height: size.height))
            .transformed(by: CGAffineTransform(translationX: -x, y: -y))
    }

    /// HEIC en sRGB 8 bits ; JPEG si l'appareil ne sait pas écrire de HEIC.
    private static func heic(_ image: CIImage, quality: CGFloat) throws -> Data {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw FlashaMediaError.encoder }
        let key = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        let options: [CIImageRepresentationOption: Any] = [key: quality]
        if let data = context.heifRepresentation(of: image, format: .RGBA8, colorSpace: space, options: options) {
            return data
        }
        if let data = context.jpegRepresentation(of: image, colorSpace: space, options: options) {
            return data
        }
        throw FlashaMediaError.encoder
    }
}

/// Affiche une photo sans la décoder en entier : seulement à la taille de l'écran,
/// ce qui divise la mémoire vive utilisée.
nonisolated enum ImageLoader {
    static func image(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
