import SwiftUI

struct ContentView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var weatherViewModel = WeatherViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var selectedDate = Date()
    @State private var showSettings = false

    // Layout constants
    private let headerHeight: CGFloat = 52
    private let weekStripHeight: CGFloat = 76
    private let weekStripTopPadding: CGFloat = 4

    private var weekStripSpacerHeight: CGFloat {
        headerHeight + weekStripHeight + weekStripTopPadding + 8
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Base layer: unified background color
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                // Scroll view with transparent background
                InfiniteDayScrollView(
                    selectedDate: $selectedDate,
                    calendarViewModel: calendarViewModel,
                    settingsViewModel: settingsViewModel,
                    topInset: weekStripSpacerHeight
                )

                // Top layer: single glass panel for header + week strip
                VStack(spacing: 0) {
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
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    WeekStripView(selectedDate: $selectedDate)
                        .padding(.horizontal)
                        .padding(.top, weekStripTopPadding)
                        .padding(.bottom, 8)
                }
                .background {
                    UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16)
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: settingsViewModel)
            }
            .task {
                await calendarViewModel.requestAccess()
                settingsViewModel.loadAvailableCalendars()
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
    @Environment(\.scenePhase) private var scenePhase
    var topInset: CGFloat = 0

    @State private var visibleDates: [Date] = []
    @State private var loadedEvents: [Date: (events: [EventModel], reminders: [ReminderModel])] = [:]
    @State private var isLoadingMoreWeeks = false
    @State private var hasInitializedWithPermissions = false
    @State private var scrollPosition: Date?
    @State private var isUpdatingFromScroll = false

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
                scrollContent
            }
        }
        .background(.clear)
    }

    private var scrollContent: some View {
        ScrollView {
            dayList
        }
        .scrollPosition(id: $scrollPosition)
        .contentMargins(.top, topInset + 8, for: .scrollContent)
        .defaultScrollAnchor(.top)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        .onChange(of: selectedDate) { _, newValue in
            guard !isUpdatingFromScroll else { return }

            if !visibleDates.contains(where: { calendar.isDate($0, inSameDayAs: newValue) }) {
                loadWeek(containing: newValue)
            }

            let target = calendar.startOfDay(for: newValue)
            if scrollPosition != target {
                scrollPosition = target
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue = newValue else { return }

            if let matchingDate = visibleDates.first(where: {
                calendar.startOfDay(for: $0) == newValue
            }) {
                if !calendar.isDate(selectedDate, inSameDayAs: matchingDate) {
                    isUpdatingFromScroll = true
                    selectedDate = matchingDate
                    isUpdatingFromScroll = false
                }
            }
        }
        .onChange(of: calendarViewModel.hasCalendarAccess) { _, newValue in
            if newValue && !hasInitializedWithPermissions {
                hasInitializedWithPermissions = true
                reloadAllVisibleDates()
            }
        }
        .onChange(of: calendarViewModel.hasRemindersAccess) { _, newValue in
            if newValue {
                reloadAllVisibleDates()
            }
        }
        .onChange(of: settingsViewModel.selectedCalendarIds) { _, _ in
            reloadAllVisibleDates()
        }
        .onChange(of: settingsViewModel.selectedReminderListIds) { _, _ in
            reloadAllVisibleDates()
        }
        .onChange(of: settingsViewModel.showCompletedReminders) { _, _ in
            reloadAllVisibleDates()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reloadAllVisibleDates()
            }
        }
    }

    private var dayList: some View {
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
        .scrollTargetLayout()
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
        var allDates: [Date] = []

        // Previous week
        if let prevWeekDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) {
            allDates.append(contentsOf: getWeekDates(for: prevWeekDate))
        }

        // Current week
        allDates.append(contentsOf: getWeekDates(for: selectedDate))

        // Next 2 weeks
        if let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: selectedDate) {
            allDates.append(contentsOf: getWeekDates(for: nextWeekDate))
        }
        if let nextNextWeekDate = calendar.date(byAdding: .day, value: 14, to: selectedDate) {
            allDates.append(contentsOf: getWeekDates(for: nextNextWeekDate))
        }

        visibleDates = allDates
        scrollPosition = calendar.startOfDay(for: selectedDate)

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
            let sortedNewDates = newDates.sorted()

            // Insert at correct position to maintain chronological order
            if let firstNew = sortedNewDates.first,
               let firstExisting = visibleDates.first,
               firstNew < firstExisting {
                visibleDates.insert(contentsOf: sortedNewDates, at: 0)
            } else {
                visibleDates.append(contentsOf: sortedNewDates)
            }

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

        guard let firstDate = visibleDates.first,
              let lastDate = visibleDates.last else { return }

        // Find index of the appearing date
        guard let dateIndex = visibleDates.firstIndex(where: {
            calendar.isDate($0, inSameDayAs: date)
        }) else { return }

        // Load previous week when within 3 days of the start
        if dateIndex < 3 {
            isLoadingMoreWeeks = true
            if let previousWeekDate = calendar.date(byAdding: .day, value: -7, to: firstDate) {
                loadWeek(containing: previousWeekDate)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isLoadingMoreWeeks = false
            }
        }

        // Load next week when within 3 days of the end
        if dateIndex >= visibleDates.count - 3 {
            isLoadingMoreWeeks = true
            if let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: lastDate) {
                loadWeek(containing: nextWeekDate)
            }
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

        // Capture values to avoid property wrapper issues
        let vm: CalendarViewModel = calendarViewModel
        let selectedCals = settingsViewModel.selectedCalendarIds
        let selectedLists = settingsViewModel.selectedReminderListIds
        let showCompleted = settingsViewModel.showCompletedReminders

        let result = await vm.fetchEvents(
            for: dateStart,
            selectedCalendarIds: selectedCals,
            selectedReminderListIds: selectedLists,
            showCompletedReminders: showCompleted
        )
        loadedEvents[dateStart] = result
    }
}

struct DaySection: View {
    let date: Date
    let events: [EventModel]
    let reminders: [ReminderModel]
    let onToggleReminder: (ReminderModel) -> Void

    // Enum to represent either an event or reminder for unified display
    enum TimedItem: Identifiable {
        case event(EventModel)
        case reminder(ReminderModel)

        var id: String {
            switch self {
            case .event(let event):
                return "event_\(event.id)"
            case .reminder(let reminder):
                return "reminder_\(reminder.id)"
            }
        }

        var sortTime: Date? {
            switch self {
            case .event(let event):
                return event.startDate
            case .reminder(let reminder):
                return reminder.dueDate
            }
        }
    }

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

    // Combined items sorted by time
    private var sortedTimedItems: [TimedItem] {
        var items: [TimedItem] = []

        // Add timed events
        for event in timedEvents {
            items.append(.event(event))
        }

        // Add reminders
        for reminder in reminders {
            items.append(.reminder(reminder))
        }

        // Sort by time (events by start time, reminders by due date)
        // Items without a time (nil sortTime) are sorted to the end
        // Use id as secondary sort for stable ordering when times are equal
        return items.sorted { item1, item2 in
            let time1 = item1.sortTime ?? Date.distantFuture
            let time2 = item2.sortTime ?? Date.distantFuture
            if time1 == time2 {
                return item1.id < item2.id
            }
            return time1 < time2
        }
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
                VStack(alignment: .leading, spacing: 8) {
                    if !allDayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(allDayEvents) { event in
                                AllDayEventPillView(event: event)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    // Combined timed events and reminders, sorted by time
                    if !sortedTimedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(sortedTimedItems) { item in
                                switch item {
                                case .event(let event):
                                    EventCardView(event: event)
                                        .padding(.horizontal, 8)
                                case .reminder(let reminder):
                                    ReminderCardView(reminder: reminder) {
                                        onToggleReminder(reminder)
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                }
            }

            Divider()
                .background(Color(uiColor: .separator))
                .padding(.top, 6)
        }
    }
}

#Preview {
    ContentView()
}
