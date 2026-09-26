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
    private let bodyHeight = AppModel.expandedBodyHeight

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
        panel.contentView = NSHostingView(rootView: NotchRootView(model: model))
        position()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position() }
        }
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPointer() }
        }
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
        model.panelWidth = min(760, screen.frame.width - 32)
        let height = model.notchHeight + bodyHeight + 18
        window.setFrame(NSRect(x: screen.frame.midX - model.panelWidth / 2, y: screen.frame.maxY - height,
                               width: model.panelWidth, height: height), display: true)
        window.orderFrontRegardless()
    }

    func expand() {
        closeTask?.cancel()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { model.expanded = true }
        window?.ignoresMouseEvents = false
        lastInside = true
    }

    private func checkPointer() {
        guard let window else { return }
        let point = NSEvent.mouseLocation
        let width = model.expanded ? model.panelWidth : model.notchWidth + 92
        let height = model.expanded ? model.notchHeight + bodyHeight : model.notchHeight + 3
        let hitRect = NSRect(x: window.frame.midX - width / 2, y: window.frame.maxY - height, width: width, height: height)
        let inside = hitRect.contains(point)
        // A fixed transparent host allows SwiftUI's spring animation without intercepting
        // clicks in the desktop below the collapsed notch.
        window.ignoresMouseEvents = !inside
        if inside {
            closeTask?.cancel()
            closeTask = nil
            if !model.expanded { expand() }
        } else if lastInside && model.expanded {
            closeTask?.cancel()
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, let self else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { self.model.expanded = false }
            }
        }
        lastInside = inside
    }
}
