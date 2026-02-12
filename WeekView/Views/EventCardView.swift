import SwiftUI
import EventKit

struct EventCardView: View {
    let event: EventModel
    
    var body: some View {
        Button {
            openEventInCalendar()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(event.calendarColor)
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(event.duration)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
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
    
    private func openEventInCalendar() {
        let urlString = "calshow:\(event.startDate.timeIntervalSinceReferenceDate)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    EventCardView(event: EventModel(
        from: {
            let event = EKEvent(eventStore: EKEventStore())
            event.title = "Team Meeting"
            event.startDate = Date()
            event.endDate = Date().addingTimeInterval(3600)
            return event
        }()
    ))
    .padding()
}
