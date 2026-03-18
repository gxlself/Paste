//
//  EditItemSheet.swift
//  Paste-iOS
//

import SwiftUI

struct EditItemSheet: View {

    let item: SharedClipboardItem
    let onSave: (String) -> Void
    var onSaveRich: ((String, Data?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var attributedText: NSAttributedString = NSAttributedString()
    @State private var isRichMode = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isRichMode {
                    RichTextEditorWrapper(
                        attributedText: $attributedText,
                        plainText: $text
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    RichTextToolbar(
                        onBold: { NotificationCenter.default.post(name: .richTextToggleBold, object: nil) },
                        onItalic: { NotificationCenter.default.post(name: .richTextToggleItalic, object: nil) },
                        onUnderline: { NotificationCenter.default.post(name: .richTextToggleUnderline, object: nil) },
                        onFontSizeIncrease: { NotificationCenter.default.post(name: .richTextFontSizeUp, object: nil) },
                        onFontSizeDecrease: { NotificationCenter.default.post(name: .richTextFontSizeDown, object: nil) }
                    )
                } else {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                HStack {
                    Text(String(format: NSLocalizedString("ios.newText.charCount", comment: ""), text.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation { isRichMode.toggle() }
                    } label: {
                        Image(systemName: isRichMode ? "text.alignleft" : "textformat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Color(UIColor.systemFill).opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle(Text("ios.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "ios.edit.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "ios.edit.save")) {
                        if isRichMode, let onSaveRich {
                            let rtfData = try? attributedText.data(
                                from: NSRange(location: 0, length: attributedText.length),
                                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                            )
                            onSaveRich(text, rtfData)
                        } else {
                            onSave(text)
                        }
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            text = item.plainText ?? ""
            if let rtfData = item.rtfData,
               let attrStr = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
               ) {
                attributedText = attrStr
            } else {
                attributedText = NSAttributedString(
                    string: text,
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
            }
            isRichMode = (item.itemType == .text)
            isFocused = true
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - RichTextEditorWrapper with notification-based formatting

struct RichTextEditorWrapper: UIViewRepresentable {

    @Binding var attributedText: NSAttributedString
    @Binding var plainText: String

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditorWrapper
        var textView: UITextView?

        init(_ parent: RichTextEditorWrapper) {
            self.parent = parent
            super.init()

            NotificationCenter.default.addObserver(self, selector: #selector(toggleBold), name: .richTextToggleBold, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(toggleItalic), name: .richTextToggleItalic, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(toggleUnderline), name: .richTextToggleUnderline, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(fontSizeUp), name: .richTextFontSizeUp, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(fontSizeDown), name: .richTextFontSizeDown, object: nil)
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
            parent.plainText = textView.text
        }

        @objc func toggleBold() {
            guard let tv = textView else { return }
            RichTextFormatting.toggleBold(in: tv)
            parent.attributedText = tv.attributedText
            parent.plainText = tv.text
        }

        @objc func toggleItalic() {
            guard let tv = textView else { return }
            RichTextFormatting.toggleItalic(in: tv)
            parent.attributedText = tv.attributedText
            parent.plainText = tv.text
        }

        @objc func toggleUnderline() {
            guard let tv = textView else { return }
            RichTextFormatting.toggleUnderline(in: tv)
            parent.attributedText = tv.attributedText
            parent.plainText = tv.text
        }

        @objc func fontSizeUp() {
            guard let tv = textView else { return }
            RichTextFormatting.adjustFontSize(by: 2, in: tv)
            parent.attributedText = tv.attributedText
            parent.plainText = tv.text
        }

        @objc func fontSizeDown() {
            guard let tv = textView else { return }
            RichTextFormatting.adjustFontSize(by: -2, in: tv)
            parent.attributedText = tv.attributedText
            parent.plainText = tv.text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.allowsEditingTextAttributes = true
        tv.attributedText = attributedText
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        context.coordinator.textView = tv
        tv.becomeFirstResponder()
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {}
}

// MARK: - Notification names for rich text formatting

extension Notification.Name {
    static let richTextToggleBold = Notification.Name("richTextToggleBold")
    static let richTextToggleItalic = Notification.Name("richTextToggleItalic")
    static let richTextToggleUnderline = Notification.Name("richTextToggleUnderline")
    static let richTextFontSizeUp = Notification.Name("richTextFontSizeUp")
    static let richTextFontSizeDown = Notification.Name("richTextFontSizeDown")
}
