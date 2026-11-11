import PhotosUI
import SwiftUI

/// Le Fil : les publications photo des amis et des créateurs suivis.
struct FeedView: View {
    @Environment(AppStore.self) private var store
    @State private var commenting: FeedPost.ID?
    @State private var composing = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                stories
                ForEach(store.feed) { post in
                    PostCard(post: post) { commenting = post.id }
                }
            }
            .padding(.bottom, 24)
        }
        .toolbar {
            Button("Publier", systemImage: "plus.square") { composing = true }
        }
        .sheet(isPresented: Binding(get: { commenting != nil }, set: { if !$0 { commenting = nil } })) {
            if let id = commenting, let post = store.feed.first(where: { $0.id == id }) {
                CommentsSheet(comments: post.comments) { store.comment($0, onPost: id) }
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $composing) {
            ComposePostView()
                .environment(store)
                .presentationDetents([.medium])
        }
    }

    private var stories: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(store.friends) { friend in
                    VStack(spacing: 6) {
                        AvatarView(friend: friend, size: 68, showsStoryRing: true)
                        Text(friend.name).font(.caption.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
    }
}

/// Une publication : en-tête, carrousel, actions, légende et commentaires.
struct PostCard: View {
    let post: FeedPost
    let onComments: () -> Void

    @Environment(AppStore.self) private var store
    @State private var page = 0
    @State private var burst = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(friend: post.author, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.author.username).font(.subheadline.bold())
                    if let place = post.place {
                        Text(place).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(post.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ZStack(alignment: .topTrailing) {
                TabView(selection: $page) {
                    ForEach(Array(post.slides.enumerated()), id: \.element.id) { index, slide in
                        ZStack {
                            if let mediaID = slide.mediaID {
                                MediaImage(id: mediaID)
                            } else {
                                LinearGradient(colors: slide.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: slide.symbol)
                                    .font(.system(size: 110))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .clipped()
                        .tag(index)
                        .accessibilityLabel("Photo \(index + 1) sur \(post.slides.count)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .aspectRatio(1, contentMode: .fit)
                .onTapGesture(count: 2) { likeOnce() }
                .overlay {
                    if burst {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(.white)
                            .shadow(color: Theme.pink, radius: 16)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }

                if post.slides.count > 1 {
                    Text("\(page + 1)/\(post.slides.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(10)
                }
            }

            HStack(spacing: 18) {
                Button {
                    withAnimation(.spring) { store.toggleLike(post: post.id) }
                } label: {
                    Image(systemName: post.liked ? "heart.fill" : "heart")
                        .foregroundStyle(post.liked ? Theme.pink : .primary)
                        .symbolEffect(.bounce, value: post.liked)
                }
                .accessibilityLabel(post.liked ? "Ne plus aimer" : "J'aime")
                Button(action: onComments) { Image(systemName: "bubble.right") }
                    .accessibilityLabel("Commentaires")
                ShareLink(item: "\(post.caption) — \(post.author.username) sur FLASHA") {
                    Image(systemName: "paperplane")
                }
                .accessibilityLabel("Partager")
                Spacer()
                if post.slides.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<post.slides.count, id: \.self) { index in
                            Circle()
                                .fill(index == page ? AnyShapeStyle(Theme.pink) : AnyShapeStyle(Color.secondary.opacity(0.4)))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Spacer()
                Button {
                    withAnimation(.spring) { store.toggleSave(post: post.id) }
                } label: {
                    Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(post.saved ? "Retirer des favoris" : "Enregistrer")
            }
            .font(.title2)
            .foregroundStyle(.primary)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(compactCount(post.likes)) J'aime").font(.subheadline.bold())
                Text("\(Text(post.author.username).bold()) \(post.caption)")
                    .font(.subheadline)
                if !post.comments.isEmpty {
                    Button("Voir les \(post.comments.count) commentaires", action: onComments)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    private func likeOnce() {
        store.like(post: post.id)
        withAnimation(.spring(duration: 0.3)) { burst = true }
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation { burst = false }
        }
    }
}

/// Publier dans le Fil : une légende et un décor (les vraies photos arrivent avec
/// le serveur de médias).
private struct ComposePostView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var style = 0
    @State private var items: [PhotosPickerItem] = []
    @State private var photos: [EncodedPhoto] = []
    @State private var converting = false

    private let styles: [Slide] = [
        Slide(colors: [Theme.violet, Theme.pink], symbol: "sparkles"),
        Slide(colors: [Theme.orange, Theme.pink], symbol: "sun.max.fill"),
        Slide(colors: [.indigo, .black], symbol: "moon.stars.fill"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $items, maxSelectionCount: 10, matching: .images) {
                        Label(pickerTitle, systemImage: "photo.on.rectangle.angled")
                    }
                    if converting {
                        ProgressView("Conversion en FLASHA Photo…")
                    }
                    if photos.isEmpty {
                        Picker("Décor", selection: $style) {
                            ForEach(styles.indices, id: \.self) { index in
                                Image(systemName: styles[index].symbol).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    Text("Converties en FLASHA Photo (1080 × 1440), chiffrées sur ce téléphone, puis envoyées chiffrées à chacun de vos abonnés.")
                }
                Section("Légende") {
                    TextField("Écrire une légende…", text: $caption, axis: .vertical)
                }
            }
            .onChange(of: items) {
                Task { await convert() }
            }
            .navigationTitle("Nouvelle publication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publier") {
                        if photos.isEmpty {
                            store.publish(caption: caption, slides: [styles[style]])
                        } else {
                            store.publish(caption: caption, photos: photos)
                        }
                        dismiss()
                    }
                    .disabled(converting)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private var pickerTitle: String {
        guard !photos.isEmpty else { return "Choisir des photos" }
        let bytes = Int64(photos.reduce(0) { $0 + $1.data.count })
        return "\(photos.count) photo\(photos.count > 1 ? "s" : "") · \(bytes.fileSize)"
    }

    /// Chaque photo choisie est convertie en FLASHA Photo.
    private func convert() async {
        converting = true
        var result: [EncodedPhoto] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let encoded = try? await PhotoEncoder.encode(image) {
                result.append(encoded)
            }
        }
        photos = result
        converting = false
    }
}
