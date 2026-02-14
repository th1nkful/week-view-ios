import SwiftUI
import EventKit

struct ReminderCardView: View {
    let reminder: ReminderModel
    let onToggle: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openReminderInApp()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Rectangle()
                    .fill(reminder.calendarColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 2) {
                    if let dueDateString = reminder.dueDateString {
                        Text(dueDateString)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    Text(reminder.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .strikethrough(reminder.isCompleted)
                        .multilineTextAlignment(.leading)

                    Text(reminder.listName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onToggle()
                } label: {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(reminder.calendarColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private func openReminderInApp() {
        let urlString = "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}

#Preview {
    ReminderCardView(
        reminder: ReminderModel(
            from: {
                let reminder = EKReminder(eventStore: EKEventStore())
                reminder.title = "Buy groceries"
                var components = DateComponents()
                components.hour = 14
                components.minute = 0
                reminder.dueDateComponents = components
                return reminder
            }()
        ),
        onToggle: {}
    )
    .padding()
}
