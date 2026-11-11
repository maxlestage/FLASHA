import SwiftUI

/// Découvrir : les Clips, des vidéos courtes en plein écran, une par page.
/// « Pour toi » montre tout, « Abonnements » seulement les créateurs suivis.
struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @State private var forYou = true
    @State private var commenting: Clip.ID?

    private var clips: [Clip] {
        forYou ? store.clips : store.clips.filter { store.isFollowing($0.creator) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if clips.isEmpty {
                ContentUnavailableView(
                    "Aucun abonnement",
                    systemImage: "person.badge.plus",
                    description: Text("Suivez des créateurs depuis « Pour toi » pour retrouver leurs Clips ici.")
                )
                .foregroundStyle(.white)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(clips) { clip in
                            ClipPage(clip: clip) { commenting = clip.id }
                                .containerRelativeFrame([.horizontal, .vertical])
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            }

            HStack(spacing: 22) {
                tab("Abonnements", selected: !forYou) { forYou = false }
                tab("Pour toi", selected: forYou) { forYou = true }
            }
            .padding(.top, 8)
        }
        .background(Theme.night)
        .sheet(isPresented: Binding(get: { commenting != nil }, set: { if !$0 { commenting = nil } })) {
            if let id = commenting, let clip = store.clips.first(where: { $0.id == id }) {
                CommentsSheet(comments: clip.comments) { store.comment($0, onClip: id) }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func tab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { action() }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(selected ? .white : .white.opacity(0.6))
                Capsule()
                    .fill(Theme.gradient)
                    .frame(width: 28, height: 3)
                    .opacity(selected ? 1 : 0)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 4)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Un Clip en plein écran : décor animé, colonne d'actions et légende.
private struct ClipPage: View {
    let clip: Clip
    let onComments: () -> Void

    @Environment(AppStore.self) private var store
    @State private var drift = false
    @State private var burst = false
    @State private var spin = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: clip.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: clip.symbol)
                .font(.system(size: 150))
                .foregroundStyle(.white.opacity(0.9))
                .scaleEffect(drift ? 1.08 : 0.94)
                .rotationEffect(.degrees(drift ? 4 : -4))
                .offset(y: drift ? -18 : 18)
                .animation(.easeInOut(duration: 2.4).repeatForever(), value: drift)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { drift = true }
                .accessibilityHidden(true)

            if burst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.pink, radius: 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(clip.creator).font(.headline)
                    Text(clip.caption).font(.subheadline)
                    Label(clip.sound, systemImage: "music.note")
                        .font(.caption)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                rail
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { likeOnce() }
    }

    private var rail: some View {
        VStack(spacing: 18) {
            Button {
                withAnimation(.spring) { store.toggleFollow(clip.creator) }
            } label: {
                ZStack(alignment: .bottom) {
                    Circle()
                        .fill(Theme.gradient)
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .overlay {
                            Text(String(clip.creator.dropFirst().prefix(1)).uppercased())
                                .font(.headline)
                        }
                    Image(systemName: store.isFollowing(clip.creator) ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Theme.pink)
                        .offset(y: 10)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .accessibilityLabel(store.isFollowing(clip.creator) ? "Ne plus suivre \(clip.creator)" : "Suivre \(clip.creator)")
            .padding(.bottom, 6)

            railButton(clip.liked ? "heart.fill" : "heart", compactCount(clip.likes), tint: clip.liked ? Theme.pink : .white) {
                withAnimation(.spring) { store.toggleLike(clip: clip.id) }
            }
            .accessibilityLabel(clip.liked ? "Ne plus aimer" : "J'aime")

            railButton("bubble.right.fill", compactCount(clip.comments.count), action: onComments)
                .accessibilityLabel("Commentaires")

            railButton(clip.saved ? "bookmark.fill" : "bookmark", "Favoris", tint: clip.saved ? Theme.orange : .white) {
                withAnimation(.spring) { store.toggleSave(clip: clip.id) }
            }
            .accessibilityLabel(clip.saved ? "Retirer des favoris" : "Enregistrer")

            ShareLink(item: "\(clip.caption) — \(clip.creator) sur FLASHA") {
                VStack(spacing: 2) {
                    Image(systemName: "arrowshape.turn.up.right.fill").font(.title2)
                    Text(compactCount(clip.shares)).font(.caption2.bold())
                }
            }
            .accessibilityLabel("Partager")

            Circle()
                .fill(AngularGradient(colors: [Theme.violet, Theme.pink, Theme.orange, Theme.violet], center: .center))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.black.opacity(0.8), lineWidth: 8))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: spin)
                .onAppear { spin = true }
                .accessibilityHidden(true)
        }
    }

    private func railButton(_ symbol: String, _ label: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                Text(label).font(.caption2.bold())
            }
        }
    }

    private func likeOnce() {
        if !clip.liked {
            store.toggleLike(clip: clip.id)
        }
        withAnimation(.spring(duration: 0.3)) { burst = true }
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation { burst = false }
        }
    }
}
