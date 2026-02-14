import SwiftUI

struct CalendarSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            let groups = viewModel.calendarsGroupedBySource
            if groups.isEmpty {
                Text("No calendars available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 12, height: 12)

                                Text(calendar.title)
                                    .font(.body)

                                Spacer()

                                if viewModel.selectedCalendarIds.contains(calendar.calendarIdentifier) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleCalendar(calendar)
                            }
                        }
                    } header: {
                        Text(group.title)
                    }
                }
            }
        }
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CalendarSettingsView(viewModel: SettingsViewModel())
    }
}
