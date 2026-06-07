//
//  BarcodeScannerView.swift
//  Haliable
//
//  A dependency-free barcode scanner built directly on AVFoundation.
//  Replaces the previous third-party CodeScanner package.
//
//  Note: the iOS Simulator has no camera, so this shows a "camera
//  unavailable" message there. Use a physical device, or the manual
//  barcode entry on ScannerView, to test the full flow.
//

import SwiftUI
import AVFoundation
import AudioToolbox

struct BarcodeScannerView: UIViewControllerRepresentable {
    /// Called once with the first barcode string found. The parent dismisses.
    let onFound: (String) -> Void
    /// Called if the camera can't be used (no permission / no hardware).
    var onError: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        private let parent: BarcodeScannerView
        private var didFind = false
        init(_ parent: BarcodeScannerView) { self.parent = parent }

        func scanner(_ controller: ScannerViewController, didFind code: String) {
            guard !didFind else { return }   // ignore the rapid repeat callbacks
            didFind = true
            parent.onFound(code)
        }
        func scanner(_ controller: ScannerViewController, didFailWith message: String) {
            parent.onError?(message)
        }
    }
}

// MARK: - The UIKit controller that owns the capture session

protocol ScannerViewControllerDelegate: AnyObject {
    func scanner(_ controller: ScannerViewController, didFind code: String)
    func scanner(_ controller: ScannerViewController, didFailWith message: String)
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let supportedTypes: [AVMetadataObject.ObjectType] =
        [.ean13, .ean8, .upce, .code128, .code39, .qr]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { self.configureSession() }
                else { self.delegate?.scanner(self, didFailWith: "Camera access is needed to scan barcodes. Enable it in Settings.") }
            }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            delegate?.scanner(self, didFailWith: "No camera is available on this device.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            delegate?.scanner(self, didFailWith: "Couldn't start the barcode reader.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = supportedTypes

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        // Start on a background queue — startRunning() blocks the caller.
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        session.stopRunning()
        delegate?.scanner(self, didFind: value)
    }
}
