//
//  MyReviewsV2.swift
//  Haliable
//
//  Board screen 7 — Reviews. Same data and logic as before (ReviewStore refresh,
//  request sheet, Sign in with Apple gate); the verdict now sits in the row so
//  nobody has to tap in to learn the answer.
//

import SwiftUI

struct MyReviewsV2: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ReviewStore.self) private var store
    @State private var showRequest = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GuardBackground()
                ScrollView {
                    VStack(spacing: 10) {
                        GuardIDRow(title: "Reviews", subtitle: "Ask a human") {
                            if auth.isSignedIn {
                                RingButton(symbol: "pencil.line", label: "Request a review") { showRequest = true }
                            }
                        }
                        .padding(.bottom, DSSpacing.xxs)

                        if auth.isSignedIn { signedIn } else { signedOut }
                    }
                    .padding(.horizontal, DSSpacing.screen)
                    .padding(.top, DSSpacing.xs)
                    .padding(.bottom, DSSpacing.lg)
                }
                .scrollIndicators(.hidden)
                .refreshable { await reload() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReviewRequest.self) { ReviewDetailView(request: $0) }
            .sheet(isPresented: $showRequest) { RequestReviewView() }
            .task { await reload() }
        }
    }

    @ViewBuilder private var signedIn: some View {
        GuardAction(symbol: "pencil.line",
                    title: "Not sure about something?",
                    subtitle: "Photograph the label — a scholar rules on it.") {
            showRequest = true
        }
        GuardSection(title: "Your requests")
            .padding(.top, DSSpacing.xs)
        if store.requests.isEmpty {
            GuardRow(symbol: "tray", tint: DSColor.textSecondary,
                     title: "No requests yet",
                     subtitle: "Send a tricky label and the answer lands here.",
                     showsArrow: false)
        } else {
            ForEach(store.requests) { request in
                NavigationLink(value: request) { row(request) }
                    .buttonStyle(PressableStyle(scale: 0.985))
            }
        }
        if let errorMessage { errorText(errorMessage) }
    }

    private var signedOut: some View {
        VStack(spacing: DSSpacing.sm) {
            Image("HMark")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 52, height: 52)
                .foregroundStyle(DSColor.accent)
                .shadow(color: DSColor.accent.opacity(0.4), radius: 16)
                .accessibilityHidden(true)
            Text("Sign in to request reviews")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("Photograph a tricky label and a person rules on it. The answer comes back to your account.")
                .font(.system(size: 14))
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            AppleSignInButton { errorMessage = $0 }
                .padding(.top, DSSpacing.xs)
            if let errorMessage { errorText(errorMessage) }
        }
        .padding(DSSpacing.lg)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(DSColor.outline, lineWidth: 1))
        .padding(.top, DSSpacing.xl)
    }

    private func row(_ r: ReviewRequest) -> some View {
        let sent = r.createdAt.formatted(.relative(presentation: .named))
        let (symbol, tint, detail): (String, Color, String) = {
            if r.status == .completed, let v = r.verdict {
                return (v.rowSymbol, v.tint, "Answered · \(v.displayName.lowercased())")
            }
            return ("clock", DSColor.warning, "\(r.status.displayName) · sent \(sent)")
        }()
        return GuardRow(symbol: symbol, tint: tint,
                        title: r.productName ?? "Untitled product",
                        subtitle: detail)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(DSFont.caption)
            .foregroundStyle(DSColor.danger)
            .multilineTextAlignment(.center)
    }

    private func reload() async {
        guard auth.isSignedIn else { return }
        do { try await store.refresh(auth: auth) }
        catch { errorMessage = error.localizedDescription }
    }
}

// The seeded fixtures below are `#if DEBUG` (they must not ship), so the previews
// that use them have to be too — otherwise a Release build fails to compile.
#if DEBUG
#Preview("Reviews - with requests") {
    MyReviewsV2()
        .environment(AuthManager.previewSignedIn())
        .environment(ReviewStore.previewSeeded())
}

#Preview("Reviews - signed out") {
    MyReviewsV2()
        .environment(AuthManager())
        .environment(ReviewStore())
}
#endif
