import AppKit
import SwiftUI

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor
final class NotchWindowController: NSWindowController {
    private let model: AppModel
    private var pointerTimer: Timer?
    private var closeTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?
    private var lastInside = false
    private var incomingFileDrag = false
    private let expandedHeight = AppModel.expandedPanelHeight

    init(model: AppModel) {
        self.model = model
        let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        super.init(window: panel)
        let hostingView = NotchDropHostingView(rootView: NotchRootView(model: model))
        hostingView.onFileDrag = { [weak self] in self?.expandForFileDrag() }
        hostingView.onDrop = { [weak model] urls in model?.shelf.add(urls) }
        hostingView.registerForDraggedTypes([.fileURL])
        panel.contentView = hostingView
        position()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position() }
        }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPointer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var targetScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func position() {
        guard let screen = targetScreen, let window else { return }
        let topInset = screen.safeAreaInsets.top
        model.notchHeight = max(30, topInset)
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            model.notchWidth = max(160, right.minX - left.maxX)
        } else {
            model.notchWidth = 184
        }
        model.panelWidth = min(880, screen.frame.width - 32)
        let height = expandedHeight + 18
        window.setFrame(NSRect(x: screen.frame.midX - model.panelWidth / 2, y: screen.frame.maxY - height,
                               width: model.panelWidth, height: height), display: true)
        window.orderFrontRegardless()
    }

    func expand() {
        closeTask?.cancel()
        closeTask = nil
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { model.expanded = true }
        window?.ignoresMouseEvents = false
        lastInside = true
    }

    private func expandForFileDrag() {
        incomingFileDrag = true
        if model.selectedTab != .shelf { model.selectedTab = .shelf }
        if !model.expanded { expand() }
    }

    private func checkPointer() {
        guard let window else { return }
        let point = NSEvent.mouseLocation
        let width = model.expanded ? model.panelWidth : model.notchWidth + 92
        let height = model.expanded
            ? expandedHeight
            : model.notchHeight + 3
        let hitRect = NSRect(x: window.frame.midX - width / 2, y: window.frame.maxY - height, width: width, height: height)
        let inside: Bool
        if model.expanded {
            let localPoint = CGPoint(x: point.x - window.frame.minX, y: window.frame.maxY - point.y)
            inside = ExpandedPanelShape().path(in: CGRect(x: 0, y: 0, width: width, height: height)).contains(localPoint)
        } else {
            inside = hitRect.contains(point)
        }
        if NSEvent.pressedMouseButtons & 1 == 0 { incomingFileDrag = false }
        let keepOpen = incomingFileDrag || model.shelf.keepsPanelOpen
        // A fixed transparent host allows SwiftUI's spring animation without intercepting
        // clicks in the desktop below the collapsed notch.
        window.ignoresMouseEvents = !inside
        if inside || keepOpen {
            closeTask?.cancel()
            closeTask = nil
            if inside && !model.expanded { expand() }
        } else if model.expanded && closeTask == nil {
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, let self else { return }
                self.closeTask = nil
                guard !self.lastInside, !self.incomingFileDrag, !self.model.shelf.keepsPanelOpen else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { self.model.expanded = false }
            }
        }
        lastInside = inside
    }
}

/// The compact notch itself is a drop destination, even before the Shelf exists.
private final class NotchDropHostingView: NSHostingView<NotchRootView> {
    var onFileDrag: (() -> Void)?
    var onDrop: (([URL]) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard FileDragPasteboard.containsFiles(sender.draggingPasteboard) else { return [] }
        onFileDrag?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard FileDragPasteboard.containsFiles(sender.draggingPasteboard) else { return [] }
        onFileDrag?()
        return .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        FileDragPasteboard.containsFiles(sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = FileDragPasteboard.urls(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        onFileDrag?()
        onDrop?(urls)
        return true
    }
}
