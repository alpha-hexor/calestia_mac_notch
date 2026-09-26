import SwiftUI

struct RadialVisualizer: View {
    let image: NSImage?
    let bands: [Float]
    let isPlaying: Bool

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = side * 0.345
                    for index in bands.indices {
                        let angle = Double(index) / Double(bands.count) * 2 * .pi - .pi / 2
                        let level = isPlaying ? CGFloat(bands[index]) : 0
                        let length = 5 + level * side * 0.125
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * (radius + length), y: center.y + sin(angle) * (radius + length)))
                        context.stroke(path, with: .color(Palette.accent.opacity(isPlaying ? 0.9 : 0.35)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    }
                }
                AlbumArt(image: image).frame(width: side * 0.61, height: side * 0.61).clipShape(Circle())
                    .overlay(Circle().strokeBorder(Palette.peach.opacity(0.6), lineWidth: 3))
            }
        }
        .accessibilityLabel(isPlaying ? "Live circular audio spectrum" : "Album artwork, visualizer paused")
    }
}
