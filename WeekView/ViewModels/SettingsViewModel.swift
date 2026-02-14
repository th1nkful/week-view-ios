import Foundation
import SwiftUI
import EventKit

struct CalendarSourceGroup: Identifiable {
    let id: String
    let title: String
    let calendars: [EKCalendar]
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var selectedCalendarIds: Set<String> = []
    @Published var selectedReminderListIds: Set<String> = []
    @Published var showCompletedReminders: Bool = false {
        didSet {
            saveSettings()
        }
    }
    @Published var availableCalendars: [EKCalendar] = []
    @Published var availableReminderLists: [EKCalendar] = []

    var calendarsGroupedBySource: [CalendarSourceGroup] {
        Dictionary(grouping: availableCalendars, by: { $0.source.sourceIdentifier })
            .map { CalendarSourceGroup(
                id: $0.key,
                title: $0.value.first?.source.title ?? "",
                calendars: $0.value.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            )}
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var reminderListsGroupedBySource: [CalendarSourceGroup] {
        Dictionary(grouping: availableReminderLists, by: { $0.source.sourceIdentifier })
            .map { CalendarSourceGroup(
                id: $0.key,
                title: $0.value.first?.source.title ?? "",
                calendars: $0.value.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            )}
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private let eventStore = EKEventStore()
    private let selectedCalendarsKey = "selectedCalendarIds"
    private let selectedReminderListsKey = "selectedReminderListIds"
    private let showCompletedRemindersKey = "showCompletedReminders"
    private let hasInitializedKey = "hasInitializedSettings"

    init() {
        loadSettings()
    }

    func loadAvailableCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
        availableReminderLists = eventStore.calendars(for: .reminder)

        // Only auto-select all on first launch, not when user has explicitly deselected all
        let hasInitialized = UserDefaults.standard.bool(forKey: hasInitializedKey)
        if !hasInitialized {
            // First launch - select all calendars and reminder lists by default
            selectedCalendarIds = Set(availableCalendars.map { $0.calendarIdentifier })
            selectedReminderListIds = Set(availableReminderLists.map { $0.calendarIdentifier })
            UserDefaults.standard.set(true, forKey: hasInitializedKey)
            saveSettings()
        }
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        if selectedCalendarIds.contains(calendar.calendarIdentifier) {
            selectedCalendarIds.remove(calendar.calendarIdentifier)
        } else {
            selectedCalendarIds.insert(calendar.calendarIdentifier)
        }
        saveSettings()
    }

    func toggleReminderList(_ list: EKCalendar) {
        if selectedReminderListIds.contains(list.calendarIdentifier) {
            selectedReminderListIds.remove(list.calendarIdentifier)
        } else {
            selectedReminderListIds.insert(list.calendarIdentifier)
        }
        saveSettings()
    }

    private func loadSettings() {
        if let savedCalendarIds = UserDefaults.standard.array(forKey: selectedCalendarsKey) as? [String] {
            selectedCalendarIds = Set(savedCalendarIds)
        }

        if let savedReminderListIds = UserDefaults.standard.array(forKey: selectedReminderListsKey) as? [String] {
            selectedReminderListIds = Set(savedReminderListIds)
        }

        // Load showCompletedReminders - value is already false by default, 
        // and didSet won't trigger on initialization, so this is safe
        showCompletedReminders = UserDefaults.standard.bool(forKey: showCompletedRemindersKey)
    }

    private func saveSettings() {
        UserDefaults.standard.set(Array(selectedCalendarIds), forKey: selectedCalendarsKey)
        UserDefaults.standard.set(Array(selectedReminderListIds), forKey: selectedReminderListsKey)
        UserDefaults.standard.set(showCompletedReminders, forKey: showCompletedRemindersKey)
    }
}
