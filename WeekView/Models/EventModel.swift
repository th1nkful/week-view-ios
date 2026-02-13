import Foundation
import SwiftUI
import EventKit

struct EventModel: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendar: EKCalendar
    let eventIdentifier: String
    let calendarColor: Color
    let location: String?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    init(from ekEvent: EKEvent) {
        self.id = ekEvent.calendarItemIdentifier
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendar = ekEvent.calendar
        self.eventIdentifier = ekEvent.calendarItemIdentifier
        self.calendarColor = Color(cgColor: ekEvent.calendar.cgColor)
        let loc = ekEvent.location
        self.location = (loc != nil && !loc!.isEmpty) ? loc : nil
    }

    var duration: String {
        if isAllDay {
            return "All Day"
        }

        return "\(Self.timeFormatter.string(from: startDate)) - \(Self.timeFormatter.string(from: endDate))"
    }

    var startTimeString: String {
        Self.timeFormatter.string(from: startDate)
    }

    var endTimeString: String {
        Self.timeFormatter.string(from: endDate)
    }
    
    var simplifiedLocation: String? {
        guard let location = location else { return nil }
        
        // Check for well-known virtual meeting providers
        let lowercased = location.lowercased()
        
        // Zoom
        if lowercased.contains("zoom.us") {
            return "Zoom"
        }
        
        // Google Meet
        if lowercased.contains("meet.google.com") {
            return "Google Meet"
        }
        
        // Microsoft Teams
        if lowercased.contains("teams.microsoft.com") || lowercased.contains("teams.live.com") {
            return "Microsoft Teams"
        }
        
        // Slack
        if lowercased.contains("slack.com/") && (lowercased.contains("/huddle") || lowercased.contains("/call")) {
            return "Slack"
        }
        
        // Check if it's a URL
        if let url = URL(string: location), 
           let host = url.host?.lowercased() {
            // Remove www. prefix
            let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            return domain
        }
        
        // Return original location if it's not a URL
        return location
    }
}
