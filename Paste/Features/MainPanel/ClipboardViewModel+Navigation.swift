//
//  ClipboardViewModel+Navigation.swift
//  Paste
//
//  Keyboard navigation and multi-selection.
//

import Foundation
import Combine
import AppKit
import CoreData

@MainActor
extension ClipboardViewModel {
    // MARK: - Navigation
    
    func selectPrevious() {
        selectedIndices = []
        selectionAnchor = nil
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
        selectionAnchor = selectedIndex
    }

    func selectNext() {
        selectedIndices = []
        selectionAnchor = nil
        let count = displayItemCount
        if selectedIndex < count - 1 {
            selectedIndex += 1
        }
        selectionAnchor = selectedIndex
    }

    func selectFirst() {
        selectedIndices = []
        selectionAnchor = nil
        selectedIndex = 0
        selectionAnchor = 0
    }

    func selectLast() {
        selectedIndices = []
        selectionAnchor = nil
        selectedIndex = max(0, displayItemCount - 1)
        selectionAnchor = selectedIndex
    }

    func selectAll() {
        let count = displayItemCount
        guard count > 0 else { return }
        selectedIndices = Set(0..<count)
        selectionAnchor = 0
        selectedIndex = 0
    }

    /// Closed range from a to b that is always valid (lowerBound <= upperBound).
    func selectionRange(from a: Int, to b: Int) -> ClosedRange<Int> {
        min(a, b)...max(a, b)
    }

    func extendSelection(left: Bool) {
        let count = displayItemCount
        guard count > 0 else { return }
        let anchor = selectionAnchor ?? selectedIndex
        if left {
            if selectedIndices.count > 1 {
                guard let rightmost = selectedIndices.max() else { return }
                selectedIndices.remove(rightmost)
                selectedIndex = selectedIndices.max() ?? max(0, rightmost - 1)
                if selectedIndices.isEmpty {
                    selectionAnchor = selectedIndex
                } else if selectedIndices.count == 1, selectedIndex > 0 {
                    selectedIndex -= 1
                    selectedIndices.insert(selectedIndex)
                }
            } else if selectedIndex > 0 {
                selectedIndex -= 1
                selectedIndices = selectedIndices.union(Set(selectionRange(from: selectedIndex, to: anchor)))
            }
        } else {
            if selectedIndex < count - 1 {
                selectedIndex += 1
                selectedIndices = selectedIndices.union(Set(selectionRange(from: anchor, to: selectedIndex)))
            } else if selectedIndices.count > 1 {
                guard let leftmost = selectedIndices.min() else { return }
                selectedIndices.remove(leftmost)
                selectedIndex = selectedIndices.min() ?? selectedIndex
                if selectedIndices.isEmpty {
                    selectionAnchor = selectedIndex
                } else if selectedIndices.count == 1, selectedIndex < count - 1 {
                    selectedIndex += 1
                    selectedIndices.insert(selectedIndex)
                }
            }
        }
    }
    
    /// Returns the currently selected item (valid only in history mode).
    var selectedItem: ClipboardItemModel? {
        guard filteredItems.indices.contains(selectedIndex) else { return nil }
        return filteredItems[selectedIndex]
    }
}
