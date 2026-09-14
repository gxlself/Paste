import AppKit
import SwiftUI

/// Observe the existing SwiftUI scroll view without nesting a second NSHostingView.
struct HorizontalScrollWheelBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> HorizontalWheelMonitorView { HorizontalWheelMonitorView() }
    func updateNSView(_ nsView: HorizontalWheelMonitorView, context: Context) {}
    static func dismantleNSView(_ nsView: HorizontalWheelMonitorView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

final class HorizontalWheelMonitorView: NSView {
    private weak var scrollView: NSScrollView?
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let window = self.window, window.isVisible,
                  event.window === window, !self.isHiddenOrHasHiddenAncestor,
                  self.bounds.contains(self.convert(event.locationInWindow, from: nil)),
                  abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return event }
            return self.scrollHorizontally(event) ? nil : event
        }
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        scrollView = nil
    }

    private func scrollHorizontally(_ event: NSEvent) -> Bool {
        if scrollView?.window !== window { scrollView = nil }
        if scrollView == nil {
            var ancestor = superview
            while let view = ancestor {
                if let match = findScrollView(in: view) {
                    scrollView = match
                    break
                }
                ancestor = view.superview
            }
        }
        guard let scrollView else { return false }
        let clip = scrollView.contentView
        var origin = clip.bounds.origin
        origin.x -= event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 12)
        let maximum = max(0, (scrollView.documentView?.bounds.width ?? 0) - clip.bounds.width)
        origin.x = min(maximum, max(0, origin.x))
        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
        return true
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        for child in view.subviews {
            if let scroll = findScrollView(in: child) { return scroll }
        }
        return nil
    }
}
