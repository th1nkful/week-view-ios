import SwiftUI

struct ContentView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var weatherViewModel = WeatherViewModel()
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeatherView(viewModel: weatherViewModel)
                    .padding(.horizontal)
                    .padding(.top)
                
                WeekStripView(selectedDate: $selectedDate)
                    .padding(.horizontal)
                
                DayView(
                    selectedDate: selectedDate,
                    events: calendarViewModel.events,
                    reminders: calendarViewModel.reminders,
                    onToggleReminder: { reminder in
                        calendarViewModel.toggleReminder(reminder)
                    }
                )
            }
            .navigationTitle("Week View")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await calendarViewModel.requestAccess()
                await calendarViewModel.loadEvents(for: selectedDate)
                await weatherViewModel.requestLocationAndLoadWeather()
            }
            .task(id: selectedDate) {
                await calendarViewModel.loadEvents(for: selectedDate)
            }
        }
    }
}

#Preview {
    ContentView()
}
