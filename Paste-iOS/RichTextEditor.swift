//
//  RichTextEditor.swift
//  Paste-iOS
//

import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {

    @Binding var attributedText: NSAttributedString
    @Binding var plainText: String

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
            parent.plainText = textView.text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.allowsEditingTextAttributes = true
        textView.attributedText = attributedText
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.becomeFirstResponder()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {}
}

// MARK: - Formatting Toolbar

struct RichTextToolbar: View {

    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onFontSizeIncrease: () -> Void
    let onFontSizeDecrease: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                toolButton(label: "B", font: .body.bold()) { onBold() }
                toolButton(label: "I", font: .body.italic()) { onItalic() }
                toolButton(label: "U") { onUnderline() }

                Divider().frame(height: 20)

                Button(action: onFontSizeDecrease) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 16))
                }
                Button(action: onFontSizeIncrease) {
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
        .background(.regularMaterial)
    }

    private func toolButton(label: String, font: Font = .body, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .frame(width: 32, height: 32)
                .background(Color(UIColor.systemFill).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rich text formatting helpers

enum RichTextFormatting {

    static func toggleBold(in textView: UITextView) {
        toggleTrait(.traitBold, in: textView)
    }

    static func toggleItalic(in textView: UITextView) {
        toggleTrait(.traitItalic, in: textView)
    }

    static func toggleUnderline(in textView: UITextView) {
        guard textView.selectedRange.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let range = textView.selectedRange
        var hasUnderline = false
        mutable.enumerateAttribute(.underlineStyle, in: range) { val, _, _ in
            if let style = val as? Int, style != 0 { hasUnderline = true }
        }
        let newStyle: NSUnderlineStyle = hasUnderline ? [] : .single
        mutable.addAttribute(.underlineStyle, value: newStyle.rawValue, range: range)
        textView.attributedText = mutable
        textView.selectedRange = range
    }

    static func adjustFontSize(by delta: CGFloat, in textView: UITextView) {
        guard textView.selectedRange.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let range = textView.selectedRange
        mutable.enumerateAttribute(.font, in: range) { val, subRange, _ in
            if let font = val as? UIFont {
                let newSize = max(10, min(72, font.pointSize + delta))
                let newFont = font.withSize(newSize)
                mutable.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        textView.attributedText = mutable
        textView.selectedRange = range
    }

    private static func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in textView: UITextView) {
        guard textView.selectedRange.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let range = textView.selectedRange
        mutable.enumerateAttribute(.font, in: range) { val, subRange, _ in
            guard let font = val as? UIFont else { return }
            let descriptor = font.fontDescriptor
            let hasTrait = descriptor.symbolicTraits.contains(trait)
            if hasTrait {
                if let newDescriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.subtracting(trait)) {
                    mutable.addAttribute(.font, value: UIFont(descriptor: newDescriptor, size: font.pointSize), range: subRange)
                }
            } else {
                if let newDescriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(trait)) {
                    mutable.addAttribute(.font, value: UIFont(descriptor: newDescriptor, size: font.pointSize), range: subRange)
                }
            }
        }
        textView.attributedText = mutable
        textView.selectedRange = range
    }
}
