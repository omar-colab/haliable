//
//  LabelScanView.swift
//  Haliable
//
//  "Not found? Read the label instead." Photo → on-device text → the person
//  checks and corrects it → the same RulesEngine grades it. The check step is
//  the safety: a misread word ("gelatln") would match nothing, so the text is
//  never graded until someone has compared it with the pack.
//

import SwiftUI

struct LabelScanView: View {
    /// Called with the confirmed ingredients text.
    let onCheck: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showCamera = true
    @State private var reading = false
    @State private var text = ""
    @State private var error: String?
    @State private var confirmed = false

    private var enough: Bool { LabelTextReader.looksLikeAnIngredientList(text) }

    var body: some View {
        NavigationStack {
            Form {
                if reading {
                    HStack(spacing: DSSpacing.sm) { ProgressView(); Text("Reading the label…") }
                } else if text.isEmpty {
                    Section {
                        Text(error ?? "Take a clear, close photo of the ingredients list.")
                            .foregroundStyle(error == nil ? DSColor.textSecondary : DSColor.danger)
                        Button { showCamera = true } label: { Label("Take photo", systemImage: "camera") }
                    }
                } else {
                    Section {
                        TextEditor(text: $text)
                            .frame(minHeight: 180)
                            .font(DSFont.body)
                            .onChange(of: text) { _, _ in confirmed = false }
                    } header: {
                        Text("Ingredients read from your photo")
                    } footer: {
                        Text(enough
                             ? "Fix any word that doesn't match the pack. A misread ingredient can't be checked."
                             : "That looks like only part of the list. Retake the photo with the whole list in frame.")
                    }
                    Section {
                        Toggle("I checked this matches the label", isOn: $confirmed)
                        Button("Check these ingredients") {
                            onCheck(text)
                            dismiss()
                        }
                        .bold()
                        .disabled(!enough || !confirmed)
                        Button("Retake photo") { text = ""; showCamera = true }
                    }
                }
            }
            .navigationTitle("Read the label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showCamera) {
                CameraPhotoPicker { image in Task { await read(image) } }.ignoresSafeArea()
            }
        }
    }

    private func read(_ image: UIImage) async {
        reading = true
        defer { reading = false }
        do {
            text = try await LabelTextReader.read(image)
            error = nil
        } catch {
            text = ""
            self.error = error.localizedDescription
        }
    }
}
