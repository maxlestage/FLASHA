import SwiftUI
import UIKit

/// Talka : la liste des conversations.
struct TalkaView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""

    private var conversations: [Conversation] {
        guard !search.isEmpty else { return store.conversations }
        return store.conversations.filter {
            $0.friend.name.localizedCaseInsensitiveContains(search)
                || $0.messages.contains { $0.text.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        NavigationStack {
            List(conversations) { conversation in
                NavigationLink(value: conversation.id) {
                    HStack(spacing: 12) {
                        AvatarView(friend: conversation.friend, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.friend.name).font(.headline)
                            Text(conversation.lastMessage?.text ?? "Dites bonjour 👋")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Talka")
            .searchable(text: $search, prompt: "Rechercher")
            .navigationDestination(for: Conversation.ID.self) { id in
                ChatView(conversationID: id)
            }
        }
    }
}

/// Une conversation : messages, réactions, et Léa qui répond.
struct ChatView: View {
    let conversationID: Conversation.ID

    @Environment(AppStore.self) private var store
    @State private var draft = ""
    @State private var showsCallInfo = false
    @FocusState private var focused: Bool

    private var conversation: Conversation? {
        store.conversations.first { $0.id == conversationID }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(conversation?.messages ?? []) { message in
                        bubble(message)
                            .id(message.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: conversation?.messages.count) {
                if let last = conversation?.messages.last {
                    withAnimation(.spring) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(conversation?.friend.name ?? "Talka")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Appel audio", systemImage: "phone.fill") { showsCallInfo = true }
                Button("Appel vidéo", systemImage: "video.fill") { showsCallInfo = true }
            }
        }
        .alert("Appels Talka", isPresented: $showsCallInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Les appels audio et vidéo arrivent avec la phase 2 de Talka.")
        }
    }

    private func bubble(_ message: Message) -> some View {
        HStack {
            if message.fromMe { Spacer(minLength: 48) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(message.fromMe ? .white : .primary)
                .background {
                    if message.fromMe {
                        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20)
                            .fill(Theme.gradient)
                    } else {
                        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20)
                            .fill(Color(.secondarySystemBackground))
                    }
                }
                .overlay(alignment: message.fromMe ? .bottomLeading : .bottomTrailing) {
                    if let reaction = message.reaction {
                        Text(reaction)
                            .font(.caption)
                            .padding(4)
                            .background(.regularMaterial, in: Circle())
                            .offset(x: message.fromMe ? -8 : 8, y: 12)
                    }
                }
                .contextMenu {
                    ForEach(["❤️", "😂", "🔥", "👍"], id: \.self) { emoji in
                        Button(emoji) {
                            withAnimation(.spring) { store.react(emoji, to: message.id, in: conversationID) }
                        }
                    }
                    Button("Copier", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = message.text
                    }
                }
            if !message.fromMe { Spacer(minLength: 48) }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.gradient, in: Circle())
            }
            .accessibilityLabel("Envoyer")
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send() {
        withAnimation(.spring) { store.send(draft, in: conversationID) }
        draft = ""
    }
}
