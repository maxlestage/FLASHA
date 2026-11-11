import AVKit
import SwiftUI

/// Une vidéo filmée, déjà convertie en FLASHA Vidéo : on la revoit en boucle, puis on
/// l'envoie.
struct VideoEditorView: View {
    let video: EncodedVideo

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var choosingRecipients = false
    @State private var allowsReplay = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .disabled(true)
            }

            VStack {
                HStack {
                    Button("Fermer", systemImage: "xmark") {
                        try? FileManager.default.removeItem(at: video.url)
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    Spacer()
                }
                .padding(.horizontal)

                FormatBadge(text: "FLASHA Vidéo · 1080 × 1920 · 30 i/s · \(video.bytes.fileSize) · \(Int(video.duration.rounded())) s")

                Spacer()

                VStack(spacing: 14) {
                    Toggle("Autoriser une relecture", isOn: $allowsReplay)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .tint(Theme.pink)
                    Button {
                        choosingRecipients = true
                    } label: {
                        Label("Envoyer à…", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.flasha)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 12)
            }
        }
        .onAppear {
            let item = AVPlayerItem(url: video.url)
            let queue = AVQueuePlayer()
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
            queue.play()
        }
        .onDisappear { player?.pause() }
        .sheet(isPresented: $choosingRecipients) {
            RecipientsView(
                image: nil,
                photo: nil,
                video: video,
                caption: "",
                duration: .unlimited,
                allowsReplay: allowsReplay
            ) {
                choosingRecipients = false
                dismiss()
            }
            .environment(store)
            .presentationDetents([.medium, .large])
        }
    }
}
