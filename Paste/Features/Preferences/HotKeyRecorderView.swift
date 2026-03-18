//
//  HotKeyRecorderView.swift
//  Paste
//
//  Simple hotkey recorder for macOS (SwiftUI).
//

import SwiftUI
import AppKit

struct HotKeyBinding: Equatable {
    var enabled: Bool
    var keyCode: UInt32
    var modifiers: UInt32
    
    static func disabled() -> HotKeyBinding {
        HotKeyBinding(enabled: false, keyCode: 0, modifiers: 0)
    }
}

struct HotKeyRecorderView: View {
    let title: LocalizedStringKey
    @Binding var binding: HotKeyBinding
    let onCommit: (HotKeyBinding) -> Void
    
    @State private var isRecording = false
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            
            HStack(spacing: 8) {
                ZStack {
                    if isRecording {
                        Text("preferences.shortcuts.recording")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(displayString(binding))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(binding.enabled ? .primary : .secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    isRecording.toggle()
                }
                .background(
                    KeyCaptureRepresentable(isActive: $isRecording) { newKeyCode, newModifiers in
                        var updated = binding
                        updated.enabled = true
                        updated.keyCode = newKeyCode
                        updated.modifiers = newModifiers
                        binding = updated
                        onCommit(updated)
                        isRecording = false
                    }
                )
                
                Button {
                    let disabled = HotKeyBinding.disabled()
                    binding = disabled
                    onCommit(disabled)
                    isRecording = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("preferences.shortcuts.clear"))
            }
        }
    }
    
    private func displayString(_ binding: HotKeyBinding) -> String {
        guard binding.enabled, binding.keyCode != 0 else { return "—" }
        return HotKeyManager.shared.displayString(keyCode: binding.keyCode, modifiers: binding.modifiers)
    }
}

private struct KeyCaptureRepresentable: NSViewRepresentable {
    @Binding var isActive: Bool
    let onCapture: (UInt32, UInt32) -> Void
    
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onCapture = onCapture
        view.onEscape = {
            isActive = false
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.isActive = isActive
        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class KeyCaptureView: NSView {
    var isActive: Bool = false
    var onCapture: ((UInt32, UInt32) -> Void)?
    var onEscape: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isActive else {
            super.keyDown(with: event)
            return
        }
        
        // Esc cancels
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        
        // Ignore if only modifier keys (keyCode 55/56 etc). We require an actual key.
        let keyCode = UInt32(event.keyCode)
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let modifiersRaw = UInt32(mods.rawValue)
        
        // Require at least one modifier to reduce conflicts with normal typing.
        guard !mods.isEmpty else { return }
        
        onCapture?(keyCode, modifiersRaw)
    }
}

