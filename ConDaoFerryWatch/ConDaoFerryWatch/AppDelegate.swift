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
        } else {
            showMainWindow()
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
