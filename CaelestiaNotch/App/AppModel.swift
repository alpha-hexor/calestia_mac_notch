import SwiftUI

enum NotchTab: String, CaseIterable {
    case dashboard = "Dashboard", media = "Media", performance = "Performance"

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .media: "music.note.list"
        case .performance: "gauge.with.dots.needle.50percent"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let expandedBodyHeight: CGFloat = 350
    let spotify = SpotifyService()
    let audio = AudioCaptureService()
    let bongo = BongoCatController()
    let lyrics = LyricsService()
    let system = SystemMonitor()
    @Published var expanded = false
    @Published var notchWidth: CGFloat = 190
    @Published var notchHeight: CGFloat = 32
    @Published var panelWidth: CGFloat = 760
    @Published var selectedTab: NotchTab {
        didSet { UserDefaults.standard.set(selectedTab.rawValue, forKey: "selectedTab") }
    }

    init() {
        selectedTab = NotchTab(rawValue: UserDefaults.standard.string(forKey: "selectedTab") ?? "") ?? .media
        bongo.connect(audio: audio, spotify: spotify)
        lyrics.connect(spotify: spotify)
    }

    func start() {
        spotify.start()
        system.start()
    }
}
