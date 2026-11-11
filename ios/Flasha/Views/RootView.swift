import SwiftUI

enum AppTab: String, Hashable {
    case friends, talka, camera, discover, profile

    /// L'onglet d'ouverture : la caméra, sauf si l'app est lancée avec
    /// `-flashaTab <onglet>` (captures d'écran automatiques dans le simulateur).
    static var initial: AppTab {
        UserDefaults.standard.string(forKey: "flashaTab").flatMap(AppTab.init(rawValue:)) ?? .camera
    }
}

/// La navigation principale, en cinq sections, qui s'ouvre sur la caméra.
struct RootView: View {
    @State private var tab: AppTab = .initial

    var body: some View {
        TabView(selection: $tab) {
            Tab("Amis", systemImage: "person.2.fill", value: AppTab.friends) {
                FriendsView()
            }
            Tab("Talka", systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.talka) {
                TalkaView()
            }
            Tab("Chambre", systemImage: "camera.aperture", value: AppTab.camera) {
                CameraScreen()
            }
            Tab("Rushs", systemImage: "film.stack", value: AppTab.discover) {
                DiscoverView()
            }
            Tab("Profil", systemImage: "person.crop.circle.fill", value: AppTab.profile) {
                ProfileView()
            }
        }
    }
}

/// L'avatar d'un ami : un tirage de photomaton carré ; autour, les perforations orange
/// de sa Pellicule du jour.
struct AvatarView: View {
    let friend: Friend
    var size: CGFloat = 52
    var showsStoryRing = false

    @State private var spin = false

    var body: some View {
        ZStack {
            if showsStoryRing && friend.hasNewStory {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .strokeBorder(Theme.halo, style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
                    .rotationEffect(.degrees(spin ? 4 : -4))
                    .animation(.easeInOut(duration: 1.6).repeatForever(), value: spin)
                    .onAppear { spin = true }
            }
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(friend.color)
                .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(Theme.line, lineWidth: 2))
                .padding(showsStoryRing ? 7 : 0)
            Text(friend.initial)
                .font(.system(size: size * 0.4, weight: .heavy, design: .serif).italic())
                .foregroundStyle(Theme.paperLight)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(friend.name)
    }
}

#Preview {
    RootView().environment(AppStore.preview())
}
