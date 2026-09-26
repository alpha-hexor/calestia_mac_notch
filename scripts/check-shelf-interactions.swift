// Compile alongside the Shelf sources; see docs/verification.md for the command.
// Uses real AppKit windows/hit-testing without Accessibility or screen-recording access.
import AppKit
import SwiftUI

@main
struct ShelfInteractionChecks {
    @MainActor static func main() throws {
        exit(try runChecks())
    }

    @MainActor private static func runChecks() throws -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        var failures = 0
        func check(_ condition: Bool, _ name: String) {
            print("\(condition ? "PASS" : "FAIL"): \(name)")
            if !condition { failures += 1 }
        }
        check(NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil) != nil, "AirDrop icon exists in the installed system symbol set")
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("shelf-check-\(UUID().uuidString).txt")
        try Data("Shelf drag fixture".utf8).write(to: fixture)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let sharing = RecordingSharingService()
        let service = ShelfService(makeAirDropService: { sharing })
        let window = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 724, height: 255), styleMask: .borderless, backing: .buffered, defer: false)
        let host = NSHostingView(rootView: ShelfView(shelf: service).frame(width: 724, height: 255))
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        func settle() {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            host.layoutSubtreeIfNeeded()
        }
        func destination(at point: NSPoint) -> NSView? {
            var candidate = host.hitTest(point)
            while let view = candidate {
                if view.registeredDraggedTypes.contains(.fileURL) { return view }
                candidate = view.superview
            }
            return nil
        }
        func findTile(_ view: NSView) -> FileDragSourceView? {
            if let tile = view as? FileDragSourceView { return tile }
            return view.subviews.compactMap(findTile).first
        }
        settle()
        let airDrop = destination(at: NSPoint(x: 90, y: 115))
        let tray = destination(at: NSPoint(x: 450, y: 115))
        check(airDrop != nil, "AirDrop area is reachable as a native file destination")
        check(tray != nil && tray !== airDrop, "Empty tray has its own reachable file destination")

        let incomingPasteboard = NSPasteboard.withUniqueName()
        defer { incomingPasteboard.releaseGlobally() }
        incomingPasteboard.writeObjects([fixture as NSURL])
        let incoming = FileDragInfo(pasteboard: incomingPasteboard, window: window)
        check(tray?.draggingEntered(incoming) == .copy, "Tray negotiates a native copy operation")
        check(tray?.prepareForDragOperation(incoming) == true && tray?.performDragOperation(incoming) == true, "Native drop callback accepts the file")
        check(service.files.map(\.url) == [fixture], "Native tray drop adds the original file reference")
        settle()
        if let tile = findTile(host) {
            let center = NSPoint(x: tile.bounds.midX, y: tile.bounds.midY)
            let point = host.superview!.convert(center, from: tile)
            check(host.hitTest(point) === tile, "File tile receives mouse-down instead of the enclosing scroll view")
            check(destination(at: point) === tray, "Dropping over an existing file routes to the tray")
            // The remove button overlays the native drag source and must remain clickable.
            let removePoint = host.superview!.convert(NSPoint(x: tile.bounds.maxX - 12, y: 12), from: tile)
            check(host.hitTest(removePoint) !== tile, "Remove button is not swallowed by the file drag source")
        } else { check(false, "File tile is rendered") }

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        check(pasteboard.writeObjects([fixture as NSURL]), "Native file URL is writable to a drag pasteboard")
        check(FileDragPasteboard.urls(from: pasteboard) == [fixture], "File URL pasteboard round-trip retains the original file path")
        pasteboard.clearContents()
        pasteboard.setString("https://example.com", forType: .string)
        check(!FileDragPasteboard.containsFiles(pasteboard), "Text/web links are not accepted as file drags")

        let (dragSource, session, oldView) = autoreleasepool { () -> (NSDraggingSource, NSDraggingSession, WeakView) in
            var source: RecordingDragSourceView? = RecordingDragSourceView(rootView: FileTileFace(file: ShelfFile(url: fixture), icon: service.icon(for: ShelfFile(url: fixture)), isMissing: false))
            source!.frame = NSRect(x: 0, y: 0, width: 94, height: 83)
            source!.fileURL = fixture
            source!.dragIcon = service.icon(for: ShelfFile(url: fixture))
            source!.onDragChanged = { service.isDraggingOut = $0 }
            @MainActor func event(_ type: NSEvent.EventType, _ x: CGFloat) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: 20), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
            }
            source!.mouseDown(with: event(.leftMouseDown, 20))
            source!.mouseDragged(with: event(.leftMouseDragged, 21))
            check(source!.capturedSource == nil, "Click jitter does not start a drag")
            source!.mouseDragged(with: event(.leftMouseDragged, 35))
            check(service.isDraggingOut, "Starting a file drag pins the notch open")
            let dragSource = source!.capturedSource!
            let session = source!.testSession
            check((source!.capturedItems.first?.item as? NSURL) == fixture as NSURL, "Actual drag item carries a native file URL, not text or an image")
            check(dragSource.draggingSession(session, sourceOperationMaskFor: .outsideApplication) == .copy, "External drop is copy-only")
            let oldView = WeakView(source!)
            source = nil
            return (dragSource, session, oldView)
        }
        settle()
        check(oldView.value == nil, "Regression fixture releases the tile during a drag")
        dragSource.draggingSession?(session, endedAt: .zero, operation: [])
        check(!service.isDraggingOut, "Canceled drag unpins the notch even when SwiftUI replaced the source tile")

        check(airDrop?.performDragOperation(incoming) == true, "AirDrop area accepts a native file drop")
        check(service.isSharing && sharing.performedItems.isEmpty, "AirDrop pins immediately but presents after the drop callback returns")
        settle()
        check((sharing.performedItems as? [URL]) == [fixture], "AirDrop receives the original file URL")
        service.sharingService(sharing, didFailToShareItems: [fixture], error: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        check(!service.keepsPanelOpen && service.message == nil, "Canceling AirDrop releases the panel without an error")
        service.airDrop([fixture], from: window)
        settle()
        service.sharingService(sharing, didShareItems: [fixture])
        check(!service.keepsPanelOpen, "Completing AirDrop releases the panel for subsequent shares")
        service.clear()
        check(try Data(contentsOf: fixture) == Data("Shelf drag fixture".utf8), "Clearing the tray leaves the original untouched")

        let model = AppModel()
        model.selectedTab = .media
        let controller = NotchWindowController(model: model)
        let notchWindow = controller.window!
        notchWindow.setFrameOrigin(NSPoint(x: -3000, y: -3000))
        defer { notchWindow.orderOut(nil) }
        settle()
        let root = notchWindow.contentView!
        root.layoutSubtreeIfNeeded()
        let compactPoint = root.superview!.convert(NSPoint(x: root.bounds.midX, y: model.notchHeight / 2), from: root)
        check(root.hitTest(compactPoint) != nil && root.registeredDraggedTypes.contains(.fileURL), "Collapsed notch remains a reachable native file destination")
        let notchDrag = FileDragInfo(pasteboard: incomingPasteboard, window: notchWindow)
        check(root.draggingEntered(notchDrag) == .copy && model.expanded && model.selectedTab == .shelf, "Dragging over the collapsed notch expands and selects Shelf")
        check(root.performDragOperation(notchDrag) && model.shelf.files.map(\.url) == [fixture], "Quick drop on the notch is retained before Shelf finishes expanding")
        return failures == 0 ? 0 : 1
    }
}

@MainActor
private final class RecordingDragSourceView: FileDragSourceView {
    var capturedSource: NSDraggingSource?
    var capturedItems: [NSDraggingItem] = []
    let testSession = RecordingDraggingSession()

    override func beginDraggingSession(with items: [NSDraggingItem], event: NSEvent, source: NSDraggingSource) -> NSDraggingSession {
        capturedSource = source
        capturedItems = items
        return testSession
    }
}

private final class WeakView {
    weak var value: NSView?
    init(_ view: NSView) { value = view }
}

private final class RecordingDraggingSession: NSDraggingSession {
    override var animatesToStartingPositionsOnCancelOrFail: Bool {
        get { true }
        set { }
    }
}

@MainActor
private final class RecordingSharingService: NSSharingService {
    var performedItems: [Any] = []
    init() { super.init(title: "Test AirDrop", image: NSImage(size: NSSize(width: 16, height: 16)), alternateImage: nil, handler: {}) }
    override func canPerform(withItems items: [Any]?) -> Bool { items?.isEmpty == false }
    override func perform(withItems items: [Any]) { performedItems = items }
}

private final class FileDragInfo: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    let draggingDestinationWindow: NSWindow?
    let draggingSourceOperationMask: NSDragOperation = .copy
    let draggingLocation = NSPoint.zero
    let draggedImageLocation = NSPoint.zero
    let draggedImage: NSImage? = nil
    let draggingSource: Any? = nil
    let draggingSequenceNumber = 1
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    let springLoadingHighlight: NSSpringLoadingHighlight = .none
    init(pasteboard: NSPasteboard, window: NSWindow) {
        draggingPasteboard = pasteboard
        draggingDestinationWindow = window
    }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}
