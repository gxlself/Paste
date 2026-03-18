// KeyboardViewModel.swift
// Paste-Keyboard

import Foundation
import Combine
import CoreData
import UIKit
import ImageIO

final class KeyboardViewModel: ObservableObject {

    @Published var items: [SharedClipboardItem] = []
    @Published var searchText = ""
    @Published var activeTypeFilter: ClipboardItemType?

    private let stack = SharedCoreDataStack.shared

    var filterLabel: String {
        switch activeTypeFilter {
        case nil:    return String(localized: "mainpanel.filter.all")
        case .text:  return String(localized: "mainpanel.filter.text")
        case .image: return String(localized: "mainpanel.filter.image")
        case .file:  return String(localized: "mainpanel.filter.file")
        }
    }

    var filterIcon: String {
        switch activeTypeFilter {
        case nil:    return "square.grid.2x2"
        case .text:  return "doc.text"
        case .image: return "photo"
        case .file:  return "folder"
        }
    }

    var filteredItems: [SharedClipboardItem] {
        var result = items

        if let type = activeTypeFilter {
            result = result.filter { $0.itemType == type }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.displayText.lowercased().contains(query) }
        }

        return result
    }

    func fetchItems() {
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt, ascending: false)
        ]
        request.fetchLimit = 100
        request.fetchBatchSize = 20
        do {
            let entities = try ctx.fetch(request)
            items = entities.map { SharedClipboardItem(entity: $0, loadBinaryData: false) }
        } catch {
            print("Keyboard fetch error: \(error)")
        }
    }

    // MARK: - Write operations

    func copyToClipboard(_ item: SharedClipboardItem) {
        let pb = UIPasteboard.general
        switch item.itemType {
        case .text:  pb.string = item.plainText
        case .image:
            if let data = SharedThumbnailCache.loadImageData(for: item.id),
               let img = Self.downsampleForPaste(data: data) {
                pb.image = img
            }
        case .file:  pb.string = item.displayText
        }
    }

    private static func downsampleForPaste(data: Data, maxPixelSize: CGFloat = 1024) -> UIImage? {
        let sourceOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOpts as CFDictionary) else {
            return nil
        }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }

    func deleteItem(_ item: SharedClipboardItem) {
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        if let entity = try? ctx.fetch(request).first {
            ctx.delete(entity)
            stack.save()
            fetchItems()
        }
    }

    func togglePin(_ item: SharedClipboardItem) {
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        if let entity = try? ctx.fetch(request).first {
            entity.isPinned.toggle()
            stack.save()
            fetchItems()
        }
    }

    func openInApp(_ item: SharedClipboardItem, action: String) {
        guard let url = URL(string: "pasteg://\(action)?id=\(item.id.uuidString)") else { return }
        var responder: UIResponder? = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIResponder
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url)
                return
            }
            responder = r.next
        }
    }

    private func decodeTags(_ data: Data?) -> [String]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
}
