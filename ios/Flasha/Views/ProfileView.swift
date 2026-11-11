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
                            stat("\(store.publishedStories)", "Stories")
                        }
                        Text("Vos statistiques ne sont visibles que par vous.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
