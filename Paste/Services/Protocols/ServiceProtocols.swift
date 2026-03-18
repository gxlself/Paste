//
//  ServiceProtocols.swift
//  Paste
//
//  Protocol interfaces for the five macOS service singletons.
//  Abstracting behind protocols enables dependency injection and unit testing
//  without touching any production code paths.
//

import Foundation
import AppKit

// MARK: - ClipboardServiceProtocol

protocol ClipboardServiceProtocol: AnyObject {
    // Create
    func saveItem(_ content: ClipboardContent)
    // Read
    func fetchAllItems() -> [ClipboardItemModel]
    func fetchItemWithFullData(id: UUID) -> ClipboardItemModel?
    func searchItems(keyword: String, type: ClipboardItemType?) -> [ClipboardItemModel]
    func filterByApp(_ bundleId: String) -> [ClipboardItemModel]
    // Update
    func togglePin(id: UUID)
    func updateTags(id: UUID, tags: [String])
    func updatePlainText(id: UUID, newText: String)
    // Pinboard
    func isInAnyPinboard(_ item: ClipboardItemModel) -> Bool
    func isInPinboard(_ item: ClipboardItemModel, index: Int) -> Bool
    func setPinboard(id: UUID, index: Int, enabled: Bool)
    func moveToPinboard(id: UUID, index: Int)
    // Delete
    func deleteItem(id: UUID)
    func deleteAllItems()
    func deleteAllItems(ofType type: ClipboardItemType)
    func restoreItem(_ model: ClipboardItemModel)
    // Paste / Copy
    func pasteItem(_ item: ClipboardItemModel, simulatePaste: Bool, plainTextOnly: Bool)
    func copyItem(_ item: ClipboardItemModel, plainTextOnly: Bool)
    func copyPlainTextToClipboard(_ string: String)
}

// MARK: - ClipboardMonitorProtocol

protocol ClipboardMonitorProtocol: AnyObject {
    var isMonitoringActive: Bool { get }
    var selfWriteHash: String? { get }
    func startMonitoring()
    func stopMonitoring()
    func markSelfWrite(hash: String)
}

// MARK: - PasteboardHelperProtocol

protocol PasteboardHelperProtocol: AnyObject {
    var changeCount: Int { get }
    func readContent() -> ClipboardContent?
    func readPlainText() -> String?
    func readRTFData() -> Data?
    func readImageData() -> Data?
    func readFilePaths() -> [String]?
    func getSourceApplication() -> String?
    func writeText(_ text: String, rtfData: Data?)
    func writeImage(_ imageData: Data)
    func writeFilePaths(_ paths: [String])
    func writeItem(_ item: ClipboardItemModel, plainTextOnly: Bool)
    @discardableResult func simulatePaste() -> Bool
}

// MARK: - HotKeyManagerProtocol

protocol HotKeyManagerProtocol: AnyObject {
    func registerAll(handlers: [HotKeyManager.HotKeyAction: () -> Void])
    func setHandler(action: HotKeyManager.HotKeyAction, handler: @escaping () -> Void)
    func updateHotKey(action: HotKeyManager.HotKeyAction, enabled: Bool, keyCode: UInt32, modifiers: UInt32)
    func unregisterAll()
    func unregister(action: HotKeyManager.HotKeyAction)
    func currentHotKeyDisplayString(action: HotKeyManager.HotKeyAction) -> String
    func displayString(keyCode: UInt32, modifiers: UInt32) -> String
}

// MARK: - PasteStackServiceProtocol

protocol PasteStackServiceProtocol: AnyObject {
    func fetchEntries() -> [PasteStackService.Entry]
    func push(itemId: UUID)
    func remove(entryId: UUID)
    func removeTopEntry(for itemId: UUID)
    func clear()
}

// MARK: - Protocol conformances

extension ClipboardService:  ClipboardServiceProtocol  {}
extension ClipboardMonitor:  ClipboardMonitorProtocol  {}
extension PasteboardHelper:  PasteboardHelperProtocol  {}
extension HotKeyManager:     HotKeyManagerProtocol     {}
extension PasteStackService: PasteStackServiceProtocol {}
