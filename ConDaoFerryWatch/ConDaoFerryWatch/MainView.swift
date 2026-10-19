//
//  MainView.swift
//  ConDaoFerryWatch
//
//  The main window and the menu bar panel. Design rule (Michael): as
//  little clutter as possible -- few words, few numbers; color and layout
//  carry the meaning. Colors are tuned for dark mode for now.
//

import SwiftUI

// MARK: - Main window

struct MainView: View {
    let store: FerryStore
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Upcoming Departures").font(.title2.bold())
                Spacer()
                if store.isRefreshing { ProgressView().controlSize(.small) }
                Button { Task { await store.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("r")
                .help("Refresh (⌘R)")
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let state = store.state {
                        ForEach(Leg.all, id: \.self) { leg in
                            let deps = state.departures.filter { $0.leg == leg }
                            if !deps.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(deps) { dep in
                                        DepartureRow(departure: dep, isExpanded: expanded.contains(dep.id)) {
                                            if expanded.contains(dep.id) { expanded.remove(dep.id) }
                                            else { expanded.insert(dep.id) }
                                        }
                                    }
                                }
                            }
                        }
                        footer(state)
                    } else if store.lastError == nil {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    if let error = store.lastError {
                        Text("Couldn't fetch the latest forecast: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func footer(_ state: FerryState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.departures.contains(where: \.inClosureWindow) {
                Text("These dates fall in the ferry's typical seasonal closure window. Verify the route is running at taucaotocthanglong.com before booking.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Updated \(Format.updated(state.generatedAt))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - One departure row

private struct DepartureRow: View {
    let departure: Departure
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: toggle) {
                HStack(spacing: 14) {
                    CalendarSquare(departure: departure)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(departure.label).font(.headline)
                        PathBar(departure: departure)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let points = departure.points {
                    PathDetail(points: points, worst: departure.worstWaypoint)
                } else {
                    Text("No per-point detail in this forecast run.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Wall-calendar style date: weekday band (worst-point color) over a blue
/// body with the day number and departure time.
private struct CalendarSquare: View {
    let departure: Departure

    var body: some View {
        VStack(spacing: 0) {
            Text(Format.weekday(departure.depart))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 20)
                .background(Palette.color(for: departure))
            VStack(spacing: 0) {
                Text(Format.dayNumber(departure.depart))
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                Text(Format.time(departure.depart))
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.calendarBlue)
        }
        .frame(width: 78, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

/// The route from start to end, colored point by point and blended
/// smoothly in between.
private struct PathBar: View {
    let departure: Departure

    private var gradient: LinearGradient {
        let points = departure.points ?? []
        guard points.count > 1 else {
            return LinearGradient(colors: [Palette.color(for: departure)], startPoint: .leading, endPoint: .trailing)
        }
        let stops = points.enumerated().map { i, p in
            Gradient.Stop(color: Palette.color(score: p.score),
                          location: Double(i) / Double(points.count - 1))
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        Capsule()
            .fill(gradient)
            .frame(height: 10)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - The drill-down (unchanged in this PR; Michael will redesign it)

private struct PathDetail: View {
    let points: [RoutePoint]
    let worst: Int?

    private var scale: Double { max(points.compactMap(\.score).max() ?? 1, 1.6) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(points) { p in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(p.point == 0 ? "Start" : p.point == points.count - 1 ? "End" : "Point \(p.point)")
                            .frame(width: 52, alignment: .leading)
                        Text(p.eta).monospacedDigit().foregroundStyle(.secondary)
                        if let score = p.score {
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(p.point == worst ? Color.accentColor : Color.secondary.opacity(0.5))
                                    .frame(width: geo.size.width * score / scale)
                            }
                            .frame(height: 8)
                            Text(String(format: "%.2f", score))
                                .monospacedDigit()
                                .fontWeight(p.point == worst ? .bold : .regular)
                                .frame(width: 36, alignment: .trailing)
                        } else {
                            Text("no data").foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .font(.callout)
                    Text(Format.drivers(p))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 60)
                }
            }
        }
    }
}

// MARK: - Menu bar panel (only when "Show in menu bar" is on)

/// A two-row calendar strip, one column per day, so return dates sit
/// between outbound dates:
///     Vung Tau → Con Dao    20      22      24
///     Con Dao → Vung Tau        21      23
/// Click anywhere to open the main window; ✕ quits the app.
struct MenuBarView: View {
    let store: FerryStore
    @Environment(\.dismiss) private var dismiss

    private var days: [Date] {
        let all = store.state?.departures.map { Format.ictCalendar.startOfDay(for: $0.depart) } ?? []
        return Array(Set(all)).sorted()
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
            ForEach(Leg.all, id: \.self) { leg in
                GridRow {
                    Text(Leg.label(leg)).foregroundStyle(.secondary)
                    ForEach(days, id: \.self) { day in
                        if let dep = departure(leg, on: day) {
                            Text(Format.dayNumber(dep.depart))
                                .font(.title3.bold())
                                .monospacedDigit()
                                .foregroundStyle(Palette.color(for: dep))
                                .frame(width: 26)
                        } else {
                            Color.clear.frame(width: 26, height: 1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .fixedSize()
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()   // close the panel, then bring up the main window
            AppDelegate.shared?.showMainWindow()
        }
        .overlay(alignment: .topTrailing) {
            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(8)
            .help("Quit Con Dao Ferry Watch")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await store.refresh() }
        }
    }

    private func departure(_ leg: String, on day: Date) -> Departure? {
        store.state?.departures.first {
            $0.leg == leg && Format.ictCalendar.isDate($0.depart, inSameDayAs: day)
        }
    }
}

// MARK: - Shared bits

private enum Leg {
    static let all = ["VT_TO_CD", "CD_TO_VT"]

    static func label(_ leg: String) -> String {
        leg == "VT_TO_CD" ? "Vung Tau → Con Dao" : "Con Dao → Vung Tau"
    }
}

/// The color scale: a smooth gradient on the score, 0 green → 1 yellow →
/// 2+ red, gray for missing data. A fixed scale on purpose: learn what
/// each shade feels like rather than calibrating thresholds.
enum Palette {
    static let calendarBlue = Color(red: 0.11, green: 0.30, blue: 0.62)

    static func color(score: Double?) -> Color {
        guard let score else { return .gray }
        let t = min(max(score, 0), 2) / 2               // 0 ... 1
        return Color(hue: (1 - t) * 120 / 360,          // 120° green → 60° yellow → 0° red
                     saturation: 0.85, brightness: 0.95)
    }

    static func color(for departure: Departure) -> Color {
        departure.rating == "NO_DATA" ? .gray : color(score: departure.score)
    }
}

private enum Format {
    /// Everything is shown in Vietnam time, whatever zone the Mac is in.
    static let ict = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
    static let ictCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = ict
        return c
    }()

    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = ict
        f.dateFormat = pattern
        return f
    }
    private static let weekdayF = formatter("EEEE")       // Tuesday
    private static let dayF = formatter("d")              // 20
    private static let timeF = formatter("h:mm a")        // 7:30 AM
    private static let updatedF = formatter("EEE d MMM, h:mm a")

    static func weekday(_ d: Date) -> String { weekdayF.string(from: d) }
    static func dayNumber(_ d: Date) -> String { dayF.string(from: d) }
    static func time(_ d: Date) -> String { timeF.string(from: d) }
    static func updated(_ d: Date) -> String { updatedF.string(from: d) }

    /// "swell 0.47 · wind 0.22" (the two biggest contributors) plus the raw inputs.
    static func drivers(_ p: RoutePoint) -> String {
        if let missing = p.missing, !missing.isEmpty {
            return "Missing forecast values: " + missing.joined(separator: ", ")
        }
        guard let parts = p.contributions, let i = p.inputs else { return "" }
        let names = ["swell": "swell", "wind_waves": "chop", "secondary_swell": "2nd swell", "wind": "wind"]
        let top = parts.sorted { $0.value > $1.value }.prefix(2)
            .map { "\(names[$0.key] ?? $0.key) \(String(format: "%.2f", $0.value))" }
            .joined(separator: " · ")
        let raw = String(format: "swell %.2f m @ %.1f s, %.0f° off bow · wind %.0f kt",
                         i.swellM, i.swellPeriodS, i.swellOffBowDeg, i.windKt)
        return "Mostly \(top)  —  \(raw)"
    }
}
