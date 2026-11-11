import SwiftUI
import UIKit

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
        List {
            if !store.requests.isEmpty {
                Section("Demandes d'abonnement") {
                    ForEach(store.requests) { request in
                        HStack(spacing: 10) {
                            AvatarView(friend: request, size: 40)
                            VStack(alignment: .leading) {
                                Text(request.name).font(.headline)
                                Text(request.publicID?.fingerprint ?? "")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Refuser") { withAnimation { store.decline(request) } }
                                .buttonStyle(.bordered)
                            Button("Accepter") { withAnimation { store.accept(request) } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            if !store.requestedIDs.isEmpty {
                Section("Demandes envoyées") {
                    ForEach(Array(store.requestedIDs), id: \.self) { id in
                        Label(id.fingerprint, systemImage: "clock")
                            .font(.footnote.monospaced())
                    }
                }
            }
            Section("Amis") {
                ForEach(store.friends) { friend in
                    friendRow(friend)
                }
            }
        }
    }

    private func relationship(_ id: FlashaID) -> String {
        switch (store.followingIDs.contains(id), store.followerIDs.contains(id)) {
        case (true, true): "Vous vous suivez"
        case (true, false): "Vous suivez"
        case (false, true): "Vous suit"
        case (false, false): "Contact"
        }
    }

    private func friendRow(_ friend: Friend) -> some View {
            HStack(spacing: 12) {
                AvatarView(friend: friend, size: 40)
                VStack(alignment: .leading) {
                    Text(friend.name).font(.headline)
                    Text("@\(friend.username)").font(.caption).foregroundStyle(.secondary)
                    if let id = friend.publicID {
                        Text(relationship(id)).font(.caption2.bold()).foregroundStyle(Theme.pink)
                    }
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
    @State private var code = ""
    @State private var invalid = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("flasha:…", text: $code, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())
                        .onChange(of: code) { invalid = false }
                    Button("Coller", systemImage: "doc.on.clipboard") {
                        code = UIPasteboard.general.string ?? ""
                    }
                    Button("Demander à suivre", systemImage: "person.badge.plus") {
                        if store.follow(code) {
                            dismiss()
                        } else {
                            invalid = true
                        }
                    }
                    .disabled(code.isEmpty)
                } header: {
                    Text("Par identifiant FLASHA")
                } footer: {
                    Text(invalid
                        ? "Cet identifiant n'est pas valable."
                        : "Collez l'identifiant reçu, ou scannez son QR code avec l'appareil photo de l'iPhone. Une demande chiffrée lui est envoyée.")
                }
                Section("Mon identifiant") {
                    ShareLink(item: store.myID.string, message: Text("Ajoute-moi sur FLASHA")) {
                        Label("Partager mon identifiant", systemImage: "qrcode")
                    }
                }
            }
            .navigationTitle("Ajouter un ami")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
