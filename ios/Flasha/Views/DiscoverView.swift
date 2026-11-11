import SwiftUI

/// Découvrir : un flux vertical, une publication par écran.
struct DiscoverView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(store.posts) { post in
                    PostPage(post: post) { store.toggleLike(post) }
                        .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(Theme.night)
    }
}

private struct PostPage: View {
    let post: Post
    let onLike: () -> Void

    @State private var drift = false
    @State private var burst = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: post.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: post.symbol)
                .font(.system(size: 140))
                .foregroundStyle(.white.opacity(0.9))
                .scaleEffect(drift ? 1.08 : 0.94)
                .offset(y: drift ? -16 : 16)
                .animation(.easeInOut(duration: 3).repeatForever(), value: drift)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { drift = true }
                .accessibilityHidden(true)

            if burst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale.combined(with: .opacity))
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.creator).font(.headline)
                    Text(post.title).font(.title3.weight(.bold))
                    Text(post.hashtag).font(.subheadline).opacity(0.85)
                }
                Spacer()
                VStack(spacing: 18) {
                    Button(action: like) {
                        VStack {
                            Image(systemName: post.liked ? "heart.fill" : "heart")
                                .font(.title)
                                .symbolEffect(.bounce, value: post.liked)
                            Text(post.likes, format: .number.notation(.compactName))
                                .font(.caption.bold())
                        }
                    }
                    .accessibilityLabel(post.liked ? "Ne plus aimer" : "J'aime")
                    Image(systemName: "bubble.right.fill").font(.title)
                        .accessibilityLabel("Commentaires")
                    ShareLink(item: "\(post.title) \(post.hashtag) sur FLASHA") {
                        Image(systemName: "arrowshape.turn.up.right.fill").font(.title)
                    }
                    .accessibilityLabel("Partager")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .onTapGesture(count: 2, perform: like)
    }

    private func like() {
        if !post.liked {
            withAnimation(.spring(duration: 0.3)) { burst = true }
            Task {
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation { burst = false }
            }
        }
        onLike()
    }
}
