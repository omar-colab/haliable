//
//  LiveTextScanner.swift
//  Haliable
//
//  Apple's live text scanner (VisionKit `DataScannerViewController`, UIKit):
//  highlights text on the pack as you point at it, pinch to zoom, on-device.
//  Bumping `captureToken` hands back what's in view, top to bottom. Devices
//  without it (pre-A12, simulator) fall back to a photo (LabelTextReader).
//

import SwiftUI
import VisionKit

struct LiveTextScanner: UIViewControllerRepresentable {
    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    let captureToken: Int
    let onCapture: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate,
                                           recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false,
                                           isPinchToZoomEnabled: true, isGuidanceEnabled: true,
                                           isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if !vc.isScanning { try? vc.startScanning() }
        if captureToken != context.coordinator.lastToken {
            context.coordinator.lastToken = captureToken
            onCapture(context.coordinator.text())
        }
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        vc.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(lastToken: captureToken) }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var lastToken: Int
        private var items: [RecognizedItem] = []
        init(lastToken: Int) { self.lastToken = lastToken }

        func dataScanner(_ s: DataScannerViewController, didAdd a: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }
        func dataScanner(_ s: DataScannerViewController, didUpdate u: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }
        func dataScanner(_ s: DataScannerViewController, didRemove r: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }

        /// Lines in reading order: top to bottom, left to right within a row.
        func text() -> String {
            let lines = items.compactMap { item -> (y: CGFloat, x: CGFloat, text: String)? in
                guard case .text(let t) = item else { return nil }
                return (t.bounds.topLeft.y, t.bounds.topLeft.x, t.transcript)
            }
            return lines.sorted { abs($0.y - $1.y) > 8 ? $0.y < $1.y : $0.x < $1.x }
                .map(\.text).joined(separator: "\n")
        }
    }
}
