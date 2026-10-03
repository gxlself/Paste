//
//  PasteWidgetBundle.swift
//  Paste-Widget
//

import SwiftUI
import WidgetKit

@main
struct PasteWidgetBundle: WidgetBundle {
    var body: some Widget {
        // The extension's deployment target is iOS 16.1, the Live Activity minimum.
        PasteLiveActivity()
    }
}
