//
//  FerryState.swift
//  ConDaoFerryWatch
//
//  Mirrors state.json as written by backend/main.py. The app never
//  computes ratings; it only decodes and displays this.
//

import Foundation

struct FerryState: Codable {
    let generatedAt: Date
    let scheduleMode: String
    let departures: [Departure]
    let events: [Event]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case scheduleMode = "schedule_mode"
        case departures, events
    }
}

struct Departure: Codable, Identifiable {
    let id: String
    let leg: String
    let label: String
    let depart: Date
    let score: Double
    let rating: String          // GREEN, YELLOW, RED or NO_DATA
    let previousRating: String?
    let worstWaypoint: Int?
    let inClosureWindow: Bool
    let points: [RoutePoint]?   // optional: older state.json files lack it

    enum CodingKeys: String, CodingKey {
        case id, leg, label, depart, score, rating, points
        case previousRating = "previous_rating"
        case worstWaypoint = "worst_waypoint"
        case inClosureWindow = "in_closure_window"
    }
}

/// One of the 7 forecast points along the route, at the boat's ETA there.
struct RoutePoint: Codable, Identifiable {
    let point: Int
    let eta: String
    let score: Double?                     // nil = forecast data missing
    let contributions: [String: Double]?   // swell, wind_waves, secondary_swell, wind
    let inputs: Inputs?
    let missing: [String]?

    var id: Int { point }

    struct Inputs: Codable {
        let swellM: Double
        let swellPeriodS: Double
        let swellOffBowDeg: Double
        let windWaveM: Double
        let secondarySwellM: Double
        let windKt: Double

        enum CodingKeys: String, CodingKey {
            case swellM = "swell_m"
            case swellPeriodS = "swell_period_s"
            case swellOffBowDeg = "swell_off_bow_deg"
            case windWaveM = "wind_wave_m"
            case secondarySwellM = "secondary_swell_m"
            case windKt = "wind_kt"
        }
    }
}

/// A rating change chosen by the backend as notification-worthy.
/// `id` is unique per run, so the app posts each event at most once.
struct Event: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
}
