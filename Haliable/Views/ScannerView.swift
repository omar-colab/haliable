//
//  ScannerView.swift
//  Haliable
//
//  Created by Omar O on 6/2/26.
//

import SwiftUI
import SwiftData

struct ScannerView: View {
    @Environment(RulesEngine.self) private var engine
    @Environment(AppSettings.self) private var settings     // active halal standard
    @Environment(\.modelContext) private var modelContext   // SwiftData history

    @State private var isPresentingScanner = false
    @State private var isLoading = false
    @State private var currentVerdict: ProductVerdict?
    @State private var errorMessage: String?
    @State private var manualBarcode = ""
    @State private var showManualReview = false
    @State private var showSettings = false
    @State private var showStandardSheet = false
    @State private var standardSheetIsFirstRun = false

    private let lookup = ProductLookupService()

    var body: some View {
        @Bindable var settings = settings
        return NavigationStack {
            VStack(spacing: DSSpacing.lg) {
                // In-context standard switcher — same source of truth as Settings.
                StandardPill(standard: settings.halalStandard) {
                    standardSheetIsFirstRun = false
                    showStandardSheet = true
                }
                .padding(.top, DSSpacing.xs)

                Spacer(minLength: 0)

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 72))
                    .foregroundStyle(DSColor.accent)
                    .shadow(color: DSColor.accent.opacity(0.4), radius: 16)

                Text("Scan a grocery barcode")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)

                Text("We check ingredients against IFANCA, ISNA, and AMJA guidance — and tell you honestly when something is Questionable.")
                    .font(DSFont.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.horizontal)

                PrimaryButton(title: "Scan barcode", systemImage: "camera.fill") {
                    isPresentingScanner = true
                }
                .padding(.horizontal)

                // Manual entry — works in the Simulator (no camera) and as a fallback.
                HStack {
                    TextField("Or enter a barcode", text: $manualBarcode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button("Look up") {
                        Task { await handleScan(barcode: manualBarcode) }
                    }
                    .disabled(manualBarcode.isEmpty)
                }
                .padding(.horizontal)

                if isLoading { ProgressView("Looking up product…") }

                if let errorMessage {
                    VStack(spacing: DSSpacing.xs) {
                        Text(errorMessage)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.danger)
                            .multilineTextAlignment(.center)
                        Button("Request a manual review instead") { showManualReview = true }
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.accent)
                    }
                    .padding(DSSpacing.md)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Haliable")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .fullScreenCover(isPresented: $isPresentingScanner) {
                scannerSheet
            }
            .sheet(item: $currentVerdict) { VerdictView(verdict: $0) }
            .sheet(isPresented: $showManualReview) {
                RequestReviewView(prefillBarcode: manualBarcode.isEmpty ? nil : manualBarcode)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showStandardSheet) {
                StandardSelectorSheet(
                    selected: $settings.halalStandard,
                    isFirstRun: standardSheetIsFirstRun,
                    onCommit: { _ in settings.hasChosenStandard = true },
                    onDecideLater: { settings.hasChosenStandard = true }
                )
            }
            // Note: we intentionally do NOT auto-present the standard chooser on
            // first launch — the app opens straight to the scanner. The default
            // standard is "General Halal", and the pill at the top of this screen
            // (or Settings) opens the chooser whenever the user wants it.
        }
    }

    private var scannerSheet: some View {
        ZStack(alignment: .topTrailing) {
            BarcodeScannerView(
                onFound: { code in
                    isPresentingScanner = false
                    Task { await handleScan(barcode: code) }
                },
                onError: { message in
                    isPresentingScanner = false
                    errorMessage = message
                }
            )
            .ignoresSafeArea()
            Button { isPresentingScanner = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title).symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding()
        }
    }

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
            currentVerdict = verdict
            modelContext.insert(ScanRecord(
                barcode: code,
                productName: product.name,
                overallVerdict: verdict.overall
            ))
            try? modelContext.save()
        } catch let error as OFFError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
