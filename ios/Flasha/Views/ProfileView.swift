import SwiftUI

/// Le profil : identité, statistiques privées et confidentialité.
struct ProfileView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        AvatarView(friend: store.me, size: 96)
                        Text(store.me.name).font(.title2.bold())
                        Text("@\(store.me.username)").foregroundStyle(.secondary)
                        HStack {
                            stat("\(store.friends.count)", "Amis")
                            stat("\(store.sentFlashs)", "Flashs envoyés")
                            stat("\(store.following.count)", "Abonnements")
                        }
                        Text("Vos statistiques ne sont visibles que par vous.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Mes publications") {
                    if store.myPosts.isEmpty {
                        Text("Publiez depuis le Fil : vos photos apparaissent ici.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                            ForEach(store.myPosts) { post in
                                ZStack {
                                    LinearGradient(
                                        colors: post.slides.first?.colors ?? [Theme.violet, Theme.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    Image(systemName: post.slides.first?.symbol ?? "photo")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .accessibilityLabel(post.caption.isEmpty ? "Publication" : post.caption)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section("Qui peut…") {
                    Picker("M'envoyer un Flash", selection: $store.whoCanSendFlashs) { audiences }
                    Picker("M'écrire sur Talka", selection: $store.whoCanMessage) { audiences }
                    Picker("Voir mes Stories", selection: $store.whoCanSeeStories) { audiences }
                    Picker("M'appeler", selection: $store.whoCanCall) { audiences }
                }

                Section {
                    Toggle("Afficher ma présence en ligne", isOn: $store.showsOnlineStatus)
                    Toggle("Partager ma localisation", isOn: $store.sharesLocation)
                    Toggle("Alertes de capture d'écran", isOn: $store.screenshotAlerts)
                } header: {
                    Text("Confidentialité")
                } footer: {
                    Text("La localisation est désactivée par défaut. Une capture d'écran n'est pas toujours détectable, et un Flash peut être photographié par un autre appareil.")
                }

                Section {
                    LabeledContent("Utilisé", value: "\(store.mediaBytes.fileSize) sur \(store.mediaQuota.fileSize)")
                    ProgressView(value: Double(store.mediaBytes), total: Double(max(store.mediaQuota, 1)))
                        .tint(Theme.pink)
                    Picker("Limite", selection: Binding(get: { store.mediaQuota }, set: { store.setMediaQuota($0) })) {
                        ForEach(MediaStore.quotas, id: \.self) { quota in
                            Text(quota.fileSize).tag(quota)
                        }
                    }
                    Button("Libérer de l'espace", role: .destructive) { store.clearMediaCache() }
                } header: {
                    Text("Stockage des photos et vidéos")
                } footer: {
                    Text("Tout est enregistré au format FLASHA : photos 1080 × 1440 en HEIC, vidéos 1080 × 1920 en HEVC. Au-delà de la limite, les plus anciennes sont effacées en premier ; vos Souvenirs et les envois en cours sont gardés.")
                }
                .onAppear { store.refreshStorage() }

                Section("FLASHA+") {
                    Label("Stockage étendu, filtres exclusifs et outils de création — 4,99 € par mois (prix indicatif).", systemImage: "sparkles")
                }
            }
            .tint(Theme.pink)
            .navigationTitle("Profil")
        }
    }

    private var audiences: some View {
        ForEach(Audience.allCases) { audience in
            Text(audience.rawValue).tag(audience)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
