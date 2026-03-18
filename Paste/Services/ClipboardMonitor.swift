//
//  ClipboardMonitor.swift
//  Paste
//
//  Clipboard monitor: polls for pasteboard changes
//

import Foundation
import AppKit

class ClipboardMonitor {
    
    static let shared = ClipboardMonitor()
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isMonitoring = false
    
    /// Indicates whether clipboard monitoring is currently active.
    var isMonitoringActive: Bool {
        return isMonitoring
    }
    
    /// Hash of content written by this app, used to prevent circular recording.
    private(set) var selfWriteHash: String?
    
    private let pasteboardHelper = PasteboardHelper.shared
    private let clipboardService = ClipboardService.shared
    
    private init() {
        lastChangeCount = pasteboardHelper.changeCount
    }
    
    // MARK: - Public Methods
    
    /// Starts clipboard polling.
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        lastChangeCount = pasteboardHelper.changeCount
        
        // Use a RunLoop-based timer for polling.
        timer = Timer.scheduledTimer(
            withTimeInterval: Constants.clipboardPollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }
        
        // Ensure the timer fires in .common mode (e.g. during menu tracking).
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Stops clipboard polling.
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Marks the hash of content this app is about to write, preventing it from being re-recorded.
    func markSelfWrite(hash: String) {
        selfWriteHash = hash
        
        // Clear the mark after 1 second to avoid permanently ignoring future copies.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if self?.selfWriteHash == hash {
                self?.selfWriteHash = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkClipboard() {
        let currentCount = pasteboardHelper.changeCount
        
        // Skip if the pasteboard has not changed.
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // Read the current pasteboard content.
        guard let content = pasteboardHelper.readContent(), !content.isEmpty else { return }
        
        // Skip if this content was written by the app itself.
        if content.contentHash == selfWriteHash {
            return
        }

        // Apply content rules: skip sensitive or auto-generated content.
        if ContentRules.shouldIgnore(content: content) {
            return
        }
        
        // Skip if the source app is on the user exclusion list.
        if let sourceApp = content.sourceApp, isAppExcluded(sourceApp) {
            return
        }
        
        // Skip images if image recording is disabled.
        if content.type == .image && !shouldRecordImages() {
            return
        }
        
        // Persist the item.
        clipboardService.saveItem(content)
    }
    
    /// Returns true if the given bundle ID is on the user's exclusion list.
    private func isAppExcluded(_ bundleId: String) -> Bool {
        AppSettings.excludedApps.contains(bundleId)
    }
    
    /// Returns whether image items should be recorded.
    private func shouldRecordImages() -> Bool {
        AppSettings.recordImages
    }
}
