import SwiftUI

struct ContentView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var weatherViewModel = WeatherViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var selectedDate = Date()
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // WeatherView hidden - requires paid Apple Developer account
                // WeatherView(viewModel: weatherViewModel)
                //     .padding(.horizontal)
                //     .padding(.top)
                
                // Month and Year Header (left-aligned)
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(selectedDate.formatted(.dateTime.month(.wide)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .textCase(.uppercase)
                        
                        Text(selectedDate.formatted(.dateTime.year()))
                            .font(.title2)
                            .fontWeight(.regular)
                            .foregroundStyle(.red)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = Date()
                    }
                    
                    Spacer()
                    
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                WeekStripView(selectedDate: $selectedDate)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .overlay(alignment: .bottom) {
                        Divider()
                            .background(Color(uiColor: .separator))
                    }
                
                InfiniteDayScrollView(
                    selectedDate: $selectedDate,
                    calendarViewModel: calendarViewModel,
                    settingsViewModel: settingsViewModel
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: settingsViewModel)
            }
            .task {
                await calendarViewModel.requestAccess()
                // Don't load events here - let InfiniteDayScrollView handle it after permissions are granted
                // await weatherViewModel.requestLocationAndLoadWeather()
            }
        }
    }
}

struct InfiniteDayScrollView: View {
    @Binding var selectedDate: Date
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    @State private var visibleDates: [Date] = []
    @State private var loadedEvents: [Date: (events: [EventModel], reminders: [ReminderModel])] = [:]
    @State private var isLoadingMoreWeeks = false
    @State private var hasInitializedWithPermissions = false
    @State private var scrollPosition: Date?
    @State private var isUserScrolling = false
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    
    var body: some View {
        Group {
            if visibleDates.isEmpty {
                VStack {
                    ProgressView("Loading...")
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    loadCurrentWeek()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(visibleDates, id: \.self) { date in
                                let dateKey = calendar.startOfDay(for: date)
                                let eventsForDay = loadedEvents[dateKey]?.events ?? []
                                let remindersForDay = loadedEvents[dateKey]?.reminders ?? []
                                
                                DaySection(
                                    date: date,
                                    events: eventsForDay,
                                    reminders: remindersForDay,
                                    onToggleReminder: { reminder in
                                        calendarViewModel.toggleReminder(reminder)
                                        // Reload events after toggling
                                        Task {
                                            await loadEventsForDate(date, forceReload: true)
                                        }
                                    }
                                )
                                .id(calendar.startOfDay(for: date))
                                .onAppear {
                                    handleDayAppear(date)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .scrollPosition(id: $scrollPosition)
                    .onAppear {
                        // Scroll to today when the view first appears
                        scrollPosition = calendar.startOfDay(for: selectedDate)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(calendar.startOfDay(for: selectedDate))
                            }
                        }
                    }
                    .onChange(of: selectedDate) { oldValue, newValue in
                        // Only update scroll position if not already scrolling (user tapped a day)
                        guard !isUserScrolling else { return }
                        
                        // Check if the selected date is in the visible range
                        if !visibleDates.contains(where: { calendar.isDate($0, inSameDayAs: newValue) }) {
                            // Load the week containing the new date
                            loadWeek(containing: newValue)
                        }
                        
                        // Scroll to the selected date
                        scrollPosition = calendar.startOfDay(for: newValue)
                        Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            withAnimation {
                                proxy.scrollTo(calendar.startOfDay(for: newValue))
                            }
                        }
                    }
                    .onChange(of: scrollPosition) { oldValue, newValue in
                        // Update selected date when user scrolls
                        guard let newValue = newValue else { return }
                        
                        isUserScrolling = true
                        
                        // Find the date that matches the scroll position
                        if let matchingDate = visibleDates.first(where: { 
                            calendar.startOfDay(for: $0) == newValue 
                        }) {
                            if !calendar.isDate(selectedDate, inSameDayAs: matchingDate) {
                                selectedDate = matchingDate
                            }
                        }
                        
                        // Reset the scrolling flag after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isUserScrolling = false
                        }
                    }
                    .onChange(of: calendarViewModel.hasCalendarAccess) { oldValue, newValue in
                        if newValue && !hasInitializedWithPermissions {
                            hasInitializedWithPermissions = true
                            reloadAllVisibleDates()
                        }
                    }
                    .onChange(
                        of: (
                            settingsViewModel.selectedCalendarIds,
                            settingsViewModel.selectedReminderListIds,
                            settingsViewModel.showCompletedReminders
                        )
                    ) { _, _ in
                        reloadAllVisibleDates()
                    }
                }
            }
        }
    }
    
    private func reloadAllVisibleDates() {
        Task {
            // Clear cached events and reload all visible dates
            loadedEvents.removeAll()
            for date in visibleDates {
                await loadEventsForDate(date)
            }
        }
    }
    
    private func loadCurrentWeek() {
        let weekDates = getWeekDates(for: selectedDate)
        visibleDates = weekDates

        if let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: selectedDate) {
            let nextWeekDates = getWeekDates(for: nextWeekDate)
            visibleDates.append(contentsOf: nextWeekDates)
        }
        
        // Load events for all loaded weeks
        Task {
            for date in visibleDates {
                await loadEventsForDate(date)
            }
        }
    }
    
    private func loadWeek(containing date: Date) {
        let weekDates = getWeekDates(for: date)

        let newDates = weekDates.filter { weekDate in
            !visibleDates.contains { calendar.isDate($0, inSameDayAs: weekDate) }
        }

        if !newDates.isEmpty {
            // Insert dates in chronological order
            visibleDates.append(contentsOf: newDates)
            visibleDates.sort()
            
            // Load events for the new dates
            Task {
                for weekDate in newDates {
                    await loadEventsForDate(weekDate)
                }
            }
        }
    }
    
    private func handleDayAppear(_ date: Date) {
        let dateStart = calendar.startOfDay(for: date)
        
        // Load events if not already loaded
        if loadedEvents[dateStart] == nil {
            Task {
                await loadEventsForDate(date)
            }
        }
        
        // Prevent concurrent week loading
        guard !isLoadingMoreWeeks else { return }
        
        // Check if we need to load adjacent weeks
        guard let firstDate = visibleDates.first,
              let lastDate = visibleDates.last else { return }
        
        // Only load more weeks when we're actually at the edges
        // If we're viewing the first day, load the previous week
        if calendar.isDate(date, inSameDayAs: firstDate) {
            isLoadingMoreWeeks = true
            if let previousWeekDate = calendar.date(byAdding: .day, value: -7, to: firstDate) {
                loadWeek(containing: previousWeekDate)
            }
            // Small delay to prevent rapid loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isLoadingMoreWeeks = false
            }
        }
        
        // If we're viewing the last day, load the next week
        if calendar.isDate(date, inSameDayAs: lastDate) {
            isLoadingMoreWeeks = true
            if let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: lastDate) {
                loadWeek(containing: nextWeekDate)
            }
            // Small delay to prevent rapid loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isLoadingMoreWeeks = false
            }
        }
    }
    
    private func getWeekDates(for date: Date) -> [Date] {
        let startOfDate = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDate)

        // weekday 1=Sunday, 2=Monday, etc.
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2

        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDate) else {
            return []
        }

        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    private func loadEventsForDate(_ date: Date, forceReload: Bool = false) async {
        let dateStart = calendar.startOfDay(for: date)
        guard forceReload || loadedEvents[dateStart] == nil else { return }

        let result = await calendarViewModel.fetchEvents(
            for: dateStart,
            selectedCalendarIds: settingsViewModel.selectedCalendarIds,
            selectedReminderListIds: settingsViewModel.selectedReminderListIds,
            showCompletedReminders: settingsViewModel.showCompletedReminders
        )
        loadedEvents[dateStart] = result
    }
}

struct DaySection: View {
    let date: Date
    let events: [EventModel]
    let reminders: [ReminderModel]
    let onToggleReminder: (ReminderModel) -> Void
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    private var displayDayName: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "TODAY"
        } else if calendar.isDateInTomorrow(date) {
            return "TOMORROW"
        } else {
            return Self.dayFormatter.string(from: date).uppercased()
        }
    }
    
    private var allDayEvents: [EventModel] {
        events.filter { $0.isAllDay }
    }

    private var timedEvents: [EventModel] {
        events.filter { !$0.isAllDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayDayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .primary)

                Text(Self.dateFormatter.string(from: date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            if events.isEmpty && reminders.isEmpty {
                Text("NO EVENTS OR REMINDERS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    if !allDayEvents.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(allDayEvents) { event in
                                AllDayEventPillView(event: event)
                            }
                        }
                        .padding(.horizontal, 8)
                    }

                    if !timedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(timedEvents) { event in
                                EventCardView(event: event)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }

                    if !reminders.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminders")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)

                            ForEach(reminders) { reminder in
                                ReminderCardView(reminder: reminder) {
                                    onToggleReminder(reminder)
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.top, events.isEmpty ? 0 : 4)
                    }
                }
            }

            Divider()
                .background(Color(uiColor: .separator))
                .padding(.top, 6)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    ContentView()
}
