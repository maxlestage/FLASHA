import CoreImage
import UIKit

/// Les filtres de l'éditeur, appliqués avec Core Image.
enum PhotoFilter: String, CaseIterable, Identifiable {
    case natural = "Naturel"
    case neon = "Néon"
    case vintage = "Vintage"
    case dawn = "Aube"
    case noir = "Noir"

    var id: String { rawValue }

    private var filterName: String? {
        switch self {
        case .natural: nil
        case .neon: "CIPhotoEffectChrome"
        case .vintage: "CIPhotoEffectTransfer"
        case .dawn: "CIPhotoEffectInstant"
        case .noir: "CIPhotoEffectNoir"
        }
    }

    private static let context = CIContext()

    func apply(to image: UIImage) -> UIImage {
        guard let name = filterName,
              let input = CIImage(image: image),
              let filter = CIFilter(name: name)
        else { return image }
        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let cgImage = Self.context.createCGImage(output, from: output.extent)
        else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension UIImage {
    /// Une image de démonstration, pour le simulateur qui n'a pas de caméra.
    static func flashaPlaceholder(size: CGSize = CGSize(width: 1080, height: 1920)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = [
                UIColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1).cgColor,
                UIColor(red: 0.925, green: 0.282, blue: 0.600, alpha: 1).cgColor,
                UIColor(red: 0.984, green: 0.573, blue: 0.235, alpha: 1).cgColor,
            ]
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.55, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            let sun = CGRect(x: size.width * 0.3, y: size.height * 0.45, width: size.width * 0.4, height: size.width * 0.4)
            UIColor.white.withAlphaComponent(0.85).setFill()
            context.cgContext.fillEllipse(in: sun)
        }
    }
}
