import SwiftUI

enum Palette {
    static let cream = Color(red: 1.0, green: 0.974, blue: 0.956)
    static let card = Color(red: 0.985, green: 0.920, blue: 0.895)
    static let peach = Color(red: 0.975, green: 0.816, blue: 0.768)
    static let accent = Color(red: 0.59, green: 0.33, blue: 0.27)
    static let ink = Color(red: 0.28, green: 0.22, blue: 0.21)
    static let muted = Color(red: 0.58, green: 0.48, blue: 0.44)
    static let olive = Color(red: 0.57, green: 0.57, blue: 0.36)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Palette.peach.opacity(configuration.isPressed ? 0.85 : 0.45), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct AlbumArt: View {
    let image: NSImage?
    var body: some View {
        ZStack {
            Palette.peach
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.accent)
            }
        }.clipped()
    }
}

func playbackTime(_ seconds: Double) -> String {
    let value = seconds.isFinite ? max(0, Int(seconds)) : 0
    return String(format: "%d:%02d", value / 60, value % 60)
}
