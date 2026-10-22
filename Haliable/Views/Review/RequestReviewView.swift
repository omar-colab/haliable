//
//  RequestReviewView.swift
//  Haliable
//
//  The manual-review submission flow: snap/pick photos of a product and its
//  ingredient list, add a little context, and send it for a human halal verdict.
//

import SwiftUI
import PhotosUI

struct RequestReviewView: View {
    /// Optionally pre-fill from a product the scanner couldn't resolve.
    var prefillName: String? = nil
    var prefillBarcode: String? = nil

    @Environment(AuthManager.self) private var auth
    @Environment(ReviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var images: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    /// The server takes 1–6 photos (migration 0015); 4 keeps uploads quick.
    static let maxPhotos = 4
    @State private var showCamera = false
    @State private var productName = ""
    @State private var barcode = ""
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var submitted = false
    /// App Review 5.1.2(i): explicit permission before photos and notes go to a
    /// third-party AI. Asked once; the switch stays visible so it can be undone.
    @AppStorage("reviewAIConsent") private var aiConsent = false

    var body: some View {
        NavigationStack {
            Form {
                if !auth.isSignedIn {
                    Section {
                        Text("Sign in with Apple so we can return your verdict to you. We only use it to track your requests.")
                            .font(DSFont.body).foregroundStyle(DSColor.textSecondary)
                        AppleSignInButton { errorMessage = $0 }
                    }
                } else {
                    photosSection
                    detailsSection
                    submitSection
                }

                if let errorMessage {
                    Section { Text(errorMessage).font(DSFont.body).foregroundStyle(DSColor.danger) }
                }
            }
            .navigationTitle("Request a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showCamera) {
                CameraPhotoPicker { if images.count < Self.maxPhotos { images.append($0) } }.ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, items in Task { await loadPicked(items) } }
            .onAppear {
                if productName.isEmpty, let p = prefillName { productName = p }
                if barcode.isEmpty, let b = prefillBarcode { barcode = b }
            }
            .alert("Request sent", isPresented: $submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text("We'll review your photos and your verdict will appear in My Reviews.")
            }
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 10))
                                Button { images.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }.padding(4)
                            }
                        }
                    }
                }
            }
            Button { showCamera = true } label: { Label("Take photo", systemImage: "camera") }
                .disabled(images.count >= Self.maxPhotos)
            PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, Self.maxPhotos - images.count), matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            .disabled(images.count >= Self.maxPhotos)
            Text("Tip: include a clear shot of the full ingredients list.")
                .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
        }
    }

    private var detailsSection: some View {
        Section("Details (optional)") {
            TextField("Product name", text: $productName)
            TextField("Barcode", text: $barcode).keyboardType(.numberPad)
            TextField("Anything we should know?", text: $notes, axis: .vertical).lineLimit(2...4)
        }
    }

    private var submitSection: some View {
        Section {
            if store.isLive {
                Toggle(isOn: $aiConsent) {
                    Text("Share my photos and notes with Anthropic's Claude AI, which drafts an answer from published halal sources. A person checks it before you see a verdict.")
                        .font(DSFont.caption)
                }
            }
            Button {
                Task { await submit() }
            } label: {
                if store.isWorking { ThinkingOrb(diameter: 28) } else { Text("Submit for review").bold() }
            }
            .disabled(images.isEmpty || store.isWorking || (store.isLive && !aiConsent))
            if !store.isLive {
                Text("Demo mode: no backend configured, so this is stored locally only.")
                    .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        for item in items where images.count < Self.maxPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                images.append(img)
            }
        }
        pickerItems = []
    }

    private func submit() async {
        errorMessage = nil
        do {
            try await store.submit(
                images: images,
                productName: productName.isEmpty ? nil : productName,
                barcode: barcode.isEmpty ? nil : barcode,
                notes: notes.isEmpty ? nil : notes,
                auth: auth
            )
            submitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
