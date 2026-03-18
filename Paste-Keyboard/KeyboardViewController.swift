//
//  KeyboardViewController.swift
//  Paste-Keyboard
//
//
//  Copyright © 2026 Gxlself. All rights reserved.
//

import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardGridView>?
    private let viewModel = KeyboardViewModel()

    private let keyboardHeight: CGFloat = 310

    override func viewDidLoad() {
        super.viewDidLoad()

        let gridView = KeyboardGridView(
            viewModel: viewModel,
            onInsertText: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onDeleteBackward: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            onReturnKey: { [weak self] in
                self?.textDocumentProxy.insertText("\n")
            }
        )

        let hc = UIHostingController(rootView: gridView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        hc.sizingOptions = .intrinsicContentSize

        addChild(hc)
        view.addSubview(hc.view)
        hc.didMove(toParent: self)

        let heightConstraint = hc.view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint.priority = .required

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heightConstraint
        ])

        hostingController = hc
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.fetchItems()
    }

    override func textWillChange(_ textInput: UITextInput?) {
    }

    override func textDidChange(_ textInput: UITextInput?) {
    }
}
