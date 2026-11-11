import AVKit
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Une photo chiffrée du téléphone, déchiffrée et décodée à la taille d'affichage, hors
/// du fil principal.
struct MediaImage: View {
    let id: UUID
    var maxPixelSize: CGFloat = 1440

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .developing()
            } else {
                Rectangle().fill(Color.secondary.opacity(0.15))
                ProgressView()
            }
        }
        .task(id: id) {
            image = await Self.load(id, maxPixelSize: maxPixelSize)
        }
    }

    @concurrent
    nonisolated private static func load(_ id: UUID, maxPixelSize: CGFloat) async -> UIImage? {
        MediaStore.shared.image(id: id, maxPixelSize: maxPixelSize)
    }
}

/// Une vidéo chiffrée du téléphone : déchiffrée dans un fichier temporaire le temps de
/// la lecture, effacé ensuite.
struct EncryptedVideoPlayer: View {
    let id: UUID

    @State private var player: AVPlayer?
    @State private var file: URL?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: id) {
            guard let url = MediaStore.shared.playableVideo(id: id) else { return }
            file = url
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
            if let file {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

/// Un QR code, net à toutes les tailles.
struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = Self.render(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("QR code de mon identifiant FLASHA")
        }
    }

    static func render(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
