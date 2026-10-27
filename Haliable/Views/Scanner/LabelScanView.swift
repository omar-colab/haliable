//
//  LabelScanView.swift
//  Haliable
//
//  The ingredient checker: type or paste an ingredients list, or read it off
//  the pack (live VisionKit text, or a photo), and see what the same
//  RulesEngine says as you go. On-device, no account, no AI.
//
//  Camera text is a draft: a misread word ("gelatln") matches nothing, so until
//  the person confirms it matches the pack, the preview lists only what WAS
//  flagged and never shows an overall grade.
//

import SwiftUI

struct LabelScanView: View {
    /// Called with the ingredients text to open the full result.
    let onCheck: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(RulesEngine.self) private var engine
    @Environment(AppSettings.self) private var settings

    @State private var text = ""
    @State private var fromCamera = false
    @State private var confirmed = false
    @State private var showLive = false
    @State private var showPhoto = false
    @State private var reading = false
    @State private var error: String?
    @FocusState private var editing: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    private var enough: Bool { LabelTextReader.looksLikeAnIngredientList(text) }
    private var trusted: Bool { !fromCamera || confirmed }

    private var preview: ProductVerdict? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 3 else { return nil }
        return engine.evaluate(product: LabelScanView.product(t), standard: settings.halalStandard)
    }

    static func product(_ text: String) -> Product {
        Product(id: "label-\(UUID().uuidString)", name: "Ingredients you checked",
                brand: "From the label", rawIngredientsText: text, additivesENumbers: [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. sugar, gelatin, mono- and diglycerides, natural flavor",
                              text: $text, axis: .vertical)
                        .lineLimit(4...12)
                        .font(DSFont.body)
                        .focused($editing)
                        .accessibilityIdentifier("checker.input")
                        .onChange(of: text) { _, _ in confirmed = false }
                    if reading { HStack(spacing: DSSpacing.sm) { ProgressView(); Text("Reading the label…") } }
                    if let error { Text(error).foregroundStyle(DSColor.danger) }
                } header: {
                    Text("Ingredients")
                } footer: {
                    Text(fromCamera
                         ? "Read by the camera — fix any word that doesn't match the pack."
                         : "Type or paste a list, separated by commas. Works offline.")
                }

                if let preview { previewSection(preview) }

                Section {
                    Button {
                        editing = false
                        if LiveTextScanner.isAvailable { showLive = true } else { showPhoto = true }
                    } label: { Label("Scan the label", systemImage: "text.viewfinder") }
                    if LiveTextScanner.isAvailable {
                        Button { editing = false; showPhoto = true } label: { Label("Use a photo instead", systemImage: "camera") }
                    }
                    if !text.isEmpty {
                        Button("Clear", role: .destructive) { text = ""; fromCamera = false; error = nil }
                    }
                }


                if !text.isEmpty {
                    Section {
                        if fromCamera { Toggle("I checked this matches the label", isOn: $confirmed) }
                        Button("See the full result") { onCheck(text); dismiss() }
                            .bold()
                            .disabled(!enough || !trusted)
                    } footer: {
                        if !enough { Text("Add at least two ingredients to see a full result.") }
                    }
                }
            }
            .navigationTitle("Ingredient checker")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editing = false }.bold()
                }
            }
            .fullScreenCover(isPresented: $showLive) {
                LiveTextCapture { captured in use(LabelTextReader.ingredientsSection(of: captured)) }
            }
            .sheet(isPresented: $showPhoto) {
                CameraPhotoPicker { image in Task { await read(image) } }.ignoresSafeArea()
            }
        }
    }

    /// What the rules flag, live. Before camera text is confirmed, only the
    /// flags show — a misread list must never read as "Halal".
    @ViewBuilder private func previewSection(_ v: ProductVerdict) -> some View {
        Section {
            if trusted {
                row { Text("Overall").font(DSFont.headline) } badge: {
                    GradeBadge(grade: v.overallGrade, pendingReview: v.overallNeedsReview)
                }
            }
            if v.flagged.isEmpty {
                Text(trusted ? "Nothing flagged by the rules for \(settings.halalStandard.displayName)."
                             : "Nothing flagged yet — confirm the text to see the overall grade.")
                    .foregroundStyle(DSColor.textSecondary)
            }
            ForEach(v.flagged) { item in
                row {
                    Label { Text(item.displayName) } icon: {
                        Image(systemName: item.grade.symbolName).foregroundStyle(item.grade.tint)
                    }
                } badge: {
                    GradeBadge(grade: item.grade, pendingReview: item.needsReview)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Live check · \(settings.halalStandard.displayName)")
        }
    }

    /// Side by side normally; stacked at accessibility text sizes, so neither
    /// the name nor the grade pill gets squeezed into "Nat-ural" or "…".
    @ViewBuilder private func row<Title: View, Badge: View>(@ViewBuilder _ title: () -> Title,
                                                             @ViewBuilder badge: () -> Badge) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DSSpacing.xs) { title(); badge() }
        } else {
            HStack { title(); Spacer(); badge() }
        }
    }

    private func use(_ captured: String) {
        guard !captured.isEmpty else { error = "Couldn't read any text. Try again closer, in good light."; return }
        text = captured
        fromCamera = true
        confirmed = false
        error = nil
    }

    private func read(_ image: UIImage) async {
        reading = true
        defer { reading = false }
        do { use(try await LabelTextReader.read(image)) } catch { self.error = error.localizedDescription }
    }
}

/// Full-screen live text: point at the ingredients, tap Capture.
private struct LiveTextCapture: View {
    let onCapture: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var token = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            LiveTextScanner(captureToken: token) { captured in onCapture(captured); dismiss() }
                .ignoresSafeArea()
            VStack(spacing: DSSpacing.sm) {
                Text("Fit the whole ingredients list in view")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, DSSpacing.sm).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                HStack {
                    Button("Cancel") { dismiss() }
                        .padding(.horizontal, DSSpacing.md).padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                    Button { token += 1 } label: {
                        Label("Capture", systemImage: "text.viewfinder")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DSSpacing.md).padding(.vertical, 14)
                            .background(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                    }
                    .accessibilityHint("Reads the text in view into the ingredient checker")
                }
            }
            .padding(DSSpacing.screen)
        }
    }
}
