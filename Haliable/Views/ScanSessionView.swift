//
//  ScanSessionView.swift
//  Haliable
//
//  Board screen 2 — the full-screen scanner, opened from Home's "Start a halal
//  scan" or the dock. Same BarcodeScannerView and the same lookup → evaluate →
//  save path the old in-page viewfinder used; only the chrome is new.
//
//  Deliberately NOT here: the board's live ingredient tags over the feed
//  ("14 of 18 read"). Those need on-device label OCR — a feature the app does
//  not have — so the chip states only what is true: which standard is active.
//

import SwiftUI
import SwiftData
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct ScanSessionView: View {
    /// When set (e.g. tapping a Home row), look this barcode up immediately.
    var initialBarcode: String? = nil

    @Environment(RulesEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var cameraUnavailable = false
    @State private var warming = true
    @State private var scannerID = UUID()
    @State private var isLoading = false
    @State private var currentVerdict: ProductVerdict?
    @State private var errorMessage: String?
    @State private var manualBarcode = ""
    @State private var showManualEntry = false
    @State private var showManualReview = false
    @State private var torchOn = false

    private let lookup = ProductLookupService()

    private var hasTorch: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            camera.ignoresSafeArea()
            if !cameraUnavailable { ScanReticle(active: currentVerdict == nil && !isLoading) }

            VStack(spacing: DSSpacing.sm) {
                topBar
                Spacer(minLength: 0)
                bottomArea
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.bottom, DSSpacing.xs)

            if warming && !cameraUnavailable && initialBarcode == nil { statusOverlay("Starting camera…") }
            if isLoading { statusOverlay("Checking ingredients…") }
        }
        .animation(DSMotion.move, value: showManualEntry)
        .animation(DSMotion.move, value: errorMessage)
        .sheet(item: $currentVerdict, onDismiss: resume) { VerdictView(verdict: $0) }
        .sheet(isPresented: $showManualReview) {
            RequestReviewView(prefillBarcode: manualBarcode.isEmpty ? nil : manualBarcode)
        }
        .task {
            if let initialBarcode { await handleScan(barcode: initialBarcode) }
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.easeOut(duration: 0.4)) { warming = false }
        }
        .onDisappear { setTorch(false) }
    }

    // MARK: - Camera

    @ViewBuilder private var camera: some View {
        if cameraUnavailable {
            RadialGradient(colors: [DSColor.surfaceElevated, DSColor.background],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 460)
        } else if currentVerdict == nil {
            BarcodeScannerView(
                onFound: { code in Task { await handleScan(barcode: code) } },
                onError: { _ in withAnimation(.easeInOut(duration: 0.3)) { cameraUnavailable = true } }
            )
            .id(scannerID)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Camera viewfinder. Point at a product barcode to scan it.")
        } else {
            DSColor.background
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 6) {
            RingButton(symbol: "chevron.left", label: "Close scanner") { dismiss() }
            GuardChip(text: settings.halalStandard.displayName, live: !cameraUnavailable)
            Spacer(minLength: 0)
            if hasTorch && !cameraUnavailable {
                RingButton(symbol: torchOn ? "bolt.fill" : "bolt", label: torchOn ? "Turn torch off" : "Turn torch on",
                           active: torchOn) { setTorch(!torchOn) }
            }
        }
        .padding(.top, DSSpacing.xs)
    }

    private var bottomArea: some View {
        VStack(spacing: DSSpacing.sm) {
            if cameraUnavailable {
                unavailableCard
            } else {
                GuardChip(text: "Hold steady — reading the barcode")
            }
            if showManualEntry { manualField.transition(.opacity.combined(with: .move(edge: .bottom))) }
            if let errorMessage { errorCard(errorMessage).transition(.opacity) }
            dock
        }
    }

    private var dock: some View {
        HStack(spacing: -9) {
            DockBubble(symbol: "keyboard", label: "Enter barcode manually", selected: showManualEntry) {
                impactLight(); showManualEntry.toggle()
            }
            DockMainBubble(symbol: "barcode.viewfinder", label: "Scan again") {
                impactLight(); errorMessage = nil; restartCamera()
            }
            DockBubble(symbol: "camera.viewfinder", label: "Send photos for a human review") {
                showManualReview = true
            }
        }
        .padding(.top, DSSpacing.xxs)
    }

    private var unavailableCard: some View {
        VStack(spacing: DSSpacing.xs) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 30))
                .foregroundStyle(DSColor.textSecondary)
            Text("Camera unavailable")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text("Allow camera access in Settings, or type the barcode number.")
                .font(.system(size: 13))
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { openSystemSettings() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColor.accent)
                .padding(.top, 2)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(DSColor.outline, lineWidth: 1))
    }

    private var manualField: some View {
        HStack(spacing: DSSpacing.sm) {
            TextField("Barcode number", text: $manualBarcode)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .medium))
                .monospacedDigit()
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, 12)
                .background(DSColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
                .accessibilityLabel("Barcode number")
            Button {
                impactLight(); Task { await handleScan(barcode: manualBarcode) }
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .opacity(manualBarcode.isEmpty ? 0.45 : 1)
            }
            .pressable(0.92)
            .disabled(manualBarcode.isEmpty)
            .accessibilityLabel("Look up barcode")
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: DSSpacing.xs) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13.5))
                .foregroundStyle(DSColor.danger)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Request a manual review instead") { showManualReview = true }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(DSSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(DSColor.danger.opacity(0.4), lineWidth: 1))
    }

    private func statusOverlay(_ text: String) -> some View {
        ZStack {
            DSColor.background.opacity(0.88).ignoresSafeArea()
            VStack(spacing: DSSpacing.sm) {
                Image("HMark")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(DSColor.accent)
                    .shadow(color: DSColor.accent.opacity(0.45), radius: 18)
                Text(text)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Camera lifecycle

    private func restartCamera() {
        cameraUnavailable = false
        scannerID = UUID()
    }

    private func resume() {
        guard !cameraUnavailable else { return }
        scannerID = UUID()
    }

    private func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        torchOn = on
    }

    // MARK: - Scan logic (same behavior as the old ScannerViewV2.handleScan)

    private func handleScan(barcode: String) async {
        let code = barcode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, !isLoading else { return }
        withAnimation { isLoading = true }
        errorMessage = nil
        defer { withAnimation { isLoading = false } }
        do {
            let product = try await lookup.fetchProduct(
                barcode: code, cache: SwiftDataProductCache(context: modelContext))
            let verdict = engine.evaluate(product: product, standard: settings.halalStandard)
            hapticSuccess()
            currentVerdict = verdict
            showManualEntry = false
            modelContext.insert(ScanRecord(
                barcode: code,
                productName: product.name,
                overallVerdict: verdict.overall,
                standard: settings.halalStandard
            ))
            try? modelContext.save()
        } catch let error as OFFError {
            hapticError()
            errorMessage = error.errorDescription
        } catch {
            hapticError()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Haptics (respect the Settings toggle)

    private func impactLight() {
        #if canImport(UIKit)
        guard settings.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    private func hapticSuccess() {
        #if canImport(UIKit)
        guard settings.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    private func hapticError() {
        #if canImport(UIKit)
        guard settings.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #endif
    }
}
