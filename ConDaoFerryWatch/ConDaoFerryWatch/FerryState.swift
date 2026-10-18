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
    let rating: String
    let previousRating: String?
    let inClosureWindow: Bool

    enum CodingKeys: String, CodingKey {
        case id, leg, label, depart, score, rating
        case previousRating = "previous_rating"
        case inClosureWindow = "in_closure_window"
    }
}

/// A rating change chosen by the backend as notification-worthy.
/// `id` is unique per run, so the app posts each event at most once.
struct Event: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
}
