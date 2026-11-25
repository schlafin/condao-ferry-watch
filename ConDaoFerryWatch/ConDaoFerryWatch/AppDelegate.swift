//
//  AppDelegate.swift
//  ConDaoFerryWatch
//
//  Owns the main window (AppKit gives precise control over when it opens
//  and what closing it does) and implements the two modes:
//
//  - "Show in menu bar" OFF (default): a normal app. Closing the window
//    quits it; it only checks for updates while open.
//  - "Show in menu bar" ON: closing the window keeps the app running with
//    just the menu bar extra (no Dock icon), keeping the forecast current
//    every 30 minutes. It's never running invisibly: if it's running, you
//    see it.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) weak var shared: AppDelegate?

    private var window: NSWindow?

    private var showInMenuBar: Bool {
        UserDefaults.standard.bool(forKey: AppSettings.showInMenuBarKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Only one copy at a time (e.g. the installed app and an Xcode run).
        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        ).filter { $0 != .current }
        if let other = others.first {
            other.activate()
            NSApp.terminate(nil)
            return
        }

        _ = FerryStore.shared   // starts fetching

        // Launched at login in menu-bar mode: start quietly in the menu bar.
        if AppSettings.launchedAtLogin && showInMenuBar {
            NSApp.setActivationPolicy(.accessory)
            startingUp = false
            return
        }
        // Otherwise show the window, unless the app was started by a link (a
        // keyboard HUD key, or the HUD Controller asking for a refresh). The
        // link only arrives after launch, so wait a moment for it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            startingUp = false
            if !startedByLink { showMainWindow() }
        }
    }

    /// True until the app has decided how it started.
    private var startingUp = true
    private var startedByLink = false

    // MARK: - Links (docs/keyboard-hud.md)

    /// condaoferry://home, condaoferry://day/2026-11-26 (opens that day's
    /// detail) and condaoferry://hud/refresh (the HUD Controller asking for a
    /// new schedule: fetch and send without showing anything, then quit if
    /// the app was started only for it).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == HUDSender.app {
            if startingUp { startedByLink = true }
            switch url.host {
            case "hud":
                guard url.path == "/refresh" else { continue }
                let startedForIt = startedByLink && window == nil
                if startedForIt { NSApp.setActivationPolicy(.accessory) }   // no Dock icon
                Task {
                    // Wait for a fetch already under way (the one at launch),
                    // else fetch now. A successful fetch sends the HUD.
                    let store = FerryStore.shared
                    while store.isRefreshing { try? await Task.sleep(for: .milliseconds(100)) }
                    if (store.lastFetched ?? .distantPast) < .now.addingTimeInterval(-60) {
                        await store.refresh()
                    }
                    if startedForIt && window == nil { NSApp.terminate(nil) }
                }
            case "day":
                Navigator.shared.focusDay = url.lastPathComponent
                showMainWindow()
            default:
                showMainWindow()
            }
        }
    }

    /// Clicking the Dock icon with no window open brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { await FerryStore.shared.refresh() }
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)   // Dock icon + app menu
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "Con Dao Ferry Watch"
            window.contentView = NSHostingView(rootView: MainView(store: .shared))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrameAutosaveName("MainWindow")
            if !window.setFrameUsingName("MainWindow") { window.center() }
            self.window = window
        }
        NSApp.unhide(nil)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        Task { await FerryStore.shared.refresh() }
    }

    func windowWillClose(_ notification: Notification) {
        if showInMenuBar {
            NSApp.setActivationPolicy(.accessory)   // keep running, menu bar only
        } else {
            NSApp.terminate(nil)
        }
    }
}
