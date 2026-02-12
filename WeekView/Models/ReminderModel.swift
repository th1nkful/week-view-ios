import Foundation
import EventKit

struct ReminderModel: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
    let calendar: EKCalendar
    let calendarItemIdentifier: String
    
    init(from ekReminder: EKReminder) {
        self.id = ekReminder.calendarItemIdentifier
        self.title = ekReminder.title ?? "Untitled Reminder"
        self.dueDate = ekReminder.dueDateComponents?.date
        self.isCompleted = ekReminder.isCompleted
        self.calendar = ekReminder.calendar
        self.calendarItemIdentifier = ekReminder.calendarItemIdentifier
    }
    
    var dueDateString: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
    
    var calendarColor: Color {
        Color(cgColor: calendar.cgColor)
    }
}
