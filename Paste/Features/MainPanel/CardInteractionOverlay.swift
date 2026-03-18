//
//  CardInteractionOverlay.swift
//  Paste
//
//  NSView-based mouse-event overlay.
//
//  Handles mouseDown/mouseDragged/mouseUp directly in AppKit, bypassing the SwiftUI gesture system
//  to fix DragGesture being intercepted by the horizontal ScrollView's scroll recogniser.
//

import SwiftUI
import AppKit

// MARK: - NSViewRepresentable

struct CardInteractionOverlay: NSViewRepresentable {
    @Binding var isHovered: Bool
    @Binding var isDragging: Bool
    let onTap: () -> Void
    let onDragBegan: () -> Void
    let onDragEnded: (NSPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isHovered: $isHovered,
            isDragging: $isDragging,
            onTap: onTap,
            onDragBegan: onDragBegan,
            onDragEnded: onDragEnded
        )
    }

    func makeNSView(context: Context) -> CardMouseView {
        let view = CardMouseView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: CardMouseView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onDragBegan = onDragBegan
        context.coordinator.onDragEnded = onDragEnded
    }

    // MARK: - Coordinator

    final class Coordinator {
        @Binding var isHovered: Bool
        @Binding var isDragging: Bool
        var onTap: () -> Void
        var onDragBegan: () -> Void
        var onDragEnded: (NSPoint) -> Void

        init(
            isHovered: Binding<Bool>,
            isDragging: Binding<Bool>,
            onTap: @escaping () -> Void,
            onDragBegan: @escaping () -> Void,
            onDragEnded: @escaping (NSPoint) -> Void
        ) {
            self._isHovered = isHovered
            self._isDragging = isDragging
            self.onTap = onTap
            self.onDragBegan = onDragBegan
            self.onDragEnded = onDragEnded
        }
    }
}

// MARK: - CardMouseView

final class CardMouseView: NSView {
    weak var coordinator: CardInteractionOverlay.Coordinator?

    private var mouseDownScreenLocation: NSPoint?
    private var activeDrag = false
    private let dragThreshold: CGFloat = 6
    private var trackingArea: NSTrackingArea?

    // Accept the first click directly (the panel is nonactivatingPanel; the first click does not activate the app).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var acceptsFirstResponder: Bool { false }

    // MARK: Tracking area (hover)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        DispatchQueue.main.async { [weak self] in self?.coordinator?.isHovered = true }
    }

    override func mouseExited(with event: NSEvent) {
        DispatchQueue.main.async { [weak self] in self?.coordinator?.isHovered = false }
    }

    // MARK: Mouse events

    override func mouseDown(with event: NSEvent) {
        mouseDownScreenLocation = NSEvent.mouseLocation
        activeDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = mouseDownScreenLocation else { return }
        let current = NSEvent.mouseLocation
        let distance = hypot(current.x - origin.x, current.y - origin.y)

        if !activeDrag, distance > dragThreshold {
            activeDrag = true
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.isDragging = true
                self?.coordinator?.onDragBegan()
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if activeDrag {
            let releaseLocation = NSEvent.mouseLocation
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.isDragging = false
                self?.coordinator?.onDragEnded(releaseLocation)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.onTap()
            }
        }
        mouseDownScreenLocation = nil
        activeDrag = false
    }
}
