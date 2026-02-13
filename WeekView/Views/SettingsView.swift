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
                
                // Calendar Selection
                Section {
                    if viewModel.availableCalendars.isEmpty {
                        Text("No calendars available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
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
                    }
                } header: {
                    Text("Calendars")
                } footer: {
                    Text("Select which calendars to display")
                }
                
                // Reminder Lists Selection
                Section {
                    if viewModel.availableReminderLists.isEmpty {
                        Text("No reminder lists available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
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
                    }
                } header: {
                    Text("Reminder Lists")
                } footer: {
                    Text("Select which reminder lists to display")
                }
                
                // Reminder Options
                Section {
                    Toggle("Show Completed Reminders", isOn: $viewModel.showCompletedReminders)
                } header: {
                    Text("Reminder Options")
                } footer: {
                    Text("Display reminders that have been marked as complete")
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
