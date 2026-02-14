import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Calendar & Reminder Sub-Pages
                Section {
                    NavigationLink {
                        CalendarSettingsView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Calendars")
                            Spacer()
                            Text(viewModel.selectedCalendarIds.isEmpty ? "None" : "\(viewModel.selectedCalendarIds.count)")
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
                            Text(viewModel.selectedReminderListIds.isEmpty ? "None" : "\(viewModel.selectedReminderListIds.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // About Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Week View")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("An elegant calendar week view. Built with Claude and Copilot ✨")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
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
