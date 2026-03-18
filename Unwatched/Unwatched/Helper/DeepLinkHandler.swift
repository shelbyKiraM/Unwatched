//
//  DeepLinkHandler.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

struct DeepLinkHandler: ViewModifier {
    @Environment(PlayerManager.self) var player
    @State private var shortcutErrorMessage: String?
    @State private var showShortcutErrorAlert = false

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                Log.info("onOpenURL: \(url)")
                handleDeepLink(url: url)
            }
            .alert("shortcutError", isPresented: $showShortcutErrorAlert, presenting: shortcutErrorMessage) { _ in
                Button("installShortcut") {
                    UrlService.open(UrlService.generateChaptersShortcutUrl)
                }
                Button("ok", role: .cancel) { }
            } message: { message in
                Text(message)
            }
    }

    func handleDeepLink(url: URL) {
        handleDisablePip(url: url)
        guard let host = url.host else { return }

        switch host {
        case "shortcut-success":
            break
        case "shortcut-error":
            handleShortcutError(url: url)
        case "play":
            handlePlay(url: url)
        case "queue":
            handleQueue(url: url)
        default:
            break
        }
    }

    func handleDisablePip(url: URL) {
        guard queryValue(named: "disablePip", in: url) == "true" else {
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            player.setPip(false)
        }
    }

    func handleShortcutError(url: URL) {
        guard let errorMessage = queryValue(named: "errorMessage", in: url) else {
            return
        }
        shortcutErrorMessage = errorMessage
        showShortcutErrorAlert = true
    }

    func handlePlay(url: URL) {
        if queryValue(named: "source", in: url) == "safari_extension" {
            guard guardPremium() else { return }
        }

        guard let youtubeUrl = youtubeUrl(from: url) else { return }
        let userInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl]
        NotificationCenter.default.post(name: .watchInUnwatched, object: nil, userInfo: userInfo)
    }

    func handleQueue(url: URL) {
        guard let youtubeUrl = youtubeUrl(from: url) else { return }

        let isNext = queryValue(named: "next", in: url) == "true"
        let queueUserInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl, "next": isNext]
        NotificationCenter.default.post(name: .queueInUnwatched, object: nil, userInfo: queueUserInfo)

        guard let xSuccess = queryValue(named: "x-success", in: url),
              let xSuccessURL = URL(string: xSuccess) else {
            return
        }
        UrlService.open(xSuccessURL)
    }

    func youtubeUrl(from url: URL) -> URL? {
        guard let youtubeUrlString = queryValue(named: "url", in: url),
              let youtubeUrl = URL(string: youtubeUrlString) else {
            Log.error("No youtube URL found in deep link: \(url)")
            return nil
        }
        return youtubeUrl
    }

    func queryValue(named name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandler())
    }
}
