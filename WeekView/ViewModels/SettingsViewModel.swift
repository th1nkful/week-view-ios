import Foundation
import SwiftUI
import EventKit

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var selectedCalendarIds: Set<String> = []
    @Published var selectedReminderListIds: Set<String> = []
    @Published var showCompletedReminders: Bool = false
    @Published var availableCalendars: [EKCalendar] = []
    @Published var availableReminderLists: [EKCalendar] = []
    
    private let eventStore = EKEventStore()
    private let selectedCalendarsKey = "selectedCalendarIds"
    private let selectedReminderListsKey = "selectedReminderListIds"
    private let showCompletedRemindersKey = "showCompletedReminders"
    
    init() {
        loadSettings()
    }
    
    func loadAvailableCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
        availableReminderLists = eventStore.calendars(for: .reminder)
        
        // If no calendars are selected, select all by default
        if selectedCalendarIds.isEmpty {
            selectedCalendarIds = Set(availableCalendars.map { $0.calendarIdentifier })
        }
        
        // If no reminder lists are selected, select all by default
        if selectedReminderListIds.isEmpty {
            selectedReminderListIds = Set(availableReminderLists.map { $0.calendarIdentifier })
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
    
    func toggleShowCompletedReminders() {
        showCompletedReminders.toggle()
        saveSettings()
    }
    
    private func loadSettings() {
        if let savedCalendarIds = UserDefaults.standard.array(forKey: selectedCalendarsKey) as? [String] {
            selectedCalendarIds = Set(savedCalendarIds)
        }
        
        if let savedReminderListIds = UserDefaults.standard.array(forKey: selectedReminderListsKey) as? [String] {
            selectedReminderListIds = Set(savedReminderListIds)
        }
        
        showCompletedReminders = UserDefaults.standard.bool(forKey: showCompletedRemindersKey)
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(Array(selectedCalendarIds), forKey: selectedCalendarsKey)
        UserDefaults.standard.set(Array(selectedReminderListIds), forKey: selectedReminderListsKey)
        UserDefaults.standard.set(showCompletedReminders, forKey: showCompletedRemindersKey)
    }
}
