import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // About Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Week View")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("A simple and elegant week calendar view for iOS")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("About")
                }

                // Calendar & Reminder Sub-Pages
                Section {
                    NavigationLink {
                        CalendarSettingsView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Calendars")
                            Spacer()
                            Text("\(viewModel.selectedCalendarIds.count)/\(viewModel.availableCalendars.count)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        ReminderSettingsView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "checklist")
                            Text("Reminders")
                            Spacer()
                            Text("\(viewModel.selectedReminderListIds.count)/\(viewModel.availableReminderLists.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadAvailableCalendars()
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
