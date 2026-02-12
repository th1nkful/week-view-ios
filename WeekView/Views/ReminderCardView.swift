import SwiftUI
import EventKit

struct ReminderCardView: View {
    let reminder: ReminderModel
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            openReminderInApp()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(reminder.calendarColor)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .strikethrough(reminder.isCompleted)
                        .multilineTextAlignment(.leading)
                    
                    if let dueDateString = reminder.dueDateString {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(dueDateString)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func openReminderInApp() {
        let urlString = "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
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
