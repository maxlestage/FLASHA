import SwiftUI

/// Ce que montre l'onglet Amis.
enum HomeSection: String, CaseIterable, Identifiable {
    case feed = "Fil"
    case flashs = "Flashs"
    case friends = "Amis"

    var id: String { rawValue }
}

/// L'onglet Amis : le Fil des publications, les Flashs reçus, et les amis.
struct FriendsView: View {
    @Environment(AppStore.self) private var store
    @State private var section: HomeSection = .feed
    @State private var openedFlash: Flash?
    @State private var addingFriend = false

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .feed: FeedView()
                case .flashs: flashsList
                case .friends: friendsList
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Section", selection: $section.animation(.spring)) {
                    ForEach(HomeSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if section == .friends {
                    Button("Ajouter un ami", systemImage: "person.badge.plus") { addingFriend = true }
                }
            }
            .sheet(isPresented: $addingFriend) {
                AddFriendView()
                    .environment(store)
                    .presentationDetents([.medium])
            }
            .fullScreenCover(item: $openedFlash) { flash in
                FlashViewer(flash: flash)
                    .environment(store)
            }
        }
    }

    private var flashsList: some View {
        List {
            if store.receivedFlashs.isEmpty {
                ContentUnavailableView("Aucun Flash", systemImage: "bolt.slash", description: Text("Les Flashs de vos amis arrivent ici."))
            }
            ForEach(store.receivedFlashs) { flash in
                Button {
                    if flash.canOpen { openedFlash = flash }
                } label: {
                    FlashRow(flash: flash)
                }
                .foregroundStyle(.primary)
                .disabled(!flash.canOpen)
            }
        }
    }

    private var friendsList: some View {
        List(store.friends) { friend in
            HStack(spacing: 12) {
                AvatarView(friend: friend, size: 40)
                VStack(alignment: .leading) {
                    Text(friend.name).font(.headline)
                    Text("@\(friend.username)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.spring) { store.toggleBestFriend(friend) }
                } label: {
                    Image(systemName: friend.isBestFriend ? "star.fill" : "star")
                        .foregroundStyle(friend.isBestFriend ? Theme.orange : .secondary)
                        .symbolEffect(.bounce, value: friend.isBestFriend)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(friend.isBestFriend ? "Retirer des meilleurs amis" : "Ajouter aux meilleurs amis")
            }
        }
    }
}

private struct FlashRow: View {
    let flash: Flash

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .fill(flash.opened ? AnyShapeStyle(Color.secondary.opacity(0.3)) : AnyShapeStyle(Theme.gradient))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(flash.from.name).font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(flash.sentAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var status: String {
        if !flash.opened { return "Nouveau Flash · \(flash.duration.label) · touchez pour voir" }
        if flash.canOpen { return "Ouvert · une relecture autorisée" }
        return flash.replayed ? "Relu" : "Ouvert"
    }
}

/// Ajouter un ami : pseudo, QR code ou lien d'invitation.
private struct AddFriendView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Par nom d'utilisateur") {
                    TextField("pseudo", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Ajouter") {
                        store.addFriend(username: username)
                        dismiss()
                    }
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section("Autres moyens") {
                    ShareLink(item: URL(string: "https://flasha.app/add/\(store.me.username)")!) {
                        Label("Partager mon lien d'invitation", systemImage: "link")
                    }
                    Label("Mon QR code personnel", systemImage: "qrcode")
                }
            }
            .navigationTitle("Ajouter un ami")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
