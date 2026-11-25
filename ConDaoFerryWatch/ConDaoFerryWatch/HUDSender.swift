//
//  HUDSender.swift
//  ConDaoFerryWatch
//
//  Sends the keyboard HUD to the HUD Controller (docs/keyboard-hud.md; the
//  controller's side: ~/Claude/Projects/hud-controller/docs/PROTOCOL.md).
//  The controller plays it on the keyboard's top row; this app only works
//  out the colours.
//
//  Cells 1-6 = the next six days from tomorrow (Vietnam dates), each in its
//  departure's gradient colour; Monday white (no ferry); no data black;
//  cells 7-14 white. Sent after every fetch and when the setting changes.
//

import AppKit
import Foundation
import Observation

@MainActor @Observable
final class HUDSender {
    static let shared = HUDSender()

    static let controller = URL(string: "http://127.0.0.1:58620")!
    static let app = "condaoferry"
    static let hudID = "outlook"

    var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "hud.send")
            Task { await send() }
        }
    }
    private(set) var status = "Not sent yet"

    private init() {
        enabled = UserDefaults.standard.object(forKey: "hud.send") as? Bool ?? true
    }

    /// Sends the HUD for the current forecast, or removes it when the setting is off.
    func send() async {
        do {
            if enabled {
                guard let state = FerryStore.shared.state else { status = "No forecast yet"; return }
                let hud = Self.hud(state: state, now: .now)
                let body = try JSONSerialization.data(withJSONObject: hud)
                try await request("POST", "huds", body: body)
                status = "Sent (\(Date.now.formatted(date: .omitted, time: .shortened)))"
            } else {
                try await request("DELETE", "huds/\(Self.app)/\(Self.hudID)", body: nil, allowMissing: true)
                status = "Removed from the HUD Controller"
            }
        } catch let error as URLError where [.cannotConnectToHost, .networkConnectionLost, .timedOut].contains(error.code) {
            status = "The HUD Controller isn't running. The app sends again after its next update."
        } catch {
            status = "Couldn't send: \(error.localizedDescription)"
        }
    }

    // MARK: - The HUD

    static let white = "#ffffff"
    static let black = "#000000"

    /// Two moments, today's and tomorrow's, changing at Vietnam midnight. The
    /// schedule ends after tomorrow, so the controller asks for a new one
    /// (condaoferry://hud/refresh) every 6 hours or so.
    static func hud(state: FerryState, now: Date) -> [String: Any] {
        let cal = HUDCalendar.ict
        let today = cal.startOfDay(for: now)
        let moments = (0..<2).map { offset -> [String: Any] in
            let start = cal.date(byAdding: .day, value: offset, to: today)!
            return moment(state: state, from: start)
        }
        let until = cal.date(byAdding: .day, value: 2, to: today)!
        return [
            "app": app,
            "id": hudID,
            "title": "Ferry outlook",
            "until": HUDCalendar.iso(until),
            "refresh": "\(app)://hud/refresh",
            "moments": moments,
        ]
    }

    static func moment(state: FerryState, from start: Date) -> [String: Any] {
        let cal = HUDCalendar.ict
        let home = "\(app)://home"
        var cells = Array(repeating: white, count: 14)
        var links = Array(repeating: home, count: 14)
        for i in 0..<6 {
            let day = cal.date(byAdding: .day, value: i + 1, to: start)!
            if cal.component(.weekday, from: day) == 2 { continue }   // Monday: no ferry, white
            // Both directions run in peak season: show Vung Tau → Con Dao.
            let deps = state.departures.filter { cal.isDate($0.depart, inSameDayAs: day) }
            guard let dep = deps.first(where: { $0.leg == "VT_TO_CD" }) ?? deps.first else {
                cells[i] = black   // beyond the forecast
                continue
            }
            cells[i] = dep.rating == "NO_DATA" ? black : hex(score: dep.score)
            links[i] = "\(app)://day/\(HUDCalendar.dayString(day))"
        }
        return [
            "from": HUDCalendar.iso(start),
            "cells": cells,
            "links": links,
            "note": "Ferry: 6 days from \(HUDCalendar.shortDay(cal.date(byAdding: .day, value: 1, to: start)!))",
        ]
    }

    /// The app's gradient (Palette.color(score:)): hue 120° green at 0, 60°
    /// yellow at 1, 0° red at 2 and above, blended continuously. Full
    /// saturation and brightness, which reads better on a key's LED.
    static func hex(score: Double) -> String {
        let t = min(max(score, 0), 2) / 2
        let hue = (1 - t) * 120            // degrees, 0...120
        // HSV → RGB with s = v = 1, for hue in 0...120.
        let x = 1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1)
        let (r, g) = hue < 60 ? (1.0, x) : (x, 1.0)
        return String(format: "#%02x%02x00", Int((r * 255).rounded()), Int((g * 255).rounded()))
    }

    // MARK: - Talking to the controller

    private func request(_ method: String, _ path: String, body: Data?, allowMissing: Bool = false) async throws {
        var r = URLRequest(url: Self.controller.appendingPathComponent(path), timeoutInterval: 10)
        r.httpMethod = method
        r.httpBody = body
        if body != nil { r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 200 || (allowMissing && code == 404) { return }
        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
        throw NSError(domain: "HUDController", code: code,
                      userInfo: [NSLocalizedDescriptionKey: message ?? "the controller answered \(code)"])
    }
}

/// Vietnam-time dates for the HUD, whatever zone the Mac is in.
enum HUDCalendar {
    static let ict: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }()

    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = ict.timeZone
        f.dateFormat = pattern
        return f
    }
    private static let isoF = formatter("yyyy-MM-dd'T'HH:mm:ssXXX")
    private static let dayF = formatter("yyyy-MM-dd")
    private static let shortF = formatter("EEE d")

    static func iso(_ d: Date) -> String { isoF.string(from: d) }
    static func dayString(_ d: Date) -> String { dayF.string(from: d) }
    static func shortDay(_ d: Date) -> String { shortF.string(from: d) }
    static func day(from string: String) -> Date? { dayF.date(from: string) }
}

/// Which day's detail a link asked for; the main window opens it.
@MainActor @Observable
final class Navigator {
    static let shared = Navigator()
    /// "2026-11-26", cleared once the main window has opened that day.
    var focusDay: String?
}
