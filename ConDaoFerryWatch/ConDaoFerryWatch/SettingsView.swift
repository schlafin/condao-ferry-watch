//
//  SettingsView.swift
//  ConDaoFerryWatch
//
//  The Settings window (ConDaoFerryWatch menu → Settings…, or ⌘,).
//

import AppKit
import ServiceManagement
import SwiftUI

enum AppSettings {
    static let showInMenuBarKey = "showInMenuBar"

    /// True when macOS started the app as a login item.
    static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

struct SettingsView: View {
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Show in menu bar", isOn: $showInMenuBar)
                Text(showInMenuBar
                     ? "Closing the window keeps the app running in the menu bar, where it keeps the forecast current (checking every 30 minutes)."
                     : "Closing the window quits the app. It only checks for updates while it's open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .disabled(!showInMenuBar)
                Text("Starts the app quietly in the menu bar when you log in. Only available with \"Show in menu bar\" on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)   // no empty space below
        .onChange(of: launchAtLogin) { _, on in setLoginItem(on) }
        .onChange(of: showInMenuBar) { _, on in
            // Without the menu bar there's no background mode to start at login.
            if !on && launchAtLogin { launchAtLogin = false }
        }
    }

    private func setLoginItem(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't change the login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
