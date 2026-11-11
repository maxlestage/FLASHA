import CoreImage
import UIKit

/// Les filtres de l'éditeur, appliqués avec Core Image.
enum PhotoFilter: String, CaseIterable, Identifiable {
    case natural = "Naturel"
    case cyanotype = "Cyanotype"
    case silver = "Argentique"
    case halo = "Halo"
    case sepia = "Sépia"

    var id: String { rawValue }

    private static let context = CIContext()

    /// Les tirages de l'atelier : des procédés photographiques, pas des filtres à la mode.
    private func filtered(_ input: CIImage) -> CIImage? {
        switch self {
        case .natural:
            return nil
        case .cyanotype:
            // Le bleu de Prusse des tirages au fer : noir et blanc, puis teinté cyan.
            return input
                .applyingFilter("CIPhotoEffectNoir")
                .applyingFilter("CIColorMonochrome", parameters: [
                    kCIInputColorKey: CIColor(red: 0.114, green: 0.247, blue: 0.820),
                    kCIInputIntensityKey: 1.0,
                ])
        case .silver:
            return input.applyingFilter("CIPhotoEffectNoir")
        case .halo:
            return input.applyingFilter("CIPhotoEffectInstant")
        case .sepia:
            return input.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.9])
        }
    }

    func apply(to image: UIImage) -> UIImage {
        guard let input = CIImage(image: image),
              let output = filtered(input),
              let cgImage = Self.context.createCGImage(output, from: input.extent)
        else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension UIImage {
    /// Une image de démonstration, pour le simulateur qui n'a pas de caméra : une mer
    /// cyanotype, un soleil de papier et l'éclat du flash.
    static func flashaPlaceholder(size: CGSize = CGSize(width: 1080, height: 1920)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            UIColor(red: 0.114, green: 0.247, blue: 0.820, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.949, green: 0.925, blue: 0.882, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.5, y: size.height * 0.2, width: size.width * 0.32, height: size.width * 0.32))
            UIColor(red: 0.075, green: 0.173, blue: 0.580, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.62, width: size.width, height: size.height * 0.38))
            UIColor(red: 1.0, green: 0.357, blue: 0.180, alpha: 1).setFill()
            let c = CGPoint(x: size.width * 0.28, y: size.height * 0.3)
            let r = size.width * 0.09
            let spark = UIBezierPath()
            spark.move(to: CGPoint(x: c.x, y: c.y - r))
            spark.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), controlPoint: CGPoint(x: c.x + r * 0.12, y: c.y - r * 0.12))
            spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), controlPoint: CGPoint(x: c.x + r * 0.12, y: c.y + r * 0.12))
            spark.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), controlPoint: CGPoint(x: c.x - r * 0.12, y: c.y + r * 0.12))
            spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), controlPoint: CGPoint(x: c.x - r * 0.12, y: c.y - r * 0.12))
            spark.fill()
        }
    }
}
