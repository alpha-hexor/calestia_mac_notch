import AppKit
import SwiftUI

enum FileDragPasteboard {
    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL] ?? []
        return objects.map { $0 as URL }.filter(\.isFileURL)
    }

    static func containsFiles(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }
}

/// A real AppKit destination surrounding SwiftUI content, so buttons remain clickable
/// and file drags use the same native pasteboard format as Finder.
struct FileDropContainer<Content: View>: NSViewRepresentable {
    var onTargetChanged: (Bool) -> Void
    var onDrop: ([URL], NSWindow?) -> Void
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> FileDropHostingView<Content> {
        let view = FileDropHostingView(rootView: content)
        view.registerForDraggedTypes([.fileURL])
        view.onTargetChanged = onTargetChanged
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ view: FileDropHostingView<Content>, context: Context) {
        view.rootView = content
        view.onTargetChanged = onTargetChanged
        view.onDrop = onDrop
    }
}

final class FileDropHostingView<Content: View>: NSHostingView<Content> {
    var onTargetChanged: ((Bool) -> Void)?
    var onDrop: (([URL], NSWindow?) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let valid = FileDragPasteboard.containsFiles(sender.draggingPasteboard)
        onTargetChanged?(valid)
        return valid ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDragPasteboard.containsFiles(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { onTargetChanged?(false) }
    override func draggingEnded(_ sender: NSDraggingInfo) { onTargetChanged?(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        FileDragPasteboard.containsFiles(sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetChanged?(false)
        let urls = FileDragPasteboard.urls(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        onDrop?(urls, window)
        return true
    }
}

struct FileDragSource: NSViewRepresentable {
    let file: ShelfFile
    let icon: NSImage
    let isMissing: Bool
    var onDragChanged: (Bool) -> Void
    var onMissing: () -> Void

    func makeNSView(context: Context) -> FileDragSourceView {
        let view = FileDragSourceView(rootView: face)
        configure(view)
        return view
    }

    func updateNSView(_ view: FileDragSourceView, context: Context) {
        view.rootView = face
        configure(view)
    }

    private var face: FileTileFace { FileTileFace(file: file, icon: icon, isMissing: isMissing) }
    private func configure(_ view: FileDragSourceView) {
        view.fileURL = file.url
        view.dragIcon = icon
        view.onDragChanged = onDragChanged
        view.onMissing = onMissing
        view.toolTip = file.url.path
        view.setAccessibilityLabel("\(file.name). Drag to share a copy.")
    }
}

struct FileTileFace: View {
    let file: ShelfFile
    let icon: NSImage
    let isMissing: Bool

    var body: some View {
        VStack(spacing: 7) {
            Image(nsImage: icon).resizable().scaledToFit().frame(width: 40, height: 40)
                .opacity(isMissing ? 0.35 : 1)
                .overlay(alignment: .bottomTrailing) {
                    if isMissing { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.accent) }
                }
            Text(file.name).font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1).truncationMode(.middle)
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .background(Palette.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
final class FileDragCoordinator: NSObject, NSDraggingSource {
    private var onEnded: (() -> Void)?
    private var sessionLifetime: FileDragCoordinator?

    func begin(onEnded: @escaping () -> Void) {
        self.onEnded = onEnded
        // SwiftUI may remove the source tile while AppKit still owns the drag.
        sessionLifetime = self
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let completion = onEnded
        onEnded = nil
        sessionLifetime = nil
        completion?()
    }
}

class FileDragSourceView: NSHostingView<FileTileFace> {
    var fileURL: URL?
    var dragIcon: NSImage?
    var onDragChanged: ((Bool) -> Void)?
    var onMissing: (() -> Void)?
    private let dragCoordinator = FileDragCoordinator()
    private var mouseDownPoint: NSPoint?
    private var dragging = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseUp(with event: NSEvent) { mouseDownPoint = nil }

    override func mouseDragged(with event: NSEvent) {
        guard !dragging, let origin = mouseDownPoint, let fileURL else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - origin.x, point.y - origin.y) >= 4 else { return }
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            mouseDownPoint = nil
            onMissing?()
            return
        }
        dragging = true
        onDragChanged?(true)
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        item.setDraggingFrame(NSRect(x: point.x - 24, y: point.y - 24, width: 48, height: 48), contents: dragIcon)
        let notifyDragChanged = onDragChanged
        dragCoordinator.begin { [weak self] in
            self?.dragging = false
            self?.mouseDownPoint = nil
            // Do not guard on self: the service must be notified even after the tile disappears.
            notifyDragChanged?(false)
        }
        let session = beginDraggingSession(with: [item], event: event, source: dragCoordinator)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
}
