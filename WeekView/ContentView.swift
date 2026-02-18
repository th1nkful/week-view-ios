import SwiftUI

struct ContentView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var weatherViewModel = WeatherViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var selectedDate = Date()
    @State private var showSettings = false
    @State private var isInitialLoading = true

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
                    topInset: weekStripSpacerHeight,
                    onInitialLoadComplete: { isInitialLoading = false }
                )
                .opacity(isInitialLoading ? 0 : 1)

                // Loading screen overlay
                if isInitialLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Top layer: single glass panel for header + week strip
                if !isInitialLoading {
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
    var onInitialLoadComplete: (() -> Void)?

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
                Color.clear
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
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(Array(visibleDates), id: \.self) { date in
                let dateKey = calendar.startOfDay(for: date)
                let eventsForDay = loadedEvents[dateKey]?.events ?? []
                let remindersForDay = loadedEvents[dateKey]?.reminders ?? []

                Section {
                    DaySection(
                        date: date,
                        events: eventsForDay,
                        reminders: remindersForDay,
                        onToggleReminder: { reminder in
                            calendarViewModel.toggleReminder(reminder)
                            Task {
                                await loadEventsForDate(date, forceReload: true)
                            }
                        },
                        showsHeader: false
                    )
                    .id(calendar.startOfDay(for: date))
                    .onAppear {
                        handleDayAppear(date)
                    }
                } header: {
                    DaySectionHeader(date: date)
                }
            }
        }
        .scrollTargetLayout()
    }

    private func reloadAllVisibleDates() {
        Task {
            for date in visibleDates {
                await loadEventsForDate(date, forceReload: true)
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
            // Load events for all visible dates
            for date in visibleDates {
                await loadEventsForDate(date)
            }
            // Signal that initial load is complete on main actor
            await MainActor.run {
                onInitialLoadComplete?()
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

#Preview {
    ContentView()
}
