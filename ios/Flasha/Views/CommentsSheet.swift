import SwiftUI

/// Les commentaires d'un Clip ou d'une publication, avec le champ pour répondre.
struct CommentsSheet: View {
    let comments: [Comment]
    let onSend: (String) -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if comments.isEmpty {
                    ContentUnavailableView(
                        "Aucun commentaire",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Soyez le premier à commenter.")
                    )
                } else {
                    List(comments) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Theme.gradient)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Text(String(comment.author.prefix(1)).uppercased())
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.author).font(.subheadline.bold())
                                Text(comment.text)
                            }
                            Spacer()
                            if comment.likes > 0 {
                                Label("\(comment.likes)", systemImage: "sparkle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(comments.count) commentaire\(comments.count > 1 ? "s" : "")")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    TextField("Ajouter un commentaire…", text: $draft)
                        .focused($focused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .onSubmit(send)
                    Button("Publier", action: send)
                        .font(.headline)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private func send() {
        withAnimation(.spring) { onSend(draft) }
        draft = ""
    }
}

/// Un nombre en format court : 12 400 → « 12,4 k ».
func compactCount(_ value: Int) -> String {
    value.formatted(.number.notation(.compactName).locale(Locale(identifier: "fr_FR")))
}
