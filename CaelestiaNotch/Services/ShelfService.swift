import AppKit
import Combine

@MainActor
final class ShelfService: NSObject, ObservableObject, NSSharingServiceDelegate {
    @Published private(set) var files: [ShelfFile] = []
    @Published private(set) var unavailableIDs: Set<String> = []
    @Published private(set) var message: String?
    @Published private(set) var isChoosingFiles = false
    @Published private(set) var isSharing = false
    @Published var isDraggingOut = false

    var keepsPanelOpen: Bool { isChoosingFiles || isSharing || isDraggingOut }
    private var shelf = TemporaryFileShelf()
    private var icons: [String: NSImage] = [:]
    private var sharingService: NSSharingService?
    private weak var sharingWindow: NSWindow?
    private let makeAirDropService: () -> NSSharingService?

    init(makeAirDropService: @escaping () -> NSSharingService? = { NSSharingService(named: .sendViaAirDrop) }) {
        self.makeAirDropService = makeAirDropService
        super.init()
    }

    func add(_ urls: [URL]) {
        let result = shelf.add(urls)
        files = shelf.files
        refreshAvailability()
        if result.rejected > 0 {
            message = "\(result.rejected) item(s) couldn't be added. Use accessible local files or folders."
        } else if result.added > 0 {
            message = "Added \(result.added) item(s) · originals stay where they are."
        } else if result.duplicates > 0 {
            message = "Those files are already in your tray."
        }
    }

    func remove(_ file: ShelfFile) {
        shelf.remove(id: file.id)
        files = shelf.files
        icons.removeValue(forKey: file.id)
        unavailableIDs.remove(file.id)
        message = nil
    }

    func clear() {
        shelf.clear()
        files = []
        icons.removeAll()
        unavailableIDs.removeAll()
        message = nil
    }

    func icon(for file: ShelfFile) -> NSImage {
        if let icon = icons[file.id] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: file.url.path)
        icons[file.id] = icon
        return icon
    }

    func refreshAvailability() {
        unavailableIDs = Set(files.filter { !FileManager.default.isReadableFile(atPath: $0.url.path) }.map(\.id))
    }

    func reportMissingFile() {
        refreshAvailability()
        message = "This original file was moved, deleted, or is no longer readable. Add it again from Finder."
    }

    func chooseFiles(forAirDrop: Bool) {
        guard !keepsPanelOpen else { return }
        let sourceWindow = NSApp.keyWindow
        isChoosingFiles = true
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = forAirDrop ? "AirDrop" : "Add to Shelf"
        panel.message = forAirDrop ? "Choose files to share with a nearby device." : "Add temporary references. Your original files stay in place."
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                self.isChoosingFiles = false
                guard response == .OK else { return }
                if forAirDrop { self.airDrop(panel.urls, from: sourceWindow) }
                else { self.add(panel.urls) }
            }
        }
    }

    func airDrop(_ urls: [URL], from window: NSWindow? = nil) {
        guard !isSharing else { return }
        let valid = urls.filter { $0.isFileURL && FileManager.default.isReadableFile(atPath: $0.path) }
        guard !valid.isEmpty, valid.count == urls.count else {
            message = "AirDrop needs accessible local files or folders."
            return
        }
        guard let service = makeAirDropService(), service.canPerform(withItems: valid) else {
            message = "AirDrop isn't available. Check that Wi-Fi and Bluetooth are enabled."
            return
        }
        message = nil
        sharingWindow = window
        sharingService = service
        service.delegate = self
        isSharing = true
        // Finish AppKit's incoming drop before activating another window or starting
        // the sharing service's UI. Pin immediately so the source panel stays alive.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sharingService === service else { return }
            NSApp.activate(ignoringOtherApps: true)
            service.perform(withItems: valid)
        }
    }

    func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any], sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        sharingContentScope.pointee = .item
        return sharingWindow
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        guard self.sharingService === sharingService else { return }
        finishSharing(message: "Sent with AirDrop.")
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        guard self.sharingService === sharingService else { return }
        let error = error as NSError
        let canceled = error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
        finishSharing(message: canceled ? nil : "AirDrop: \(error.localizedDescription)")
    }

    private func finishSharing(message: String?) {
        self.message = message
        sharingService?.delegate = nil
        sharingService = nil
        sharingWindow = nil
        isSharing = false
    }
}
