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
        self.eventIdentifier = ekEvent.eventIdentifier ?? ""
        self.calendarColor = Color(cgColor: ekEvent.calendar.cgColor)
    }
    
    var duration: String {
        if isAllDay {
            return "All Day"
        }
        
        return "\(Self.timeFormatter.string(from: startDate)) - \(Self.timeFormatter.string(from: endDate))"
    }
}
