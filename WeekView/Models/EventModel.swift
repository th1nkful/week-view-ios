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
    let eventURL: URL?
    let calendarName: String

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
        self.eventURL = ekEvent.url
        self.calendarName = ekEvent.calendar.title
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
        // Check both location and eventURL for meeting providers
        let sources = [location, eventURL?.absoluteString].compactMap { $0 }
        guard !sources.isEmpty else { return nil }

        for source in sources {
            let lowercased = source.lowercased()

            if lowercased.contains("zoom.us") {
                return "Zoom"
            }
            if lowercased.contains("meet.google.com") {
                return "Google Meet"
            }
            if lowercased.contains("teams.microsoft.com") || lowercased.contains("teams.live.com") {
                return "Microsoft Teams"
            }
            if lowercased.contains("slack.com") {
                return "Slack"
            }
        }

        // Fall back to parsing the location string
        guard let location = location else { return nil }
        let lowercased = location.lowercased()

        // Check if it's a URL
        var urlString = location
        if !lowercased.hasPrefix("http://") && !lowercased.hasPrefix("https://") {
            urlString = "https://" + location
        }

        if let url = URL(string: urlString),
           let host = url.host?.lowercased() {
            let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            return domain
        }

        // Return original location if it's not a URL
        return location
    }

    var subtitleText: String {
        simplifiedLocation ?? calendarName
    }
}
