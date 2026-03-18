//
//  DocumentScannerView.swift
//  Paste-iOS
//

import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {

    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, dismiss: dismiss)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (String) -> Void
        let dismiss: DismissAction

        init(onScan: @escaping (String) -> Void, dismiss: DismissAction) {
            self.onScan = onScan
            self.dismiss = dismiss
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var fullText = ""
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                if let text = recognizeText(in: image) {
                    if !fullText.isEmpty { fullText += "\n\n" }
                    fullText += text
                }
            }
            if !fullText.isEmpty {
                onScan(fullText)
            }
            dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            dismiss()
        }

        private func recognizeText(in image: UIImage) -> String? {
            guard let cgImage = image.cgImage else { return nil }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            let observations = request.results ?? []
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }
    }
}

import Vision
