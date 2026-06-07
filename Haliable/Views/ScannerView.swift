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
    @Environment(\.modelContext) private var modelContext   // SwiftData history

    @State private var isPresentingScanner = false
    @State private var isLoading = false
    @State private var currentVerdict: ProductVerdict?
    @State private var errorMessage: String?
    @State private var manualBarcode = ""
    @State private var showManualReview = false

    private let lookup = ProductLookupService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("Scan a grocery barcode")
                    .font(.title2.bold())

                Text("We check ingredients against IFANCA, ISNA, and AMJA guidance — and tell you honestly when something is Questionable.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button { isPresentingScanner = true } label: {
                    Label("Scan barcode", systemImage: "camera.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
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
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .foregroundStyle(.red).multilineTextAlignment(.center)
                        Button("Request a manual review instead") { showManualReview = true }
                            .font(.callout)
                    }
                    .padding()
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Haliable")
            .fullScreenCover(isPresented: $isPresentingScanner) {
                scannerSheet
            }
            .sheet(item: $currentVerdict) { VerdictView(verdict: $0) }
            .sheet(isPresented: $showManualReview) {
                RequestReviewView(prefillBarcode: manualBarcode.isEmpty ? nil : manualBarcode)
            }
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
            let product = try await lookup.fetchProduct(barcode: code)
            let verdict = engine.evaluate(product: product)
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
