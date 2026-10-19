//
//  FerryStore.swift
//  ConDaoFerryWatch
//
//  Fetches state.json from the public repo every 30 minutes while the app
//  is running (and on demand), and posts a local notification for each
//  event not seen before.
//

import Foundation
import Observation
import UserNotifications

@Observable
final class FerryStore {
    static let shared = FerryStore()

    static let stateURL = URL(string:
        "https://raw.githubusercontent.com/schlafin/condao-ferry-watch/main/state.json")!
    static let refreshInterval: Duration = .seconds(30 * 60)

    private(set) var state: FerryState?
    private(set) var lastError: String?
    private(set) var lastFetched: Date?
    private(set) var isRefreshing = false

    private let seenKey = "seenEventIDs"
    private let notifier = NotificationDelegate()

    private init() {
        UNUserNotificationCenter.current().delegate = notifier
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            while true {
                await refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            // Cache-busting: GitHub's raw-file CDN can keep serving a stale
            // compressed copy long after a new commit (seen 2026-10-19: 18 h
            // old, despite max-age=300). A unique query string skips its cache.
            var components = URLComponents(url: Self.stateURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "t", value: String(Int(Date.now.timeIntervalSince1970)))]
            var request = URLRequest(url: components.url!)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let newState = try decoder.decode(FerryState.self, from: data)
            state = newState
            lastError = nil
            lastFetched = .now
            await postUnseen(newState.events)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func postUnseen(_ events: [Event]) async {
        let seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        for event in events where !seen.contains(event.id) {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default
            let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
        // Event ids only ever appear in one run's file, so remembering the
        // current file's ids is enough -- the list never grows.
        UserDefaults.standard.set(events.map(\.id), forKey: seenKey)
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Show banners even while the app is in front.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Clicking a notification opens the main window.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { AppDelegate.shared?.showMainWindow() }
    }
}
