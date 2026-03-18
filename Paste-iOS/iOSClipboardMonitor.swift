// iOSClipboardMonitor.swift
// Paste-iOS

import UIKit

final class iOSClipboardMonitor {

    private var timer: Timer?
    private var lastChangeCount: Int
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.lastChangeCount = UIPasteboard.general.changeCount
        self.onChange = onChange
    }

    func startMonitoring() {
        timer?.invalidate()
        lastChangeCount = UIPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let current = UIPasteboard.general.changeCount
            if current != self.lastChangeCount {
                self.lastChangeCount = current
                DispatchQueue.main.async { self.onChange() }
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopMonitoring()
    }
}
