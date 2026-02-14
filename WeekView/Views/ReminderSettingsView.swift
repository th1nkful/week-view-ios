import SwiftUI

struct ReminderSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                Toggle("Show completed", isOn: $viewModel.showCompletedReminders)
            }

            let groups = viewModel.reminderListsGroupedBySource
            if groups.isEmpty {
                Text("No reminder lists available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.calendars, id: \.calendarIdentifier) { list in
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: list.cgColor))
                                    .frame(width: 12, height: 12)

                                Text(list.title)
                                    .font(.body)

                                Spacer()

                                if viewModel.selectedReminderListIds.contains(list.calendarIdentifier) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleReminderList(list)
                            }
                        }
                    } header: {
                        Text(group.title)
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView(viewModel: SettingsViewModel())
    }
}
