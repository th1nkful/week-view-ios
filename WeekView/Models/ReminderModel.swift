import Foundation
import SwiftUI
import EventKit

struct ReminderModel: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
    let calendar: EKCalendar
    let calendarItemIdentifier: String
    let calendarColor: Color

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    init(from ekReminder: EKReminder) {
        self.id = ekReminder.calendarItemIdentifier
        self.title = ekReminder.title ?? "Untitled Reminder"
        self.dueDate = ekReminder.dueDateComponents?.date
        self.isCompleted = ekReminder.isCompleted
        self.calendar = ekReminder.calendar
        self.calendarItemIdentifier = ekReminder.calendarItemIdentifier
        self.calendarColor = Color(cgColor: ekReminder.calendar.cgColor)
    }

    var dueDateString: String? {
        guard let dueDate = dueDate else { return nil }
        return Self.timeFormatter.string(from: dueDate)
    }
}
