//
//  HotKeyManager.swift
//  Paste
//
//  Global hotkey management using the Carbon API
//

import AppKit
import Carbon

class HotKeyManager {
    
    static let shared = HotKeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [HotKeyAction: EventHotKeyRef] = [:]
    private var handlers: [HotKeyAction: () -> Void] = [:]
    
    private init() {
        installEventHandler()
    }
    
    deinit {
        unregisterAll()
    }
    
    enum HotKeyAction: UInt32, CaseIterable {
        case paste = 1
        case pasteStack = 2
        case nextPinboard = 3
        case previousPinboard = 4
    }
    
    // MARK: - Public Methods
    
    /// Registers (or updates) all hotkeys from the current AppSettings values.
    func registerAll(handlers: [HotKeyAction: () -> Void]) {
        for (action, handler) in handlers {
            setHandler(action: action, handler: handler)
        }
        for action in HotKeyAction.allCases {
            registerActionFromSettings(action)
        }
    }
    
    func setHandler(action: HotKeyAction, handler: @escaping () -> Void) {
        self.handlers[action] = handler
    }
    
    /// Updates the hotkey for a single action (called after recording in Preferences).
    func updateHotKey(action: HotKeyAction, enabled: Bool, keyCode: UInt32, modifiers: UInt32) {
        // Unregister any existing hotkey for this action first.
        unregister(action: action)
        
        guard enabled else { return }
        guard keyCode != 0 else { return }
        
        let carbonModifiers = toCarbonModifiers(modifiers: modifiers)
        
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: action.rawValue)
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        // Check whether registration succeeded.
        if status != noErr {
            print("⚠️ Hotkey registration failed, error code: \(status)")
            print("   Accessibility permission may be required. Grant it in System Settings → Privacy & Security → Accessibility.")
        } else {
            print("✅ Hotkey registered: \(displayString(keyCode: keyCode, modifiers: modifiers))")
            if let hotKeyRef {
                hotKeyRefs[action] = hotKeyRef
            }
        }
    }
    
    func unregisterAll() {
        for action in HotKeyAction.allCases {
            unregister(action: action)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    func unregister(action: HotKeyAction) {
        if let ref = hotKeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotKeyRefs[action] = nil
        }
    }
    
    /// Returns the display string for the hotkey currently assigned to an action.
    func currentHotKeyDisplayString(action: HotKeyAction = .paste) -> String {
        let (enabled, keyCode, modifiers) = bindingFromSettings(action)
        guard enabled, keyCode != 0 else { return "—" }
        return displayString(keyCode: keyCode, modifiers: modifiers)
    }
    
    /// Converts a key code and modifier flags into a human-readable shortcut string.
    func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var result = ""
        
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 {
            result += "⌃"
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 {
            result += "⌥"
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            result += "⇧"
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 {
            result += "⌘"
        }
        
        result += keyCodeToString(keyCode)
        
        return result
    }
    
    // MARK: - Private Methods
    
    private let signature: OSType = OSType(0x5054_4F4C) // "PTOL"
    
    private func installEventHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == manager.signature else { return OSStatus(eventNotHandledErr) }
            guard let action = HotKeyAction(rawValue: hotKeyID.id) else { return OSStatus(eventNotHandledErr) }
            
            DispatchQueue.main.async {
                manager.handlers[action]?()
            }
            return noErr
        }
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, userData, &eventHandler)
    }
    
    private func toCarbonModifiers(modifiers: UInt32) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 {
            carbonModifiers |= UInt32(controlKey)
        }
        return carbonModifiers
    }
    
    private func registerActionFromSettings(_ action: HotKeyAction) {
        let (enabled, keyCode, modifiers) = bindingFromSettings(action)
        updateHotKey(action: action, enabled: enabled, keyCode: keyCode, modifiers: modifiers)
    }
    
    private func bindingFromSettings(_ action: HotKeyAction) -> (Bool, UInt32, UInt32) {
        switch action {
        case .paste:
            return (AppSettings.hotKeyPasteEnabled, AppSettings.hotKeyPasteKeyCode, AppSettings.hotKeyPasteModifiers)
        case .pasteStack:
            return (AppSettings.hotKeyPasteStackEnabled, AppSettings.hotKeyPasteStackKeyCode, AppSettings.hotKeyPasteStackModifiers)
        case .nextPinboard:
            return (AppSettings.hotKeyNextPinboardEnabled, AppSettings.hotKeyNextPinboardKeyCode, AppSettings.hotKeyNextPinboardModifiers)
        case .previousPinboard:
            return (AppSettings.hotKeyPrevPinboardEnabled, AppSettings.hotKeyPrevPinboardKeyCode, AppSettings.hotKeyPrevPinboardModifiers)
        }
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "B", 11: "N", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return keyMap[keyCode] ?? "?"
    }
}
