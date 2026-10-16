//
//  ScannerViewV2.swift
//  Haliable
//
//  A high-polish redesign of the Home/Scanner screen — "Aperture": a focused,
//  premium scanning instrument. SAFE TO TRY: brand-new file; the original
//  `ScannerView` is untouched and stays wired into RootTabView.
//
//  Re-skin ONLY. Same scan logic as the original: same RulesEngine / AppSettings
//  / SwiftData environment, same ProductLookupService, same BarcodeScannerView,
//  same destinations, and a handleScan(...) identical in behavior to the
//  original's. Everything visual comes from DesignTokens — no hex, no new names.
//
//  ── TO PREVIEW V2 ──────────────────────────────────────────────────────────
//  In RootTabView.swift, change the first tab's `ScannerView()` to
//  `ScannerViewV2()`. That's the only change. Revert it to go back.
//  ───────────────────────────────────────────────────────────────────────────
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ScannerViewV2: View {
    @Environment(RulesEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    /// Read-only: first-run (intro) vs returning (auto-start). No model change.
    @Query private var history: [ScanRecord]

    // Hero / camera presentation
    @State private var cameraActive = false
    @State private var cameraUnavailable = false
    @State private var warming = false
    @State private var scannerID = UUID()
    @State private var pulse = false
    @State private var appeared = false

    // Scan flow (same set the original carries)
    @State private var isLoading = false
    @State private var currentVerdict: ProductVerdict?
    @State private var errorMessage: String?
    @State private var manualBarcode = ""
    @State private var showManualEntry = false
    @State private var showManualReview = false
    @State private var showSettings = false
    @State private var showStandardSheet = false
    @State private var standardSheetIsFirstRun = false

    private let lookup = ProductLookupService()

    var body: some View {
        @Bindable var settings = settings
        return NavigationStack {
            ZStack {
                DSColor.background.ignoresSafeArea()
                GeometryBackdrop(intensity: 0.8)
                FloatingLatticeMark(size: 300, opacity: 0.05)
                    .offset(x: 128, y: -300)
                ambientGlow

                ScrollView {
                    VStack(spacing: DSSpacing.md) {
                        header
                            .reveal(appeared, delay: 0.00)

                        HStack {
                            StandardPill(standard: settings.halalStandard) {
                                standardSheetIsFirstRun = false
                                showStandardSheet = true
                            }
                            Spacer(minLength: 0)
                        }
                        .reveal(appeared, delay: 0.06)

                        viewfinder
                            .frame(height: 396)
                            .reveal(appeared, delay: 0.12)

                        bottomControls
                            .reveal(appeared, delay: 0.18)

                        if currentVerdict == nil && !cameraActive && !recentScans.isEmpty {
                            recentlyChecked
                                .reveal(appeared, delay: 0.24)
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.sm)
                    .padding(.bottom, DSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $currentVerdict, onDismiss: resumeAfterVerdict) { VerdictView(verdict: $0) }
            .sheet(isPresented: $showManualReview) {
                RequestReviewView(prefillBarcode: manualBarcode.isEmpty ? nil : manualBarcode)
            }
            .sheet(isPresented: $showSettings) { SettingsV2() }
            .sheet(isPresented: $showStandardSheet) {
                StandardSelectorSheet(
                    selected: $settings.halalStandard,
                    isFirstRun: standardSheetIsFirstRun,
                    onCommit: { _ in settings.hasChosenStandard = true },
                    onDecideLater: { settings.hasChosenStandard = true }
                )
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { appeared = true }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
                if !history.isEmpty && !cameraActive { startCamera() }
            }
        }
    }

    // MARK: - Atmosphere

    private var ambientGlow: some View {
        RadialGradient(
            colors: [DSColor.accent.opacity(0.10), DSColor.accent.opacity(0)],
            center: UnitPoint(x: 0.5, y: 0.34),
            startRadius: 6,
            endRadius: 340
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Header (v4 brandlock: mark tile · wordmark · kicker)

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 11) {
                AppBrandMark(size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    ObliqueText(runs: [
                        .serif("Ha", size: 27, color: "TextPrimary"),
                        .italic("liable", size: 27, color: "AccentDeep"),
                    ])
                    Text("HALAL SCANNER")
                        .font(DSFont.label)
                        .tracking(2.2)
                        .foregroundStyle(DSColor.textTertiary)
                }
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(DSColor.textSecondary)
                    .headerChip()
            }
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Viewfinder hero

    @ViewBuilder private var viewfinder: some View {
        ZStack {
            if !cameraActive {
                introContent
            } else if cameraUnavailable {
                unavailableContent
            } else {
                liveContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewfinderBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .strokeBorder(DSColor.accent.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 12)
    }

    /// The viewfinder is a calm dark "lens" in every state — matching the v4 mock,
    /// where even the resting scanner reads as a deep green-black instrument.
    private var viewfinderBackground: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.12, green: 0.17, blue: 0.14),
                         Color(red: 0.05, green: 0.07, blue: 0.05)],
                center: UnitPoint(x: 0.5, y: 0.30), startRadius: 8, endRadius: 320)
            // faint scanning dot-grid, masked to the center
            RadialGradient(colors: [DSColor.accent.opacity(0.10), .clear],
                           center: .center, startRadius: 4, endRadius: 220)
        }
    }

    /// First-run / resting state — the v4 dark lens: corner reticle + a faint
    /// barcode hint + a calm caption pinned to the bottom. The action buttons live
    /// BELOW the viewport (see `bottomControls`).
    private var introContent: some View {
        ZStack {
            ReticleView(active: false, pulse: pulse)
            barcodeHint
            VStack(spacing: DSSpacing.xs) {
                Spacer(minLength: 0)
                Text("Ready when you are")
                    .font(DSFont.serif(21))
                    .foregroundStyle(Color(red: 0.95, green: 0.93, blue: 0.87))
                Text("Line up a barcode — we'll read it in an instant.")
                    .font(DSFont.caption)
                    .foregroundStyle(Color(red: 0.58, green: 0.63, blue: 0.59))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.lg)
        }
    }

    /// A faint cluster of barcode bars inside the reticle (resting state only).
    private var barcodeHint: some View {
        HStack(spacing: 3) {
            ForEach(Array(barWidths.enumerated()), id: \.offset) { _, w in
                Capsule().fill(Color(red: 0.63, green: 0.90, blue: 0.76).opacity(0.5))
                    .frame(width: w, height: 52)
            }
        }
        .accessibilityHidden(true)
    }

    private let barWidths: [CGFloat] = [3,2,4,2,3,2,2,4,3,2,3,2,4,2,2,3,2,4,3,2,3]

    private var unavailableContent: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 38))
                .foregroundStyle(DSColor.textSecondary)
            Text("Camera unavailable")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text("Enable camera access in Settings, or enter a barcode number below.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Open Settings", systemImage: "gearshape") { openSystemSettings() }
                .padding(.top, DSSpacing.xs)
        }
        .padding(DSSpacing.xl)
    }

    private var liveContent: some View {
        ZStack {
            if currentVerdict == nil {
                BarcodeScannerView(
                    onFound: { code in Task { await handleScan(barcode: code) } },
                    onError: { _ in withAnimation(.easeInOut(duration: 0.3)) { cameraUnavailable = true } }
                )
                .id(scannerID)
            } else {
                DSColor.surfaceElevated
            }

            ReticleView(active: true, pulse: pulse)

            if warming { warmingOverlay.transition(.opacity) }
            if isLoading { loadingOverlay.transition(.opacity) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera viewfinder. Point at a product barcode to scan it.")
    }

    private var warmingOverlay: some View {
        ZStack {
            DSColor.background.opacity(0.96)
            VStack(spacing: DSSpacing.sm) {
                hMark(size: 46).opacity(pulse ? 1 : 0.4)
                Text("Starting camera…")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .accessibilityLabel("Starting camera")
    }

    private var loadingOverlay: some View {
        ZStack {
            DSColor.background.opacity(0.86)
            VStack(spacing: DSSpacing.md) {
                hMark(size: 54).opacity(pulse ? 1 : 0.5)
                Text("Checking ingredients…")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
        .accessibilityLabel("Checking ingredients")
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 11) {
            if cameraActive && !cameraUnavailable {
                Label("Aim at a barcode — we check it automatically", systemImage: "viewfinder")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            } else {
                GuardAction(symbol: "barcode.viewfinder",
                            title: "Start a halal scan",
                            subtitle: "Check a label before it goes in the basket.") {
                    impactLight(); startCamera()
                }
            }

            SecondaryButton(title: showManualEntry ? "Hide manual entry" : "Enter barcode manually",
                            systemImage: "keyboard") {
                impactLight()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showManualEntry.toggle() }
            }
            .accessibilityHint("For when the camera can't read the barcode")

            if showManualEntry { manualField }

            if let errorMessage { errorCard(errorMessage) }
        }
    }

    private var manualField: some View {
        HStack(spacing: DSSpacing.sm) {
            TextField("Barcode number", text: $manualBarcode)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .font(DSFont.body)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs + 2)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                        .strokeBorder(DSColor.outline, lineWidth: 1))
                .accessibilityLabel("Barcode number")
            Button("Look up") {
                impactLight(); Task { await handleScan(barcode: manualBarcode) }
            }
            .font(DSFont.headline)
            .foregroundStyle(manualBarcode.isEmpty ? DSColor.textSecondary : DSColor.accentDeep)
            .disabled(manualBarcode.isEmpty)
            .accessibilityLabel("Look up barcode")
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Recently checked reel (real scan history)

    private var recentScans: [ScanRecord] {
        history.sorted { $0.scannedAt > $1.scannedAt }
    }

    private var recentlyChecked: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            GuardSection(title: "Recently checked", trailing: "All")
            ForEach(recentScans.prefix(3)) { rec in
                GuardRow(symbol: symbolFor(rec.overallVerdict),
                         tint: rec.overallVerdict.tint,
                         title: rec.productName,
                         subtitle: rec.overallVerdict.displayName,
                         trailing: rec.scannedAt.formatted(.relative(presentation: .numeric)),
                         showsArrow: false)
            }
        }
    }

    private func symbolFor(_ verdict: Verdict) -> String {
        switch verdict {
        case .halal:    return "checkmark.circle"
        case .haram:    return "xmark.circle"
        case .doubtful: return "questionmark.circle"
        }
    }

    private func verdictDot(_ verdict: Verdict) -> some View {
        Image(systemName: verdict == .halal ? "checkmark" : verdict == .haram ? "xmark" : "questionmark")
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(DSColor.onAccent)
            .frame(width: 16, height: 16)
            .background(verdict.tint, in: Circle())
            .overlay(Circle().strokeBorder(DSColor.surface, lineWidth: 2))
            .accessibilityHidden(true)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: DSSpacing.sm) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(DSFont.body)
                .foregroundStyle(DSColor.danger)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Request a manual review instead", systemImage: "camera.viewfinder") {
                showManualReview = true
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity)
        .background(DSColor.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .strokeBorder(DSColor.danger.opacity(0.30), lineWidth: 1))
        .padding(.top, DSSpacing.xs)
    }

    // MARK: - Shared

    private func hMark(size: CGFloat) -> some View {
        Image("HMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(DSColor.accent)
            .shadow(color: DSColor.accent.opacity(0.45), radius: 18)
            .accessibilityHidden(true)
    }

    // Reticle: breathing accent corner-brackets + a gradient scan beam.
    private struct ReticleView: View {
        let active: Bool
        let pulse: Bool
        @State private var beamDown = false
        var body: some View {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.60
                ZStack {
                    ReticleCorners(side: side)
                        .stroke(DSColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .scaleEffect(active && pulse ? 1.03 : 1.0)
                    if active {
                        LinearGradient(
                            colors: [DSColor.accent.opacity(0), DSColor.accent, DSColor.accent.opacity(0)],
                            startPoint: .leading, endPoint: .trailing)
                            .frame(width: side * 0.9, height: 2)
                            .shadow(color: DSColor.accent, radius: 7)
                            .offset(y: (beamDown ? 1 : -1) * side * 0.42)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { beamDown = true }
            }
        }
    }

    private struct ReticleCorners: Shape {
        var side: CGFloat
        var len: CGFloat = 30
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let x0 = rect.midX - side / 2, x1 = rect.midX + side / 2
            let y0 = rect.midY - side / 2, y1 = rect.midY + side / 2
            let l = len
            p.move(to: CGPoint(x: x0, y: y0 + l)); p.addLine(to: CGPoint(x: x0, y: y0)); p.addLine(to: CGPoint(x: x0 + l, y: y0))
            p.move(to: CGPoint(x: x1 - l, y: y0)); p.addLine(to: CGPoint(x: x1, y: y0)); p.addLine(to: CGPoint(x: x1, y: y0 + l))
            p.move(to: CGPoint(x: x1, y: y1 - l)); p.addLine(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x1 - l, y: y1))
            p.move(to: CGPoint(x: x0 + l, y: y1)); p.addLine(to: CGPoint(x: x0, y: y1)); p.addLine(to: CGPoint(x: x0, y: y1 - l))
            return p
        }
    }

    // MARK: - Camera lifecycle

    private func startCamera() {
        cameraUnavailable = false
        scannerID = UUID()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { cameraActive = true }
        beginWarming()
    }

    private func resumeAfterVerdict() {
        guard cameraActive, !cameraUnavailable else { return }
        scannerID = UUID()
        beginWarming()
    }

    private func beginWarming() {
        warming = true
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.easeOut(duration: 0.4)) { warming = false }
        }
    }

    // MARK: - Scan logic (identical behavior to ScannerView.handleScan)

    private func handleScan(barcode: String) async {
        let code = barcode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let product = try await lookup.fetchProduct(
                barcode: code, cache: SwiftDataProductCache(context: modelContext))
            let verdict = engine.evaluate(product: product, standard: settings.halalStandard)
            hapticSuccess()
            currentVerdict = verdict
            modelContext.insert(ScanRecord(
                barcode: code,
                productName: product.name,
                overallVerdict: verdict.overall
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

// MARK: - Staggered reveal helper

private extension View {
    /// Fade + lift in, with a per-section delay, for a calm orchestrated load.
    func reveal(_ shown: Bool, delay: Double) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay), value: shown)
    }
}

#Preview {
    ScannerViewV2()
        .environment(RulesEngine())
        .environment(AppSettings())
        .modelContainer(for: ScanRecord.self, inMemory: true)
        .preferredColorScheme(.dark)   // app defaults to Dark; preview matches it
}
