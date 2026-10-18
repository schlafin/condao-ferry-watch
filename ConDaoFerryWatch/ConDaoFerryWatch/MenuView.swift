//
//  MenuView.swift
//  ConDaoFerryWatch
//
//  The dropdown shown when the menu-bar icon is clicked.
//

import SwiftUI

struct MenuView: View {
    let store: FerryStore

    private static let ict = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Con Dao Ferry Watch").font(.headline)

            if let state = store.state {
                if state.departures.isEmpty {
                    Text("No departures in the forecast window.")
                        .foregroundStyle(.secondary)
                }
                ForEach(state.departures) { dep in
                    DepartureRow(departure: dep, timeZone: Self.ict)
                }
                if state.departures.contains(where: \.inClosureWindow) {
                    Text("⚠️ Typical seasonal closure window — verify the route is running before booking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Forecast run: \(state.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if store.lastError == nil {
                ProgressView().controlSize(.small)
            }

            if let error = store.lastError {
                Text("Couldn't fetch: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()
            HStack {
                Button("Refresh") { Task { await store.refresh() } }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 320)
        // Re-fetch each time the dropdown opens. (.task/.onAppear only fire
        // once: macOS keeps this view alive between openings, but its
        // panel becomes the key window every time it's shown.)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await store.refresh() }
        }
    }
}

private struct DepartureRow: View {
    let departure: Departure
    let timeZone: TimeZone

    private var color: Color {
        switch departure.rating {
        case "GREEN": .green
        case "YELLOW": .yellow
        default: .red
        }
    }

    /// Departure times are shown in ICT, whatever time zone the Mac is in.
    private var departureStyle: Date.FormatStyle {
        var style = Date.FormatStyle(locale: Locale(identifier: "en_GB"), timeZone: timeZone)
            .weekday(.abbreviated).day().month(.abbreviated).hour().minute()
        style.timeZone = timeZone
        return style
    }

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text(departure.label)
                Text(departure.depart.formatted(departureStyle) + " (Vietnam time)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(format: "%.2f", departure.score))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
