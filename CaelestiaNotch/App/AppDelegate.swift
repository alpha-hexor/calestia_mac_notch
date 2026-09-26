import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var notch: NotchWindowController?
    private var statusItem: NSStatusItem?
    private var audioSubscription: AnyCancellable?
    private var captureItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.start()
        notch = NotchWindowController(model: model)
        notch?.showWindow(nil)
        setupMenu()
    }

    private func setupMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: PermissionSettings.appName)
        item.button?.toolTip = PermissionSettings.appName
        let menu = NSMenu()
        menu.addItem(withTitle: PermissionSettings.appName, action: nil, keyEquivalent: "")
        add("Show Notch", action: #selector(showNotch), to: menu)
        menu.addItem(.separator())
        captureItem = add("Enable Audio Visualizer…", action: #selector(toggleCapture), to: menu)
        add("Spotify Automation Settings…", action: #selector(automationSettings), to: menu)
        add("Audio Capture Settings…", action: #selector(captureSettings), to: menu)
        add("Show Running App in Finder", action: #selector(revealApp), to: menu)
        add("Retry Spotify Connection", action: #selector(retrySpotify), to: menu)
        menu.addItem(.separator())
        add("About & Credits", action: #selector(about), to: menu)
        add("Quit Caelestia Notch", action: #selector(quit), key: "q", to: menu)
        item.menu = menu
        statusItem = item
        audioSubscription = model.audio.$state.sink { [weak self] state in
            self?.captureItem?.title = state == .running ? "Disable Audio Visualizer" : "Enable Audio Visualizer…"
            self?.captureItem?.isEnabled = state != .starting
        }
    }

    @discardableResult
    private func add(_ title: String, action: Selector, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func showNotch() { notch?.expand() }
    @objc private func toggleCapture() {
        Task {
            if model.audio.state == .running { await model.audio.stop() }
            else { await model.audio.start() }
        }
    }
    @objc private func automationSettings() { PermissionSettings.openAutomation() }
    @objc private func captureSettings() { PermissionSettings.openCapture() }
    @objc private func revealApp() { PermissionSettings.revealRunningApp() }
    @objc private func retrySpotify() { model.spotify.retry() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Caelestia Notch",
            .applicationVersion: "0.1.0",
            .credits: NSAttributedString(string: "A little music, a little company.\n\nInspired by caelestia-dots/shell.\nBongo Cat GIF from Caelestia Shell (GPL-3.0).\nSee bundled THIRD_PARTY_NOTICES.md and GPL-3.0.txt.\nNo affiliation with Spotify or Caelestia."),
        ])
    }
}

enum PermissionSettings {
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Caelestia Notch"
    }

    static func openAutomation() { open("Privacy_Automation") }
    static func openCapture() { open("Privacy_ScreenCapture") }
    static func revealRunningApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @MainActor
    static func showCaptureError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Audio capture could not start"
        alert.informativeText = "\(message)\n\nRunning app: \(appName)\n\(Bundle.main.bundlePath)\n\nIf access is already enabled, remove the old entry from Screen & System Audio Recording and add this exact app using +. Debug and Release builds need separate approvals. Quit and reopen this same app afterward, then click Enable visualizer."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Show This App in Finder")
        alert.addButton(withTitle: "Close")
        switch alert.runModal() {
        case .alertFirstButtonReturn: openCapture()
        case .alertSecondButtonReturn: revealRunningApp()
        default: break
        }
    }

    private static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
