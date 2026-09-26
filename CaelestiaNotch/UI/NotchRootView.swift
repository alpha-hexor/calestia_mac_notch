import SwiftUI

struct NotchRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.expanded {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.black.frame(height: model.notchHeight)
                        Palette.cream
                    }
                    .clipShape(ExpandedPanelShape())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 5)

                    VStack(spacing: 0) {
                        tabs
                        Group {
                            switch model.selectedTab {
                            case .dashboard: DashboardView(spotify: model.spotify, system: model.system, bongo: model.bongo)
                            case .media: MediaView(spotify: model.spotify, audio: model.audio, bongo: model.bongo, lyrics: model.lyrics)
                            case .performance: PerformanceView(system: model.system)
                            case .shelf: ShelfView(shelf: model.shelf)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(14)
                    }
                    .padding(.horizontal, ExpandedPanelShape.shoulderWidth)
                    .padding(.top, model.notchHeight + 10)
                    .padding(.bottom, 10)

                    Capsule().fill(Palette.peach)
                        .frame(width: 34, height: 3)
                        .padding(.bottom, 7)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: model.panelWidth, height: AppModel.expandedPanelHeight)
                .transition(.asymmetric(insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity), removal: .scale(scale: 0.8, anchor: .top).combined(with: .opacity)))
            } else {
                CompactNotchView(spotify: model.spotify, audio: model.audio, notchWidth: model.notchWidth)
                    .frame(width: model.notchWidth + 92, height: model.notchHeight)
                    .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .frame(width: model.panelWidth, alignment: .top)
        .foregroundStyle(Palette.ink)
        .font(.system(size: 12, design: .rounded))
        .preferredColorScheme(.light)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(NotchTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { model.selectedTab = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol).font(.system(size: 16, weight: .medium))
                        Text(tab.rawValue).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(model.selectedTab == tab ? Palette.accent : Palette.muted)
                    .frame(maxWidth: .infinity).frame(height: 51)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        if model.selectedTab == tab {
                            UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                                .fill(Palette.accent).frame(width: 48, height: 3)
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.peach.opacity(0.55)).frame(height: 1) }
    }
}

/// Inverted upper corners: wide at the screen edge, curving inward into the body.
struct ExpandedPanelShape: Shape {
    static let shoulderWidth: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        let shoulder = Self.shoulderWidth
        let radius: CGFloat = 24
        let left = rect.minX + shoulder
        let right = rect.maxX - shoulder
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(to: CGPoint(x: right, y: rect.minY + 58),
                      control1: CGPoint(x: right, y: rect.minY),
                      control2: CGPoint(x: right, y: rect.minY + 24))
        path.addLine(to: CGPoint(x: right, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: right - radius, y: rect.maxY),
                          control: CGPoint(x: right, y: rect.maxY))
        path.addLine(to: CGPoint(x: left + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.maxY - radius),
                          control: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: left, y: rect.minY + 58))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                      control1: CGPoint(x: left, y: rect.minY + 24),
                      control2: CGPoint(x: left, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct CompactNotchView: View {
    @ObservedObject var spotify: SpotifyService
    @ObservedObject var audio: AudioCaptureService
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if spotify.track != nil {
                    AlbumArt(image: spotify.artwork).frame(width: 22, height: 22).clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "moon.stars.fill").font(.system(size: 13)).foregroundStyle(Palette.peach)
                }
            }.frame(width: 46)
            Color.black.frame(width: notchWidth)
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4) { index in
                    Capsule().fill(Palette.peach)
                        .frame(width: 3, height: spotify.isPlaying ? 4 + CGFloat(audio.bands[index * 8]) * 17 : 4)
                }
            }.frame(width: 46)
        }
        .accessibilityLabel(spotify.isPlaying ? "Spotify playing. Hover to expand." : "Caelestia Notch. Hover to expand.")
    }
}
