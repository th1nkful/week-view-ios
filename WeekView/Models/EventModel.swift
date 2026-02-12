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
}
