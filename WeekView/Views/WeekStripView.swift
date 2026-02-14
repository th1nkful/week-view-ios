import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDate: Date
    @State private var currentWeekOffset: Int = 0
    @State private var isUpdatingFromScroll: Bool = false

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
        .onChange(of: currentWeekOffset) { _, newValue in
            guard !isUpdatingFromScroll else { return }

            let newWeekDates = getWeekDates(for: newValue)
            let today = Date()
            if newWeekDates.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
                selectedDate = today
            } else if let firstDay = newWeekDates.first {
                selectedDate = firstDay
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            let newWeekOffset = getWeekOffset(for: newValue)
            if newWeekOffset != currentWeekOffset {
                isUpdatingFromScroll = true
                withAnimation {
                    currentWeekOffset = newWeekOffset
                }
                DispatchQueue.main.async {
                    isUpdatingFromScroll = false
                }
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

    private let selectedDayNameOpacity: CGFloat = 0.8

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
                    .foregroundStyle(isSelected ? .white.opacity(selectedDayNameOpacity) : .primary.opacity(0.6))

                Text(Self.dateFormatter.string(from: date))
                    .font(.title3)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
    }
}

#Preview {
    WeekStripView(selectedDate: .constant(Date()))
        .padding()
}
