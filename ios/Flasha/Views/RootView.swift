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
            Tab("Caméra", systemImage: "camera.fill", value: AppTab.camera) {
                CameraScreen()
            }
            Tab("Découvrir", systemImage: "safari.fill", value: AppTab.discover) {
                DiscoverView()
            }
            Tab("Profil", systemImage: "person.crop.circle.fill", value: AppTab.profile) {
                ProfileView()
            }
        }
    }
}

/// L'avatar d'un ami, avec l'anneau animé de ses nouvelles stories.
struct AvatarView: View {
    let friend: Friend
    var size: CGFloat = 52
    var showsStoryRing = false

    @State private var spin = false

    var body: some View {
        ZStack {
            if showsStoryRing && friend.hasNewStory {
                Circle()
                    .strokeBorder(Theme.ring, lineWidth: 3)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: spin)
                    .onAppear { spin = true }
            }
            Circle()
                .fill(friend.color.gradient)
                .padding(showsStoryRing ? 6 : 0)
            Text(friend.initial)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(friend.name)
    }
}

#Preview {
    RootView().environment(AppStore.preview())
}
