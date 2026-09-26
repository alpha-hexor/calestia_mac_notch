import SwiftUI

struct NotchRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            CompactNotchView(spotify: model.spotify, audio: model.audio, notchWidth: model.notchWidth)
                .frame(width: model.notchWidth + 92, height: model.notchHeight)
                .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
                .zIndex(2)

            if model.expanded {
                VStack(spacing: 0) {
                    tabs
                    Group {
                        switch model.selectedTab {
                        case .dashboard: DashboardView(spotify: model.spotify, system: model.system, bongo: model.bongo)
                        case .media: MediaView(spotify: model.spotify, audio: model.audio, bongo: model.bongo)
                        case .performance: PerformanceView(system: model.system)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(18)
                }
                .frame(width: model.panelWidth, height: AppModel.expandedBodyHeight)
                .background(Palette.cream, in: UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
                .overlay(alignment: .bottom) {
                    Capsule().fill(Palette.peach).frame(width: 34, height: 3).padding(.bottom, 7)
                }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
                .transition(.asymmetric(insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity), removal: .scale(scale: 0.8, anchor: .top).combined(with: .opacity)))
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
                    .frame(maxWidth: .infinity).frame(height: 59)
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
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.peach.opacity(0.55)).frame(height: 1) }
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
