# Architecture Review: Week View iOS Calendar Viewer

**Date**: 2026-02-12
**Reviewer**: Claude (automated architecture review)
**Scope**: Full codebase review — architecture, code quality, requirements alignment, extensibility

---

## 1. Overall Architecture Assessment

**Verdict: Functional MVP, but structurally unable to meet the stated architecture expectations.**

The app ships the right features — week strip, day view, events, reminders, weather, deep linking, dark mode — and the MVVM folder layout (Models/ViewModels/Views) is correct at a surface level. However, under the hood it is a **shallow MVVM**: ViewModels directly instantiate framework objects (`EKEventStore`, `WeatherService.shared`, `CLLocationManager`) with zero abstraction, no protocols, and no dependency injection. This makes the codebase untestable, un-mockable, and tightly coupled to Apple frameworks in ways that will block widgets, testing, and extensibility.

**What's working well:**
- Clean file organization and naming conventions
- Proper use of `@MainActor` on ViewModels
- Good use of `.task(id: selectedDate)` for reactive date changes in ContentView
- `nonisolated` delegate methods with `Task { @MainActor }` hop in WeatherViewModel
- Models wrap framework types into value-typed structs (partial decoupling)
- Card views are well-composed with calendar color indicators
- Empty state handling in DayView
- Deep linking to Calendar and Reminders apps

**What's not:**
- No service protocol layer — the #1 requirement from "Architecture Expectations"
- No dependency injection anywhere
- Models still hold framework types (`EKCalendar`)
- All errors go to `print()` — no user-facing error UI for calendar failures
- README claims iOS 17 / Swift 5.9 but requirements specify iOS 18 / Swift 6
- No tests, no test infrastructure, no way to add tests without refactoring first

---

## 2. Code Quality Issues and Anti-Patterns

### CRITICAL

| File | Line(s) | Issue |
|------|---------|-------|
| `Models/EventModel.swift` | 12 | **Framework type in model**: `let calendar: EKCalendar` stores a framework reference. Models should be pure value types. Store `calendarName: String` and `calendarColor: Color` instead. |
| `Models/ReminderModel.swift` | 10 | Same issue: `let calendar: EKCalendar`. |
| `ViewModels/CalendarViewModel.swift` | 11 | **Hardcoded dependency**: `private let eventStore = EKEventStore()`. No protocol, no injection. Violates "ViewModels depend on protocols, NOT concrete framework implementations." |
| `ViewModels/WeatherViewModel.swift` | 11-12 | **Hardcoded dependencies**: `WeatherService.shared` and `CLLocationManager()` directly instantiated. Same violation. |
| `ContentView.swift` | 4-5 | **No DI at composition root**: `@StateObject private var calendarViewModel = CalendarViewModel()` — ViewModels are self-constructing with no way to inject dependencies. |
| `ViewModels/CalendarViewModel.swift` | 13-23 | **Error swallows both permissions**: Single `do/catch` for calendar + reminders. If calendar access throws, reminders access is never requested. |
| `ViewModels/CalendarViewModel.swift` | 22, 78, 95 | **`print()` error handling**: All errors go to console only. No published error state. User sees empty data with no explanation. |

### MODERATE

| File | Line(s) | Issue |
|------|---------|-------|
| `ViewModels/WeatherViewModel.swift` | 20-29 | **Misleading `async` function**: `requestLocationAndLoadWeather()` is marked `async` but performs no `await`. It calls synchronous location manager methods. The actual async work happens in a delegate callback. |
| `ViewModels/WeatherViewModel.swift` | 8-9 | **`isLoading` never set to `true` on entry**: Between requesting location and receiving a callback, `isLoading` is `false`, `weather` is `nil`, and `errorMessage` is `nil`. The UI shows **nothing** — not loading, not error, not weather. A blank gap. |
| `Views/WeekStripView.swift` | 34 | **Week hardcoded to start on Sunday**: `weekday - 1` assumes Sunday=1. Should use `Calendar.current.firstWeekday` to respect locale (Monday-start in most of the world). |
| All ViewModels | — | **Uses `ObservableObject` instead of `@Observable`**: For an iOS 18 target, the `@Observable` macro (available since iOS 17) is the recommended approach. It provides finer-grained observation, eliminates the need for `@Published`, and simplifies view code. |
| `Models/ReminderModel.swift` | 23 | **`dueDateComponents?.date` unreliable**: `DateComponents.date` returns `nil` when year/month/day aren't all set. Many reminders only have time components, so this will silently drop due dates. |
| `Views/DayView.swift` | — | **No visual distinction for all-day events**: All-day events and timed events appear in the same list. Best practice is to show all-day events in a pinned section at the top, separate from the time-based list. |

### MINOR

| File | Line(s) | Issue |
|------|---------|-------|
| `EventModel.swift` + `ReminderModel.swift` | 15-18, 14-18 | **Duplicate `timeFormatter`**: Same formatter defined in both models. Should be shared. |
| `Views/EventCardView.swift` | 59-67 | **Preview will crash**: Creates `EKEvent` without a valid calendar assignment — `event.calendar` will be `nil`, and `Color(cgColor:)` will fail. |
| All models | — | **No `Sendable` conformance**: For Swift 6 strict concurrency, value types crossing actor boundaries should be `Sendable`. Models hold `EKCalendar` (not Sendable), which will cause compiler errors under strict concurrency checking. |
| `Views/WeekStripView.swift` | — | **No animations**: Date selection is instant with no transition. |

---

## 3. Missing Error Handling and Edge Cases

### Permission Handling Gaps
- **Calendar/Reminders denied**: `CalendarViewModel` sets `hasCalendarAccess = false` but **no view checks this** to show a "please grant access" message. Users see an empty screen with no call to action.
- **Independent error handling**: Calendar and reminders permissions are in the same `try` block (`CalendarViewModel.swift:13-23`). If calendar throws, reminders are skipped entirely.
- **No Settings deep link**: When permissions are denied, there's no button to open Settings (`UIApplication.openSettingsURLString`).

### Data Freshness
- **No `EKEventStoreChangedNotification`**: If a user adds an event in the Calendar app and returns, this app won't show it. Must observe `EKEventStoreChanged` and reload.
- **No foreground refresh**: No `.onChange(of: scenePhase)` to reload data when the app returns from background.
- **Weather never refreshes**: Weather is fetched once on launch. No periodic refresh or manual retry. Stale data after hours of use.

### Edge Cases
- **Multi-day events**: A 3-day event shows "All Day" on each day with no indication it spans multiple days.
- **Timezone changes**: If the user travels, `Calendar.current` changes but data isn't reloaded.
- **Rapid date selection**: No debouncing on `.task(id: selectedDate)`. Fast swiping through dates fires multiple concurrent `loadEvents` calls. While SwiftUI cancels superseded tasks, the intermediate fetches are wasted work.
- **Empty calendar list**: If a user has no calendars enabled, there's no messaging about it.
- **Deep link failure**: If `calshow:` or `x-apple-reminderkit:` URLs fail to open (possible on simulator or future OS changes), there's no fallback or error message.

---

## 4. Suggestions for Improvement (Prioritized by Impact)

### P0 — Architecture Blockers (must fix for testability and extensibility)

**1. Introduce service protocols and dependency injection**

This is the single highest-impact change. Create:

```swift
protocol CalendarServiceProtocol: Sendable {
    func requestEventAccess() async throws -> Bool
    func requestReminderAccess() async throws -> Bool
    func fetchEvents(startDate: Date, endDate: Date) -> [EKEvent]
    func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder]
    func save(_ reminder: EKReminder, commit: Bool) throws
}

protocol WeatherServiceProtocol: Sendable {
    func weather(for location: CLLocation) async throws -> WeatherModel
}

protocol LocationServiceProtocol {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    var locationStream: AsyncStream<CLLocation> { get }
}
```

ViewModels accept protocols in `init()`. `ContentView` (or an app-level DI container) injects concrete implementations.

**2. Decouple models from EventKit types**

Replace `EKCalendar` properties with extracted value types:

```swift
struct EventModel: Identifiable, Sendable {
    let calendarName: String
    let calendarColor: Color  // extracted at init, no framework ref
    // ... no EKCalendar stored
}
```

**3. Surface errors to the user**

Add `@Published var errorState: ErrorState?` to CalendarViewModel. Show permission-denied banners in ContentView with a "Grant Access" button that deep links to Settings.

### P1 — High Impact (should fix before shipping)

**4. Observe `EKEventStoreChangedNotification`**

React to external calendar changes so the app stays in sync.

**5. Adopt `@Observable` macro**

Replace `ObservableObject` + `@Published` with `@Observable`. Eliminates `@StateObject`/`@ObservedObject` ceremony and improves rendering performance (only re-renders views that read changed properties).

**6. Fix permission requests to be independent**

```swift
func requestAccess() async {
    do { hasCalendarAccess = try await eventStore.requestAccess(to: .event) }
    catch { /* handle */ }

    do { hasRemindersAccess = try await eventStore.requestAccess(to: .reminder) }
    catch { /* handle */ }
}
```

**7. Add foreground refresh via `scenePhase`**

```swift
@Environment(\.scenePhase) var scenePhase
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active { Task { await reload() } }
}
```

**8. Respect locale's first weekday**

Replace `weekday - 1` with `(weekday - calendar.firstWeekday + 7) % 7`.

### P2 — Moderate Impact (should fix for quality)

**9. Fix WeatherViewModel loading state**: Set `isLoading = true` in `requestLocationAndLoadWeather()` so the UI shows a spinner while awaiting location.

**10. Separate all-day events visually**: Pin all-day events in a non-scrolling section above timed events (matching the Fantastical-style inspiration).

**11. Add animations**: Transition on date selection, `.contentTransition(.numericText())` on weather, fade-in on event cards.

**12. Add `Sendable` conformance** to all models for Swift 6 strict concurrency.

### P3 — Polish (nice to have)

**13.** Extract shared `DateFormatter` into a `Formatters` utility type.
**14.** Add haptic feedback (`.sensoryFeedback(.impact, trigger:)`) on reminder toggle.
**15.** Add swipe gestures on the day view to navigate between days.
**16.** Add weather refresh (periodic or on-demand).
**17.** Fix preview providers to use mock data instead of constructing `EKEvent`/`EKReminder` (which crash without valid calendars).

---

## 5. Extensibility Assessment

### Can we add home screen widgets without major refactoring?

**No.** Widget extensions run in a separate process and cannot access `@StateObject` ViewModels. The current architecture has no shared data layer — `EKEventStore` is buried inside `CalendarViewModel`. You'd need to extract a service layer, potentially shared via App Groups, and create widget-specific intent providers. **Estimated refactoring: medium-large.**

### Can we swap in mock data sources for testing?

**No.** Every external dependency (`EKEventStore`, `WeatherService`, `CLLocationManager`) is hardcoded in ViewModels with no protocol abstraction or injection point. There is literally no way to provide test doubles without modifying the ViewModel source code. **This is the #1 structural deficiency.**

### Can ViewModels be unit tested independently?

**No.** Both ViewModels instantiate framework singletons internally. `CalendarViewModel` tests would require a real `EKEventStore` with real calendar permissions. `WeatherViewModel` tests would require real location services and a WeatherKit entitlement. **Unit tests are impossible without the protocol + DI refactor.**

### Hardcoded assumptions limiting future features

| Assumption | Impact |
|------------|--------|
| Week starts on Sunday | Breaks for Monday-start locales (most of the world) |
| Single `EKEventStore` per ViewModel | Prevents shared store for widgets or multi-view |
| No caching layer | Every date change re-fetches everything from EventKit |
| Deep link URLs are inline strings | No centralized routing; hard to update or test |
| No navigation abstraction | Adding screens (event detail, settings) requires ad-hoc navigation |
| `Color(cgColor:)` from `EKCalendar` | Won't work in widget extension (no UIKit colors) |

---

## Summary Scorecard

| Category | Score | Notes |
|----------|-------|-------|
| Feature completeness | 8/10 | All core features present; missing all-day event distinction and error states |
| MVVM structure | 4/10 | Folder structure is right; actual separation is shallow. No protocols, no DI |
| Testability | 1/10 | Cannot test anything without refactoring |
| Error handling | 3/10 | Weather has states; calendar silently fails; permissions not surfaced |
| SwiftUI best practices | 5/10 | Good use of `.task(id:)`, but uses legacy `ObservableObject`, no animations |
| Code quality | 6/10 | Clean, readable, consistent style. Framework coupling and duplicate code hold it back |
| Extensibility | 2/10 | Widget extension, mock data, alternative sources — all blocked |
| Styling/UX | 6/10 | Clean cards, color coding, dark mode. Missing animations, all-day distinction, haptics |
| **Overall** | **4.5/10** | **Good MVP skeleton; needs protocol layer and DI to meet architecture expectations** |

---

## Recommended Next Steps

1. **Introduce `CalendarServiceProtocol` + `WeatherServiceProtocol` + `LocationServiceProtocol`** with concrete implementations and DI via init parameters
2. **Remove `EKCalendar` from models**, extract all needed values at construction time
3. **Add error states to CalendarViewModel** and permission-denied UI in ContentView
4. **Separate permission requests** into independent try/catch blocks
5. **Adopt `@Observable`** macro across ViewModels
6. **Add `EKEventStoreChanged` observation** and `scenePhase` foreground refresh
7. **Fix week start** to respect locale
8. **Add unit tests** for ViewModels using mock service implementations

The single most impactful change is **introducing service protocols with dependency injection**. That one refactor unblocks testability, widget extensions, mock data, and decouples the architecture from Apple frameworks — addressing roughly 60% of the issues found in this review.
