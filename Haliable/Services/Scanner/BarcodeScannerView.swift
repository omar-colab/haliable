//
//  BarcodeScannerView.swift
//  Haliable
//
//  A dependency-free barcode scanner built directly on AVFoundation.
//  Replaces the previous third-party CodeScanner package.
//
//  Note: the iOS Simulator has no camera, so this shows a "camera
//  unavailable" message there. Use a physical device, or the manual
//  barcode entry on the scanner, to test the full flow.
//
//  Lifecycle (the TestFlight "frozen camera" fix, Oct 17):
//  The first version stopped the session in viewWillDisappear and never started
//  it again, and it stopped the session for good after the first barcode. Coming
//  back to the scanner from another screen therefore showed the last frame,
//  frozen. Now:
//   • every start/stop runs on ONE serial queue, so a stop can never race a start;
//   • the parent says when the camera should run (`isActive`) and when a code
//     should be acted on (`acceptsCodes`), and the controller follows both;
//   • it also restarts on viewWillAppear, after an interruption (a phone call,
//     another app taking the camera) and after a media-services reset;
//   • the session is released in dismantleUIViewController, so a closed
//     scanner never keeps the camera.
//

import SwiftUI
import AVFoundation
import AudioToolbox

struct BarcodeScannerView: UIViewControllerRepresentable {
    /// Called with a barcode string. The parent decides what happens next.
    let onFound: (String) -> Void
    /// Called if the camera can't be used (no permission / no hardware).
    var onError: ((String) -> Void)? = nil
    /// When false the capture session is stopped (verdict sheet up, app in the
    /// background). When it turns true again the camera resumes in place.
    var isActive: Bool = true
    /// When false the camera keeps running but found codes are ignored
    /// (e.g. while a lookup is in flight).
    var acceptsCodes: Bool = true
    /// Bump to forget the last delivered code, so pointing at the same barcode
    /// again scans it again ("Scan again").
    var rescanToken: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        vc.acceptsCodes = acceptsCodes
        vc.setActive(isActive)
        context.coordinator.lastToken = rescanToken
        return vc
    }

    func updateUIViewController(_ vc: ScannerViewController, context: Context) {
        context.coordinator.parent = self
        vc.acceptsCodes = acceptsCodes
        if context.coordinator.lastToken != rescanToken {
            context.coordinator.lastToken = rescanToken
            vc.forgetLastCode()
        }
        vc.setActive(isActive)
    }

    static func dismantleUIViewController(_ vc: ScannerViewController, coordinator: Coordinator) {
        vc.shutDown()
    }

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: BarcodeScannerView
        var lastToken = 0
        init(_ parent: BarcodeScannerView) { self.parent = parent }

        func scanner(_ controller: ScannerViewController, didFind code: String) {
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

    /// Found codes are only delivered while this is true.
    var acceptsCodes = true

    private let session = AVCaptureSession()
    /// Every configure / start / stop goes through this one serial queue.
    private let sessionQueue = DispatchQueue(label: "app.haliable.scanner.session", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let supportedTypes: [AVMetadataObject.ObjectType] =
        [.ean13, .ean8, .upce, .code128, .code39, .qr]

    // Main-thread state.
    private var isConfigured = false
    private var wantsRunning = true
    private var isOnScreen = true
    private var isShutDown = false

    // A barcode is delivered once, then ignored while it stays in frame. It can be
    // delivered again only after it has been out of view for `reappearGap`, or
    // after forgetLastCode(). This stops a verdict sheet re-opening the moment it
    // is dismissed because the same product is still in front of the camera.
    private var lastCode: String?
    private var lastCodeSeenAt = Date.distantPast
    private let reappearGap: TimeInterval = 1.2

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(sessionNeedsRestart),
                           name: AVCaptureSession.interruptionEndedNotification, object: session)
        center.addObserver(self, selector: #selector(sessionRuntimeError(_:)),
                           name: AVCaptureSession.runtimeErrorNotification, object: session)
        center.addObserver(self, selector: #selector(sessionNeedsRestart),
                           name: UIApplication.didBecomeActiveNotification, object: nil)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.configureSession() } else { self.failPermission() }
                }
            }
        default:
            failPermission()
        }
    }

    private func failPermission() {
        delegate?.scanner(self, didFailWith: "Camera access is needed to scan barcodes. Enable it in Settings.")
    }

    /// Adds the camera input and the barcode output. Runs on the main thread (as
    /// the original did); only start/stop — the slow, blocking calls — go to
    /// `sessionQueue`.
    private func configureSession() {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            delegate?.scanner(self, didFailWith: "No camera is available on this device.")
            return
        }
        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            delegate?.scanner(self, didFailWith: "Couldn't start the barcode reader.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = supportedTypes.filter { output.availableMetadataObjectTypes.contains($0) }
        session.commitConfiguration()

        isConfigured = true
        updateRunning()
    }

    // MARK: Running state

    /// Called by SwiftUI on every update.
    func setActive(_ active: Bool) {
        guard active != wantsRunning else { return }
        wantsRunning = active
        // Coming back: whatever is in frame right now counts as "still seen",
        // so the product you just checked doesn't instantly re-open its verdict.
        if active { lastCodeSeenAt = Date() }
        updateRunning()
    }

    func forgetLastCode() {
        lastCode = nil
    }

    /// Stop for good — the SwiftUI view is going away.
    func shutDown() {
        isShutDown = true
        updateRunning()
    }

    private func updateRunning() {
        let shouldRun = isConfigured && wantsRunning && isOnScreen && !isShutDown
        let session = self.session
        sessionQueue.async {
            if shouldRun {
                if !session.isRunning { session.startRunning() }
            } else if session.isRunning {
                session.stopRunning()
            }
        }
    }

    @objc private func sessionNeedsRestart() {
        DispatchQueue.main.async { [weak self] in self?.updateRunning() }
    }

    @objc private func sessionRuntimeError(_ note: Notification) {
        // A media-services reset kills the session; start it again. Any other
        // runtime error gets one restart attempt too — better than a frozen frame.
        let session = self.session
        sessionQueue.async { [weak self] in
            if session.isRunning { session.stopRunning() }
            DispatchQueue.main.async { self?.updateRunning() }
        }
    }

    // MARK: View lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isOnScreen = true
        lastCodeSeenAt = Date()
        updateRunning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isOnScreen = false
        updateRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = view.layer.bounds
        CATransaction.commit()
    }

    // MARK: Metadata

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        let now = Date()
        let codes = metadataObjects
            .compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
            .filter { !$0.isEmpty }
        guard let code = codes.first else { return }

        if code == lastCode {
            let wasAway = now.timeIntervalSince(lastCodeSeenAt) > reappearGap
            lastCodeSeenAt = now
            guard wasAway else { return }
        }
        guard acceptsCodes, wantsRunning, !isShutDown else { return }

        lastCode = code
        lastCodeSeenAt = now
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.scanner(self, didFind: code)
    }
}
