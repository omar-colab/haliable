//
//  SafariView.swift
//  Haliable
//
//  A thin SwiftUI wrapper around SFSafariViewController so we can show the
//  Privacy Policy / Terms in-app (Apple prefers this over bouncing to Safari).
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// What a "show this web page" tap carries. `Identifiable` so it drives a
/// `.sheet(item:)` cleanly.
struct WebPage: Identifiable {
    let id = UUID()
    let url: URL
}
