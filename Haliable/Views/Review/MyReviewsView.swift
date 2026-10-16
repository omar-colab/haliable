//
//  MyReviewsView.swift
//  Haliable
//
//  The "Reviews" tab: lists the user's manual-review requests and their status.
//  Tap one to see the returned verdict. Pull to refresh.
//

import SwiftUI

struct MyReviewsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ReviewStore.self) private var store
    @State private var showRequest = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signedOut
                } else if store.requests.isEmpty {
                    EmptyStateView(symbol: "doc.text.magnifyingglass",
                                   title: "No reviews yet",
                                   message: "Send us photos of a tricky product and we'll give it a human halal verdict.")
                } else {
                    list
                }
            }
            .navigationTitle("My Reviews")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showRequest = true } label: { Image(systemName: "plus") }
                        .disabled(!auth.isSignedIn)
                }
            }
            .sheet(isPresented: $showRequest) { RequestReviewView() }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private var list: some View {
        List(store.requests) { request in
            NavigationLink(value: request) {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(request.productName ?? "Untitled product")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    HStack {
                        statusChip(request)
                        if let v = request.verdict { VerdictBadge(verdict: v) }
                        Spacer()
                        Text(request.createdAt, style: .date)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }.padding(.vertical, 2)
            }
        }
        .navigationDestination(for: ReviewRequest.self) { ReviewDetailView(request: $0) }
    }

    private var signedOut: some View {
        VStack(spacing: 16) {
            EmptyStateView(symbol: "person.crop.circle.badge.questionmark",
                           title: "Sign in to request reviews",
                           message: "We return your verdict to your account.")
            AppleSignInButton { errorMessage = $0 }.padding(.horizontal, 40)
            if let errorMessage {
                Text(errorMessage).font(DSFont.caption).foregroundStyle(DSColor.danger)
            }
        }.padding(DSSpacing.md)
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
