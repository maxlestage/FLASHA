import SwiftUI

/// Un Flash ouvert : il s'affiche le temps choisi par l'expéditeur, puis disparaît.
struct FlashViewer: View {
    let flash: Flash

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var remaining: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let mediaID = flash.mediaID {
                    if flash.isVideo == true {
                        EncryptedVideoPlayer(id: mediaID)
                    } else {
                        MediaImage(id: mediaID)
                    }
                } else if let image = flash.image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(uiImage: .flashaPlaceholder()).resizable().scaledToFill()
                }
            }
            .ignoresSafeArea()
            .overlay {
                Text(flash.caption)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.4))
            }

            HStack {
                AvatarView(friend: flash.from, size: 36)
                Text(flash.from.name).font(.headline).foregroundStyle(.white)
                Spacer()
                ZStack {
                    Circle().stroke(.white.opacity(0.3), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: remaining)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(flash.duration.label).font(.caption.bold()).foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityAction(named: "Fermer") { dismiss() }
        .task {
            store.markOpened(flash)
            guard let seconds = flash.duration.seconds else { return }
            withAnimation(.linear(duration: seconds)) { remaining = 0 }
            try? await Task.sleep(for: .seconds(seconds))
            dismiss()
        }
    }
}
