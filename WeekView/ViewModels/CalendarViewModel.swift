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
    
    func fetchEvents(for date: Date, selectedCalendarIds: Set<String>? = nil, selectedReminderListIds: Set<String>? = nil, showCompletedReminders: Bool = false) async -> (events: [EventModel], reminders: [ReminderModel]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return ([], [])
        }

        var events: [EventModel] = []
        if hasCalendarAccess {
            // If calendars are explicitly selected but the set is empty, show no events
            if let selectedIds = selectedCalendarIds, selectedIds.isEmpty {
                events = []
            } else {
                // Filter calendars if specified
                let calendarsToUse: [EKCalendar]?
                if let selectedIds = selectedCalendarIds {
                    let allCalendars = eventStore.calendars(for: .event)
                    calendarsToUse = allCalendars.filter { selectedIds.contains($0.calendarIdentifier) }
                } else {
                    calendarsToUse = nil
                }
                
                let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendarsToUse)
                let ekEvents = eventStore.events(matching: predicate)
                events = ekEvents.map { EventModel(from: $0) }.sorted { $0.startDate < $1.startDate }
            }
        }

        var reminders: [ReminderModel] = []
        if hasRemindersAccess {
            // If reminder lists are explicitly selected but the set is empty, show no reminders
            if let selectedIds = selectedReminderListIds, selectedIds.isEmpty {
                reminders = []
            } else {
                // Filter reminder lists if specified
                let reminderListsToUse: [EKCalendar]?
                if let selectedIds = selectedReminderListIds {
                    let allReminderLists = eventStore.calendars(for: .reminder)
                    reminderListsToUse = allReminderLists.filter { selectedIds.contains($0.calendarIdentifier) }
                } else {
                    reminderListsToUse = nil
                }
                
                // Fetch reminders based on showCompletedReminders setting
                if showCompletedReminders {
                    // Fetch both incomplete and completed reminders with due dates in the range
                    // Use two separate predicates for efficiency
                    let incompletePredicate = eventStore.predicateForIncompleteReminders(
                        withDueDateStarting: startOfDay, ending: endOfDay, calendars: reminderListsToUse
                    )
                    let completedPredicate = eventStore.predicateForCompletedReminders(
                        withCompletionDateStarting: startOfDay,
                        ending: endOfDay,
                        calendars: reminderListsToUse
                    )
                    
                    // Fetch both types concurrently
                    async let incompleteFetched: [EKReminder] = withCheckedContinuation { continuation in
                        eventStore.fetchReminders(matching: incompletePredicate) { r in
                            continuation.resume(returning: r ?? [])
                        }
                    }
                    async let completedFetched: [EKReminder] = withCheckedContinuation { continuation in
                        eventStore.fetchReminders(matching: completedPredicate) { r in
                            continuation.resume(returning: r ?? [])
                        }
                    }
                    
                    let (incomplete, completed) = await (incompleteFetched, completedFetched)
                    
                    // Combine and deduplicate by identifier
                    var reminderMap: [String: EKReminder] = [:]
                    for reminder in incomplete {
                        reminderMap[reminder.calendarItemIdentifier] = reminder
                    }
                    for reminder in completed {
                        // For completed reminders, prioritize by due date if available
                        if let dueDate = reminder.dueDateComponents?.date,
                           dueDate >= startOfDay && dueDate < endOfDay {
                            reminderMap[reminder.calendarItemIdentifier] = reminder
                        } else if reminderMap[reminder.calendarItemIdentifier] == nil {
                            // Include completed reminders without due dates
                            reminderMap[reminder.calendarItemIdentifier] = reminder
                        }
                    }
                    
                    reminders = reminderMap.values.map { ReminderModel(from: $0) }
                        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                } else {
                    // Fetch only incomplete reminders
                    let predicate = eventStore.predicateForIncompleteReminders(
                        withDueDateStarting: startOfDay, ending: endOfDay, calendars: reminderListsToUse
                    )
                    
                    let fetched = await withCheckedContinuation { continuation in
                        eventStore.fetchReminders(matching: predicate) { r in
                            continuation.resume(returning: r ?? [])
                        }
                    }
                    
                    reminders = fetched.map { ReminderModel(from: $0) }
                        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                }
            }
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
