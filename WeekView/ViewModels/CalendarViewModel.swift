import Foundation
import EventKit
import WeatherKit
import CoreLocation

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var events: [EventModel] = []
    @Published var reminders: [ReminderModel] = []
    @Published var hasCalendarAccess = false
    @Published var hasRemindersAccess = false
    @Published var currentWeather: WeatherModel?
    @Published var weatherError: Error?
    
    private let eventStore = EKEventStore()
    private let weatherService = WeatherService.shared
    
    func requestAccess() async {
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                hasCalendarAccess = try await eventStore.requestFullAccessToEvents()
                hasRemindersAccess = try await eventStore.requestFullAccessToReminders()
            } else {
                hasCalendarAccess = try await eventStore.requestAccess(to: .event)
                hasRemindersAccess = try await eventStore.requestAccess(to: .reminder)
            }
        } catch {
            print("Error requesting access: \(error.localizedDescription)")
        }
    }
    
    func loadEvents(for date: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        if hasCalendarAccess {
            let predicate = eventStore.predicateForEvents(
                withStart: startOfDay,
                end: endOfDay,
                calendars: nil
            )
            let ekEvents = eventStore.events(matching: predicate)
            events = ekEvents.map { EventModel(from: $0) }
                .sorted { $0.startDate < $1.startDate }
        } else {
            events = []
        }

        await loadReminders(for: startOfDay)
    }
    
    private func loadReminders(for date: Date) async {
        guard hasRemindersAccess else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: startOfDay,
            ending: endOfDay,
            calendars: nil
        )

        let fetchedReminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        reminders = fetchedReminders.map { ReminderModel(from: $0) }
            .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
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
    
    func fetchEvents(for date: Date) async -> (events: [EventModel], reminders: [ReminderModel]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return ([], [])
        }

        var events: [EventModel] = []
        if hasCalendarAccess {
            let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
            let ekEvents = eventStore.events(matching: predicate)
            events = ekEvents.map { EventModel(from: $0) }.sorted { $0.startDate < $1.startDate }
        }

        var reminders: [ReminderModel] = []
        if hasRemindersAccess {
            let predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: startOfDay, ending: endOfDay, calendars: nil
            )
            let fetched = await withCheckedContinuation { continuation in
                eventStore.fetchReminders(matching: predicate) { r in
                    continuation.resume(returning: r ?? [])
                }
            }
            reminders = fetched.map { ReminderModel(from: $0) }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        }

        return (events, reminders)
    }

    func loadWeather(for location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
            currentWeather = WeatherModel(from: weather.currentWeather)
            weatherError = nil
        } catch {
            print("Error fetching weather: \(error.localizedDescription)")
            weatherError = error
            currentWeather = nil
        }
    }
}
