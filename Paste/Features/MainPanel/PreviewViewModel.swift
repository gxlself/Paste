//
//  PreviewViewModel.swift
//  Paste
//
//  Preview window ViewModel — manages preview content state
//

import Foundation
import AppKit
import Combine

@MainActor
class PreviewViewModel: ObservableObject {
    @Published var item: ClipboardItemModel?
    @Published var preset: RegexPreset?
    @Published var arrowOffset: CGFloat = 0
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var previewImageSizeInfo: String?

    func updateItem(_ newItem: ClipboardItemModel?) {
        item = newItem
        if newItem != nil { preset = nil }
        loadPreviewImage()
    }

    func updatePreset(_ newPreset: RegexPreset?) {
        preset = newPreset
        if newPreset != nil { item = nil }
        previewImage = nil
        previewImageSizeInfo = nil
    }

    func updateArrowOffset(_ offset: CGFloat) {
        arrowOffset = offset
    }

    private func loadPreviewImage() {
        guard let item, item.itemType == .image else {
            previewImage = nil
            previewImageSizeInfo = nil
            return
        }
        if let data = ThumbnailCache.loadImageData(for: item.id) {
            previewImage = NSImage(data: data)
            if let dims = ThumbnailCache.imageDimensions(from: data) {
                previewImageSizeInfo = "\(dims.width) × \(dims.height)"
            }
        } else {
            previewImage = nil
            previewImageSizeInfo = nil
        }
    }
}
