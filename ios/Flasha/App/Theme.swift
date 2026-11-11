import SwiftUI
import UIKit

/// L'identité de FLASHA : papier photo, encre, bleu cyanotype et halo orange du flash.
/// Pas de dégradés, des tirages à bord blanc, des étiquettes à ombre franche, et des
/// titres à empattements (`fontDesign(.serif)`).
enum Theme {
    /// Bleu cyanotype : la couleur de FLASHA.
    static let cyan = Color(red: 0.114, green: 0.247, blue: 0.820)
    /// Le halo orange du flash : les accents, le dateur, les éclats.
    static let halo = Color(red: 1.000, green: 0.357, blue: 0.180)
    /// Un orange plus doux, pour les fonds.
    static let haloSoft = Color(red: 1.000, green: 0.694, blue: 0.600)
    /// L'encre, presque noire.
    static let ink = Color(red: 0.082, green: 0.075, blue: 0.059)
    /// Le papier photo.
    static let paperLight = Color(red: 0.949, green: 0.925, blue: 0.882)

    /// Le fond des écrans : papier le jour, chambre noire en mode sombre.
    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.063, green: 0.055, blue: 0.047, alpha: 1)
            : UIColor(red: 0.949, green: 0.925, blue: 0.882, alpha: 1)
    })

    /// Le bord blanc d'un tirage.
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.114, green: 0.102, blue: 0.086, alpha: 1)
            : UIColor(red: 0.984, green: 0.973, blue: 0.949, alpha: 1)
    })

    /// Le trait d'encre, qui s'éclaircit dans la chambre noire.
    static let line = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.941, green: 0.914, blue: 0.863, alpha: 1)
            : UIColor(red: 0.082, green: 0.075, blue: 0.059, alpha: 1)
    })

    // Les anciens noms, gardés pour le code existant : plus aucun dégradé arc-en-ciel.
    static let violet = cyan
    static let pink = halo
    static let orange = haloSoft
    static let night = ink

    /// Un aplat cyanotype (le « dégradé » d'avant n'en est plus un).
    static let gradient = LinearGradient(colors: [cyan, cyan], startPoint: .top, endPoint: .bottom)

    /// Le cercle des Pellicules : des perforations orange.
    static let ring = AngularGradient(colors: [halo, halo], center: .center)

    /// Le dateur orange des tirages : « 11 11 '26 ».
    static func dateStamp(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.day, .month, .year], from: date)
        return String(format: "%02d %02d '%02d", parts.day ?? 0, parts.month ?? 0, (parts.year ?? 0) % 100)
    }
}

/// Une étiquette FLASHA : rectangle cyanotype, trait d'encre et ombre franche.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.paperLight)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.ink, lineWidth: 2))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.ink)
                    .offset(x: pressed ? 1 : 4, y: pressed ? 1 : 4)
            )
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .animation(.spring(duration: 0.2), value: pressed)
    }
}

extension ButtonStyle where Self == GradientButtonStyle {
    static var flasha: GradientButtonStyle { GradientButtonStyle() }
}

extension View {
    /// Le fond papier, à la place du gris des listes et formulaires.
    func paperBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.paper)
    }

    /// Le développement : l'image apparaît comme dans le bac de révélateur.
    func developing() -> some View {
        modifier(Developing())
    }
}

private struct Developing: ViewModifier {
    @State private var developed = false

    func body(content: Content) -> some View {
        content
            .blur(radius: developed ? 0 : 8)
            .saturation(developed ? 1 : 0.1)
            .brightness(developed ? 0 : 0.35)
            .overlay(Theme.paperLight.opacity(developed ? 0 : 0.45).allowsHitTesting(false))
            .onAppear {
                withAnimation(.easeOut(duration: 2.4)) { developed = true }
            }
    }
}
