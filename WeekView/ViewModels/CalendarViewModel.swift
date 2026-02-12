import Foundation
import EventKit

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var events: [EventModel] = []
    @Published var reminders: [ReminderModel] = []
    @Published var hasCalendarAccess = false
    @Published var hasRemindersAccess = false
    
    private let eventStore = EKEventStore()
    
    func requestAccess() async {
        do {
            let calendarAccess = try await eventStore.requestAccess(to: .event)
            hasCalendarAccess = calendarAccess
            
            let remindersAccess = try await eventStore.requestAccess(to: .reminder)
            hasRemindersAccess = remindersAccess
        } catch {
            print("Error requesting access: \(error.localizedDescription)")
        }
    }
    
    func loadEvents(for date: Date) async {
        guard hasCalendarAccess else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )
        
        let ekEvents = eventStore.events(matching: predicate)
        events = ekEvents.map { EventModel(from: $0) }
            .sorted { $0.startDate < $1.startDate }
        
        await loadReminders(for: date)
    }
    
    private func loadReminders(for date: Date) async {
        guard hasRemindersAccess else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForReminders(in: nil)
        
        do {
            let ekReminders = try await eventStore.reminders(matching: predicate)
            
            let filtered = ekReminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else {
                    return false
                }
                return dueDate >= startOfDay && dueDate < endOfDay
            }
            
            reminders = filtered.map { ReminderModel(from: $0) }
                .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
        } catch {
            print("Error loading reminders: \(error.localizedDescription)")
        }
    }
    
    func toggleReminder(_ reminder: ReminderModel) {
        guard hasRemindersAccess else { return }
        
        if let ekReminder = eventStore.calendarItem(withIdentifier: reminder.calendarItemIdentifier) as? EKReminder {
            ekReminder.isCompleted.toggle()
            
            do {
                try eventStore.save(ekReminder, commit: true)
                
                if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                    reminders[index] = ReminderModel(from: ekReminder)
                }
            } catch {
                print("Error toggling reminder: \(error.localizedDescription)")
            }
        }
    }
}
