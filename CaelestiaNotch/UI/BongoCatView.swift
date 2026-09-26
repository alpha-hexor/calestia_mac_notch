import SwiftUI
import ImageIO

private final class BongoAnimation {
    static let shared = BongoAnimation()
    let frames: [NSImage]

    private init() {
        var images: [NSImage] = []
        if let url = Bundle.main.url(forResource: "bongocat", withExtension: "gif"),
           let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            for index in 0..<CGImageSourceGetCount(source) {
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
                images.append(NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
            }
        }
        frames = images
    }

    func frame(for beatCount: UInt) -> NSImage? {
        guard !frames.isEmpty else { return nil }
        return frames[Int(beatCount % UInt(frames.count))]
    }
}

struct BongoCatView: View {
    @ObservedObject var motion: BongoCatController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pulse = reduceMotion ? 0 : motion.tapStrength
        Group {
            if let image = BongoAnimation.shared.frame(for: motion.beatCount) {
                Image(nsImage: image).resizable().scaledToFit()
                    .blendMode(.multiply)
            } else {
                Image(systemName: "cat.fill").resizable().scaledToFit().foregroundStyle(Palette.accent)
            }
        }
        .scaleEffect(x: 1 + pulse * 0.012, y: 1 - pulse * 0.025, anchor: .bottom)
        .offset(y: pulse * 1.2)
        .animation(.easeOut(duration: pulse > 0 ? 0.06 : 0.20), value: pulse)
        .accessibilityLabel("Bongo Cat · taps to detected music beats")
        .help("Taps to bass and drum pulses while Spotify plays and the audio visualizer is enabled.")
        .allowsHitTesting(false)
    }
}
