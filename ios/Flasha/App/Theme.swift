import SwiftUI

/// L'identité visuelle de FLASHA : violet, rose, orange.
enum Theme {
    static let violet = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let pink = Color(red: 0.925, green: 0.282, blue: 0.600)
    static let orange = Color(red: 0.984, green: 0.573, blue: 0.235)
    static let night = Color(red: 0.051, green: 0.024, blue: 0.094)

    static let gradient = LinearGradient(
        colors: [violet, pink, orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ring = AngularGradient(
        colors: [violet, pink, orange, violet],
        center: .center
    )
}

/// Un bouton plein, au dégradé de FLASHA.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Theme.gradient, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GradientButtonStyle {
    static var flasha: GradientButtonStyle { GradientButtonStyle() }
}
