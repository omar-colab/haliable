//
//  AuthManager.swift
//  Haliable
//
//  Sign in with Apple → Supabase session. Shared by the photo-review feature
//  and (later) the Store Atlas. Sign-in is only required to CONTRIBUTE
//  (submit a review or a store); browsing stays anonymous.
//
//  The Apple button + credential handling work without any package. The token
//  EXCHANGE with Supabase is gated behind `canImport(Supabase)`; without the
//  package we fall back to a local pseudo-session so the flow is testable.
//

import Foundation
import Observation
import AuthenticationServices
import CryptoKit

@Observable
final class AuthManager {
    private(set) var userID: String?
    private(set) var email: String?
    var isSignedIn: Bool { userID != nil }

    /// Raw nonce kept between request and completion (Apple hashes it; Supabase
    /// verifies against the raw value).
    private var currentNonce: String?

    init() {
        #if canImport(Supabase)
        Task { await restoreSession() }
        #endif
    }

    // MARK: Sign in with Apple plumbing (used by the SwiftUI button)

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handle(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw AuthError.missingToken
            }
            if let appleEmail = credential.email { self.email = appleEmail }
            try await exchange(idToken: idToken, nonce: currentNonce)
        }
    }

    func signOut() {
        userID = nil
        email = nil
        #if canImport(Supabase)
        Task { try? await SupabaseManager.shared?.auth.signOut() }
        #endif
    }

    /// The bearer token for authenticated API calls (nil when signed out / mock).
    func accessToken() async -> String? {
        #if canImport(Supabase)
        return try? await SupabaseManager.shared?.auth.session.accessToken
        #else
        return userID == nil ? nil : "mock-access-token"
        #endif
    }

    // MARK: Token exchange

    private func exchange(idToken: String, nonce: String?) async throws {
        #if canImport(Supabase)
        guard let client = SupabaseManager.shared else {
            // Package present but Secrets missing → behave like the mock.
            self.userID = "local-\(UUID().uuidString.prefix(8))"
            return
        }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        self.userID = session.user.id.uuidString
        if let supaEmail = session.user.email { self.email = supaEmail }
        #else
        // No Supabase package: store a stable local id so reviews can be listed.
        self.userID = "local-\(idToken.suffix(8))"
        #endif
    }

    #if canImport(Supabase)
    private func restoreSession() async {
        if let session = try? await SupabaseManager.shared?.auth.session {
            self.userID = session.user.id.uuidString
            self.email = session.user.email
        }
    }
    #endif

    enum AuthError: LocalizedError {
        case missingToken
        var errorDescription: String? { "Apple didn't return a sign-in token. Please try again." }
    }

    // MARK: Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
