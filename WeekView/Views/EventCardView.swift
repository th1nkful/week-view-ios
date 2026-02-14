import SwiftUI
import EventKit

struct EventCardView: View {
    let event: EventModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openEventInCalendar()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Rectangle()
                    .fill(event.calendarColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let location = event.simplifiedLocation {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.startTimeString)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text(event.endTimeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private func openEventInCalendar() {
        let urlString = "calshow:\(event.startDate.timeIntervalSinceReferenceDate)"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}

struct AllDayEventPillView: View {
    let event: EventModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openEventInCalendar()
        } label: {
            Text(event.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(event.calendarColor))
        }
        .buttonStyle(.plain)
    }

    private func openEventInCalendar() {
        let urlString = "calshow:\(event.startDate.timeIntervalSinceReferenceDate)"
        if let url = URL(string: urlString) {
            openURL(url)
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
