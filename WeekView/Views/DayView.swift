import SwiftUI

struct DayView: View {
    let selectedDate: Date
    let events: [EventModel]
    let reminders: [ReminderModel]
    let onToggleReminder: (ReminderModel) -> Void
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.dateFormatter.string(from: selectedDate))
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                if events.isEmpty && reminders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        
                        Text("No events or reminders")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    if !events.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Events")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(events) { event in
                                EventCardView(event: event)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    if !reminders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminders")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(reminders) { reminder in
                                ReminderCardView(reminder: reminder) {
                                    onToggleReminder(reminder)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, events.isEmpty ? 0 : 16)
                    }
                }
            }
            .padding(.bottom)
        }
    }
}

#Preview {
    DayView(
        selectedDate: Date(),
        events: [],
        reminders: [],
        onToggleReminder: { _ in }
    )
}
