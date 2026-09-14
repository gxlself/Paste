#if PERFORMANCE_TESTING
import AppKit
import QuartzCore
import SwiftUI

@MainActor
enum PanelPerformanceMetrics {
    static var cardBodyCount = 0
}

@MainActor
enum PanelPerformanceHarness {
    static func run() async {
        let count = Int(ProcessInfo.processInfo.environment["PASTE_BENCHMARK_COUNT"] ?? "") ?? 6_000
        var fixtures: [ClipboardItemModel] = []
        for index in 0..<count {
            let type: ClipboardItemType = index % 5 == 0 ? .file : .text
            let paths: [String]? = type == .file ? ["/tmp/fixture-\(index).txt"] : nil
            let tags = index >= count - 3 ? ["pinboard:0"] : []
            fixtures.append(ClipboardItemModel(
                itemType: type,
                plainText: "Performance fixture \(index)\nSample clipboard text.",
                filePaths: paths,
                createdAt: Date(timeIntervalSince1970: 1_789_000_000 - Double(index)),
                tags: tags
            ))
        }
        let model = ClipboardViewModel(initialItems: fixtures)
        await model.waitForPendingFilters()
        let coordinator = PanelCoordinator(viewModel: model)
        coordinator.setupPanel { event in
            switch event.keyCode {
            case 48: model.selectNextFilterTab()
            case 53: coordinator.hideWithAnimation()
            default: return false
            }
            return true
        }
        let input = InputSourceCoordinator()
        var measurements: [[String: Any]] = []
        for iteration in 0..<8 {
            model.selectFilter(nil)
            await model.waitForPendingFilters()
            model.selectedIndex = 0
            try? await Task.sleep(for: .milliseconds(150))
            PanelPerformanceMetrics.cardBodyCount = 0
            let showStart = CACurrentMediaTime()
            coordinator.show(updatingInputSource: input)
            await flush(coordinator.panel)
            measurements.append([
                "action": "show", "iteration": iteration,
                "ms": (CACurrentMediaTime() - showStart) * 1_000,
                "cardBodies": PanelPerformanceMetrics.cardBodyCount
            ])
            if iteration == 1 { saveImage(coordinator.panel, name: "all") }
            try? await Task.sleep(for: .milliseconds(150))

            // Include sparse pinboards and the return to All, not just the first All -> Text.
            for step in 0..<(5 + AppSettings.pinboardCount) {
                PanelPerformanceMetrics.cardBodyCount = 0
                let filterStart = CACurrentMediaTime()
                model.selectNextFilterTab()
                await model.waitForPendingFilters()
                let filterMS = (CACurrentMediaTime() - filterStart) * 1_000
                await flush(coordinator.panel)
                measurements.append([
                    "action": "tab", "iteration": iteration, "step": step,
                    "filterMS": filterMS,
                    "ms": (CACurrentMediaTime() - filterStart) * 1_000,
                    "cardBodies": PanelPerformanceMetrics.cardBodyCount,
                    "items": model.displayItemCount, "selectedIndex": model.selectedIndex
                ])
                if iteration == 1, step == 0 { saveImage(coordinator.panel, name: "text") }
                try? await Task.sleep(for: .milliseconds(150))
            }

            let hideStart = CACurrentMediaTime()
            coordinator.hideWithAnimation()
            while coordinator.isVisible {
                try? await Task.sleep(for: .milliseconds(1))
            }
            measurements.append([
                "action": "escape", "iteration": iteration,
                "ms": (CACurrentMediaTime() - hideStart) * 1_000,
                "hidden": !coordinator.isVisible
            ])
            await flush(coordinator.panel)
        }
        if let data = try? JSONSerialization.data(withJSONObject: measurements, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print("PANEL_BENCHMARK \(json)")
        }
        NSApp.terminate(nil)
    }

    private static func saveImage(_ panel: NSPanel?, name: String) {
        guard let view = panel?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: "/tmp/paste-panel-benchmark-\(name).png"))
    }

    private static func flush(_ panel: NSPanel?) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                panel?.contentView?.layoutSubtreeIfNeeded()
                panel?.displayIfNeeded()
                CATransaction.flush()
                continuation.resume()
            }
        }
    }
}
#endif
