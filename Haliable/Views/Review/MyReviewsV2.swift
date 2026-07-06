//
//  MyReviewsV2.swift
//  Haliable
//
//  Redesigned "Reviews" tab on the shared AppScreen scaffold. Same data and logic
//  as MyReviewsView (ReviewStore refresh, request sheet, auth gate) — re-skinned
//  to match the app's holistic dark look. Original MyReviewsView is untouched.
//
//  Preview swap: in RootTabView.swift, change `MyReviewsView()` to `MyReviewsV2()`.
//

import SwiftUI

struct MyReviewsV2: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ReviewStore.self) private var store
    @State private var showRequest = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            AppScreen(eyebrow: "Human checks", title: "Reviews", trailing: {
                if auth.isSignedIn {
                    Button { showRequest = true } label: {
                        Image(systemName: "plus")
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.accent)
                    }
                    .headerChip()
                    .accessibilityLabel("Request a review")
                }
            }) {
                content
                    .navigationDestination(for: ReviewRequest.self) { ReviewDetailView(request: $0) }
            }
            .sheet(isPresented: $showRequest) { RequestReviewView() }
            .task { await reload() }
        }
    }

    @ViewBuilder private var content: some View {
        if !auth.isSignedIn {
            signedOut
        } else if store.requests.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: DSSpacing.sm) {
                tagline
                PrimaryButton(title: "Request a review", systemImage: "plus") { showRequest = true }
                SectionLabel("Your requests")
                    .padding(.top, DSSpacing.xs)
                ForEach(store.requests) { request in
                    NavigationLink(value: request) { row(request) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .refreshable { await reload() }
    }

    /// The editorial italic promise — a real person checks tricky labels.
    private var tagline: some View {
        ObliqueText(runs: [
            .italic("Stuck on a tricky label? Send a photo — ", size: 17, color: "TextSecondary"),
            .italic("a real person checks it and writes back.", size: 17, color: "TextPrimary"),
        ], lineSpacing: 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, DSSpacing.xs)
    }

    private func row(_ request: ReviewRequest) -> some View {
        HStack(spacing: DSSpacing.md) {
            ProductMonogram(text: request.productName ?? "Untitled product", size: 46)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(request.productName ?? "Untitled product")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: DSSpacing.xs) {
                    statusChip(request)
                    if let v = request.verdict { VerdictBadge(verdict: v) }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
                Text(request.createdAt, style: .date)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(DSColor.textSecondary.opacity(0.6))
            }
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private var signedOut: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()
            brandMark
            Text("Sign in to request reviews")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("Send us photos of a tricky product and we'll return a human halal verdict to your account.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSSpacing.lg)
            AppleSignInButton { errorMessage = $0 }
                .padding(.horizontal, DSSpacing.xl)
                .padding(.top, DSSpacing.sm)
            if let errorMessage {
                Text(errorMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.danger)
            }
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DSSpacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()
            brandMark
            Text("No reviews yet")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            Text("Tap + to send photos of a tricky product — we'll give it a human halal verdict and return it here.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSSpacing.xl)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DSSpacing.lg)
    }

    private var brandMark: some View {
        Image("HMark")
            .renderingMode(.template)
            .resizable().scaledToFit()
            .frame(width: 64, height: 64)
            .foregroundStyle(DSColor.accent)
            .shadow(color: DSColor.accent.opacity(0.4), radius: 16)
            .accessibilityHidden(true)
    }

    private func statusChip(_ r: ReviewRequest) -> some View {
        StatusBadge(text: r.status.displayName,
                    tint: r.status == .completed ? DSColor.success : DSColor.warning)
    }

    private func reload() async {
        guard auth.isSignedIn else { return }
        do { try await store.refresh(auth: auth) }
        catch { errorMessage = error.localizedDescription }
    }
}

#Preview {
    MyReviewsV2()
        .environment(AuthManager())
        .environment(ReviewStore())
        .preferredColorScheme(.dark)
}
