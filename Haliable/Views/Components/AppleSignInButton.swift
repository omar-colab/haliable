//
//  AppleSignInButton.swift
//  Haliable
//
//  Wraps SwiftUI's SignInWithAppleButton and routes the credential through
//  AuthManager. Drop it anywhere a contribution requires a signed-in user.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var colorScheme
    var onError: (String) -> Void = { _ in }

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            auth.configure(request)
        } onCompletion: { result in
            Task {
                do { try await auth.handle(result) }
                catch { onError(error.localizedDescription) }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        // Apple's button takes its style once, at creation. The in-app Theme lands
        // after launch, so a tab built under the phone's dark mode stayed white on a
        // white card in Light theme. Rebuild it when the scheme changes.
        .id(colorScheme)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
