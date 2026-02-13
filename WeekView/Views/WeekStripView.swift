import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDate: Date
    @State private var currentWeekOffset: Int = 0
    @State private var isUpdatingFromScroll: Bool = false
    
    private let weekTransitionDelay: TimeInterval = 0.3
    private let flagResetDelay: TimeInterval = 0.1
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    
    private var weekDates: [Date] {
        getWeekDates(for: currentWeekOffset)
    }
    
    var body: some View {
        TabView(selection: $currentWeekOffset) {
            ForEach(-52...52, id: \.self) { weekOffset in
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(getWeekDates(for: weekOffset), id: \.self) { date in
                            DayButton(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                            ) {
                                selectedDate = date
                            }
                            .frame(width: geometry.size.width / 7)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .tag(weekOffset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 76)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
        .onChange(of: currentWeekOffset) { oldValue, newValue in
            // Only update selectedDate if the user swiped the week (not from scroll)
            guard !isUpdatingFromScroll else {
                // Reset the flag after a short delay to handle the update
                DispatchQueue.main.asyncAfter(deadline: .now() + flagResetDelay) {
                    isUpdatingFromScroll = false
                }
                return
            }
            
            // Delay the date selection to make the transition smoother
            DispatchQueue.main.asyncAfter(deadline: .now() + weekTransitionDelay) {
                // When week changes, select appropriate day
                let newWeekDates = getWeekDates(for: newValue)
                
                // Check if current week contains today
                let today = Date()
                if newWeekDates.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
                    // Current week - select today
                    selectedDate = today
                } else if let firstDay = newWeekDates.first {
                    // Other week - select first day (Monday)
                    selectedDate = firstDay
                }
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Update week offset when date is selected from elsewhere (like scrolling)
            let newWeekOffset = getWeekOffset(for: newValue)
            if newWeekOffset != currentWeekOffset {
                isUpdatingFromScroll = true
                currentWeekOffset = newWeekOffset
            }
        }
        .onAppear {
            // Initialize to current week
            currentWeekOffset = getWeekOffset(for: selectedDate)
        }
    }
    
    private func getWeekDates(for weekOffset: Int) -> [Date] {
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        // weekday: 1=Sunday, 2=Monday, etc.
        let weekday = calendar.component(.weekday, from: startOfToday)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2

        guard let startOfCurrentWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfToday),
              let startOfTargetWeek = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfCurrentWeek) else {
            return []
        }

        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfTargetWeek)
        }
    }
    
    private func getWeekOffset(for date: Date) -> Int {
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let startOfDate = calendar.startOfDay(for: date)
        
        // Get the start of the week containing today (Monday)
        let todayWeekday = calendar.component(.weekday, from: startOfToday)
        let todayDaysFromMonday = todayWeekday == 1 ? 6 : todayWeekday - 2
        
        guard let startOfCurrentWeek = calendar.date(byAdding: .day, value: -todayDaysFromMonday, to: startOfToday) else {
            return 0
        }
        
        // Get the start of the week containing the target date (Monday)
        let dateWeekday = calendar.component(.weekday, from: startOfDate)
        let dateDaysFromMonday = dateWeekday == 1 ? 6 : dateWeekday - 2
        
        guard let startOfDateWeek = calendar.date(byAdding: .day, value: -dateDaysFromMonday, to: startOfDate) else {
            return 0
        }
        
        // Calculate the difference in weeks
        let components = calendar.dateComponents([.weekOfYear], from: startOfCurrentWeek, to: startOfDateWeek)
        return components.weekOfYear ?? 0
    }
}

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    private var capitalizedDayName: String {
        Self.dayFormatter.string(from: date).uppercased()
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(capitalizedDayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(Self.dateFormatter.string(from: date))
                    .font(.title3)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

#Preview {
    WeekStripView(selectedDate: .constant(Date()))
        .padding()
}
