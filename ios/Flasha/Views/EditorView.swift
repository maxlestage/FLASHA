import SwiftUI

/// L'éditeur, après une capture : filtres, texte, durée d'affichage, puis l'envoi.
struct EditorView: View {
    let image: UIImage

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var filter: PhotoFilter = .natural
    @State private var filtered: UIImage?
    @State private var caption = ""
    @State private var editingCaption = false
    @State private var duration: SnapDuration = .five
    @State private var allowsReplay = true
    @State private var choosingRecipients = false
    @FocusState private var captionFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: filtered ?? image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .clipped()
                .onTapGesture {
                    editingCaption = true
                    captionFocused = true
                }

            if editingCaption || !caption.isEmpty {
                TextField("Ajouter un texte", text: $caption, axis: .vertical)
                    .focused($captionFocused)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.45))
                    .onSubmit { editingCaption = false }
            }

            VStack {
                HStack {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                    Spacer()
                    Button("Texte", systemImage: "textformat") {
                        editingCaption = true
                        captionFocused = true
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 14) {
                    chips(PhotoFilter.allCases, selected: filter, label: \.rawValue) { choose($0) }
                    chips(SnapDuration.allCases, selected: duration, label: \.label) { duration = $0 }
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
        .sheet(isPresented: $choosingRecipients) {
            RecipientsView(
                image: filtered ?? image,
                caption: caption,
                duration: duration,
                allowsReplay: allowsReplay
            ) {
                choosingRecipients = false
                dismiss()
            }
            .environment(store)
            .presentationDetents([.medium, .large])
        }
    }

    private func choose(_ newFilter: PhotoFilter) {
        filter = newFilter
        filtered = newFilter == .natural ? nil : newFilter.apply(to: image)
    }

    private func chips<Item: Identifiable & Equatable>(
        _ items: [Item],
        selected: Item,
        label: KeyPath<Item, String>,
        action: @escaping (Item) -> Void
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button(item[keyPath: label]) {
                        withAnimation(.spring(duration: 0.25)) { action(item) }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        if item == selected {
                            Capsule().fill(Theme.gradient)
                        } else {
                            Capsule().fill(.white.opacity(0.15))
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// Le choix des destinataires d'un Snap, meilleurs amis en premier.
struct RecipientsView: View {
    let image: UIImage
    let caption: String
    let duration: SnapDuration
    let allowsReplay: Bool
    let onSent: () -> Void

    @Environment(AppStore.self) private var store
    @State private var selection = Set<Friend.ID>()
    @State private var sent = false

    var body: some View {
        NavigationStack {
            List {
                if !store.bestFriends.isEmpty {
                    Section("Meilleurs amis") {
                        ForEach(store.bestFriends) { row($0) }
                    }
                }
                Section("Amis") {
                    ForEach(store.friends.filter { !$0.isBestFriend }) { row($0) }
                }
            }
            .navigationTitle("Envoyer à")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.send(image: image, caption: caption, duration: duration, allowsReplay: allowsReplay, to: selection)
                    withAnimation(.spring) { sent = true }
                    Task {
                        try? await Task.sleep(for: .seconds(0.8))
                        onSent()
                    }
                } label: {
                    Label(
                        sent ? "Envoyé !" : "Envoyer (\(selection.count))",
                        systemImage: sent ? "checkmark.circle.fill" : "paperplane.fill"
                    )
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.flasha)
                .disabled(selection.isEmpty || sent)
                .padding()
                .background(.bar)
            }
        }
    }

    private func row(_ friend: Friend) -> some View {
        Button {
            if selection.contains(friend.id) {
                selection.remove(friend.id)
            } else {
                selection.insert(friend.id)
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(friend: friend, size: 40)
                VStack(alignment: .leading) {
                    Text(friend.name).font(.headline)
                    Text("@\(friend.username)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selection.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selection.contains(friend.id) ? Theme.pink : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .foregroundStyle(.primary)
    }
}
