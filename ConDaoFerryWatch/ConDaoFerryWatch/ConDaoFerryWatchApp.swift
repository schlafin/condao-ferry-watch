//
//  ConDaoFerryWatchApp.swift
//  ConDaoFerryWatch
//
//  Created by Michael Schlafly on 18/10/26.
//

import SwiftUI

@main
struct ConDaoFerryWatchApp: App {
    // The main window and the open/close/quit behaviour live in AppDelegate.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = false

    var body: some Scene {
        // ConDaoFerryWatch → Settings… (⌘,)
        Settings {
            SettingsView()
        }

        // Only present when "Show in menu bar" is on.
        MenuBarExtra("Con Dao Ferry Watch", systemImage: "water.waves", isInserted: $showInMenuBar) {
            MenuBarView(store: .shared)
        }
        .menuBarExtraStyle(.window)
    }
}
