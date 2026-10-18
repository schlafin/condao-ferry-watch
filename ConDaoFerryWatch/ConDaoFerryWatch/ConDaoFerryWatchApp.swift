//
//  ConDaoFerryWatchApp.swift
//  ConDaoFerryWatch
//
//  Created by Michael Schlafly on 18/10/26.
//

import SwiftUI

@main
struct ConDaoFerryWatchApp: App {
    @State private var store = FerryStore()

    var body: some Scene {
        // Menu-bar only (no window, no Dock icon -- see "Application is
        // agent" in the target's Info tab).
        MenuBarExtra("Con Dao Ferry Watch", systemImage: "water.waves") {
            MenuView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
