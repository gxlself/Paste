//
//  NewTextItemSheet.swift
//  Paste-iOS
//

import SwiftUI

struct NewTextItemSheet: View {

    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Divider()

                HStack {
                    Text(String(format: NSLocalizedString("ios.newText.charCount", comment: ""), text.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle(Text("ios.newText.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "ios.newText.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "ios.newText.create")) {
                        onCreate(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { isFocused = true }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
