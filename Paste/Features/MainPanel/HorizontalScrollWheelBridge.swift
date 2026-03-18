import SwiftUI
import AppKit

/// Maps vertical scroll wheel / trackpad events to horizontal scroll.
///
/// On macOS, scroll wheel vertical delta normally does not drive a horizontal ScrollView; this bridge fixes that.
struct HorizontalScrollWheelBridge<Content: View>: NSViewRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ScrollWheelBridgeContainerView {
        let container = ScrollWheelBridgeContainerView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        container.hostingView = hostingView
        context.coordinator.hostingView = hostingView
        return container
    }

    func updateNSView(_ nsView: ScrollWheelBridgeContainerView, context: Context) {
        if let hostingView = context.coordinator.hostingView {
            hostingView.rootView = content
            nsView.hostingView = hostingView
        }
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
    }
}

final class ScrollWheelBridgeContainerView: NSView {
    weak var hostingView: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // SwiftUI's internal NSScrollView may consume scroll wheel events even when it does not handle vertical scroll,
        // preventing the outer container from receiving scrollWheel. This makes the container the hit target only for scrollWheel,
        // so deltaY can be mapped to horizontal scroll. Other events use the default hit-test to preserve click/drag behaviour.
        if NSApp.currentEvent?.type == .scrollWheel {
            return self
        }
        return super.hitTest(point)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let scrollView = findNearestScrollView() else {
            super.scrollWheel(with: event)
            return
        }

        // Trackpad horizontal swipe: pass deltaX directly. Vertical scroll: remap deltaY to horizontal.
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 12.0
        let deltaX: CGFloat
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            deltaX = event.scrollingDeltaX * multiplier
        } else {
            deltaX = event.scrollingDeltaY * multiplier
        }

        let clipView = scrollView.contentView
        var newOrigin = clipView.bounds.origin
        newOrigin.x -= deltaX

        // Clamp to valid range to prevent out-of-bounds jitter.
        let minX: CGFloat = 0
        let maxX: CGFloat
        if let documentView = scrollView.documentView {
            maxX = max(0, documentView.bounds.width - clipView.bounds.width)
        } else {
            maxX = minX
        }

        newOrigin.x = min(max(newOrigin.x, minX), maxX)

        clipView.scroll(to: newOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }

    private func findNearestScrollView() -> NSScrollView? {
        // SwiftUI's ScrollView(.horizontal) typically creates an NSScrollView somewhere in the view hierarchy.
        // Recursively search the hostingView subtree for the first NSScrollView; skip if not found.
        let root: NSView = (hostingView as? NSView) ?? self
        return findScrollView(in: root)
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) { return found }
        }
        return nil
    }
}
