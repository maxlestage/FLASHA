import SwiftUI

/// Un Snap ouvert : il s'affiche le temps choisi par l'expéditeur, puis disparaît.
struct SnapViewer: View {
    let snap: Snap

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var remaining: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = snap.image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(uiImage: .flashaPlaceholder()).resizable().scaledToFill()
                }
            }
            .ignoresSafeArea()
            .overlay {
                Text(snap.caption)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.4))
            }

            HStack {
                AvatarView(friend: snap.from, size: 36)
                Text(snap.from.name).font(.headline).foregroundStyle(.white)
                Spacer()
                ZStack {
                    Circle().stroke(.white.opacity(0.3), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: remaining)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(snap.duration.label).font(.caption.bold()).foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityAction(named: "Fermer") { dismiss() }
        .task {
            store.markOpened(snap)
            guard let seconds = snap.duration.seconds else { return }
            withAnimation(.linear(duration: seconds)) { remaining = 0 }
            try? await Task.sleep(for: .seconds(seconds))
            dismiss()
        }
    }
}
