import SwiftUI
import UIKit

/// Le profil : identité, statistiques privées et confidentialité.
struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmingErase = false
    @State private var relayDraft = ""

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

                Section {
                    QRCodeView(text: store.myID.string)
                        .frame(maxWidth: 220)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    LabeledContent("Empreinte", value: store.myID.fingerprint)
                        .font(.footnote.monospaced())
                    Button("Copier mon identifiant", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = store.myID.string
                    }
                    ShareLink(item: store.myID.string, message: Text("Ajoute-moi sur FLASHA")) {
                        Label("Partager mon identifiant", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Mon identifiant FLASHA")
                } footer: {
                    Text("Pas d'annuaire : on vous ajoute avec ce QR code ou cet identifiant, qui contient vos clés publiques. Vos clés privées ne quittent jamais ce téléphone.")
                }

                Section {
                    TextField("https://flasha.example.com", text: $relayDraft)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { store.setRelayURL(relayDraft) }
                    LabeledContent("État", value: relayStatus)
                    LabeledContent("Abonnés", value: "\(store.followerIDs.count)")
                    LabeledContent("En attente d'accusé", value: "\(store.outbox.count)")
                    Button("Se connecter") { store.setRelayURL(relayDraft) }
                        .disabled(relayDraft.isEmpty)
                } header: {
                    Text("Relais")
                } footer: {
                    Text("Le relais ne fait que transmettre des paquets chiffrés de bout en bout : il n'a ni base de données ni disque, et ne peut rien lire. Un paquet reste dans votre boîte d'envoi jusqu'à l'accusé de réception.")
                }
                .onAppear { relayDraft = store.relayURL }

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
                    Text("Tout est chiffré et enregistré au format FLASHA : photos 1080 × 1440 en HEIC, vidéos 1080 × 1920 en HEVC. Au-delà de la limite, les plus anciennes sont effacées en premier ; vos Souvenirs et les envois en cours sont gardés.")
                }
                .onAppear { store.refreshStorage() }

                Section {
                    Label("Chiffrées en AES-256 sur cet iPhone", systemImage: "lock.shield.fill")
                    Label("Aucun serveur, aucune base de données externe", systemImage: "iphone")
                    Button("Effacer toutes mes données", role: .destructive) { confirmingErase = true }
                } header: {
                    Text("Mes données")
                } footer: {
                    Text("Profil, abonnements, messages, Flashs et médias sont chiffrés avec une clé créée sur ce téléphone, qui ne le quitte jamais : ni iCloud ni une sauvegarde ne peuvent les relire. Si vous changez d'iPhone, elles ne suivent pas.")
                }
                .confirmationDialog("Effacer toutes les données de cet iPhone ?", isPresented: $confirmingErase, titleVisibility: .visible) {
                    Button("Tout effacer", role: .destructive) { store.eraseEverything() }
                } message: {
                    Text("Le coffre et les photos et vidéos chiffrés seront supprimés. C'est définitif.")
                }

                Section("FLASHA+") {
                    Label("Stockage étendu, filtres exclusifs et outils de création — 4,99 € par mois (prix indicatif).", systemImage: "sparkles")
                }
            }
            .tint(Theme.cyan)
            .paperBackground()
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

    private var relayStatus: String {
        switch store.relay.status {
        case .online: "Connecté"
        case .connecting: "Connexion…"
        case .offline: store.relayURL.isEmpty ? "Aucun relais" : "Hors ligne"
        }
    }
}
