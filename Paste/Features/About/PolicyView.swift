//
//  PolicyView.swift
//  Paste
//
//  Displays Privacy Policy / Terms of Use
//

import SwiftUI

struct PolicyView: View {

    let document: PolicyDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(document.windowTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Divider()

            ScrollView {
                Text(document.content)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 720)
    }
}

