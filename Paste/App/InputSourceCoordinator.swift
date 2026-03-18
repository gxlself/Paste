//
//  InputSourceCoordinator.swift
//  Paste
//
//  Manages Carbon TIS input source queries and cycling.
//  Pure stateless coordinator — no stored state, no side effects beyond TISSelectInputSource.
//

import Carbon

final class InputSourceCoordinator {

    // MARK: - Query

    /// Returns the current keyboard input source's (id, localizedName), or nil if unavailable.
    func currentInfo() -> (id: String, name: String)? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        let id   = stringProperty(source, kTISPropertyInputSourceID) ?? ""
        let name = stringProperty(source, kTISPropertyLocalizedName) ?? ""
        return (id, name)
    }

    // MARK: - Action

    /// Cycles to the next enabled keyboard input source (wraps around).
    func selectNext() {
        let sources = enabledSources()
        guard !sources.isEmpty else { return }
        let currentId  = currentInfo()?.id
        let currentIdx = sources.firstIndex { stringProperty($0, kTISPropertyInputSourceID) == currentId } ?? 0
        TISSelectInputSource(sources[(currentIdx + 1) % sources.count])
    }

    // MARK: - Helpers

    private func enabledSources() -> [TISInputSource] {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        return list.filter {
            stringProperty($0, kTISPropertyInputSourceCategory) == (kTISCategoryKeyboardInputSource as String)
                && boolProperty($0, kTISPropertyInputSourceIsEnabled)
        }
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }

    private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
    }
}
