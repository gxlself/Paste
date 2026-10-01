//
//  PasteWidgetBundle.swift
//  Paste-Widget
//

import SwiftUI
import WidgetKit

@main
struct PasteWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            PasteLiveActivity()
        }
    }
}
