import SwiftUI

struct DaySection: View {
    let date: Date
    let events: [EventModel]
    let reminders: [ReminderModel]
    let onToggleReminder: (ReminderModel) -> Void

    // Enum to represent either an event or reminder for unified display
    enum TimedItem: Identifiable {
        case event(EventModel)
        case reminder(ReminderModel)

        var id: String {
            switch self {
            case .event(let event):
                return "event_\(event.id)"
            case .reminder(let reminder):
                return "reminder_\(reminder.id)"
            }
        }

        var sortTime: Date? {
            switch self {
            case .event(let event):
                return event.startDate
            case .reminder(let reminder):
                return reminder.dueDate
            }
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private var displayDayName: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "TODAY"
        } else if calendar.isDateInTomorrow(date) {
            return "TOMORROW"
        } else {
            return Self.dayFormatter.string(from: date).uppercased()
        }
    }

    private var allDayEvents: [EventModel] {
        events.filter { $0.isAllDay }
    }

    private var timedEvents: [EventModel] {
        events.filter { !$0.isAllDay }
    }

    // Combined items sorted by time
    private var sortedTimedItems: [TimedItem] {
        var items: [TimedItem] = []

        // Add timed events
        for event in timedEvents {
            items.append(.event(event))
        }

        // Add reminders
        for reminder in reminders {
            items.append(.reminder(reminder))
        }

        // Sort by time (events by start time, reminders by due date)
        // Items without a time (nil sortTime) are sorted to the end
        // Use id as secondary sort for stable ordering when times are equal
        return items.sorted { item1, item2 in
            let time1 = item1.sortTime ?? Date.distantFuture
            let time2 = item2.sortTime ?? Date.distantFuture
            if time1 == time2 {
                return item1.id < item2.id
            }
            return time1 < time2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayDayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .primary)

                Text(Self.dateFormatter.string(from: date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            if events.isEmpty && reminders.isEmpty {
                Text("NO EVENTS OR REMINDERS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !allDayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(allDayEvents) { event in
                                AllDayEventPillView(event: event)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    // Combined timed events and reminders, sorted by time
                    if !sortedTimedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(sortedTimedItems) { item in
                                switch item {
                                case .event(let event):
                                    EventCardView(event: event)
                                        .padding(.horizontal, 8)
                                case .reminder(let reminder):
                                    ReminderCardView(reminder: reminder) {
                                        onToggleReminder(reminder)
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                }
            }

            Divider()
                .background(Color(uiColor: .separator))
                .padding(.top, 6)
        }
    }
}
