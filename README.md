# Week View - iOS Calendar Viewer

A modern iOS calendar viewer app built with SwiftUI, featuring EventKit integration for events and reminders, and WeatherKit for weather information.

## Features

- 📅 **Week Strip Navigation**: Scroll through weeks with an intuitive date picker
- 📆 **Day View**: See all events and reminders for the selected day
- ☀️ **Weather Integration**: Real-time weather information using WeatherKit
- ✅ **Reminder Management**: Toggle completion status for reminders
- 🔗 **Deep Linking**: Tap events/reminders to open them in stock Calendar/Reminders apps
- 🌙 **Dark Mode**: Full support for iOS dark mode
- 🏗️ **MVVM Architecture**: Clean separation of concerns with Model-View-ViewModel pattern

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Capabilities

The app requires the following entitlements:

- **EventKit**: Access to calendar events and reminders
- **WeatherKit**: Real-time weather data
- **Location Services**: Required for weather data

## Project Structure

```
WeekView/
├── WeekViewApp.swift          # App entry point
├── ContentView.swift           # Main view container
├── Models/
│   ├── EventModel.swift        # Event data model
│   ├── ReminderModel.swift     # Reminder data model
│   └── WeatherModel.swift      # Weather data model
├── ViewModels/
│   ├── CalendarViewModel.swift # Calendar & reminders logic
│   └── WeatherViewModel.swift  # Weather data logic
├── Views/
│   ├── WeekStripView.swift     # Week navigation strip
│   ├── DayView.swift           # Day view with scrollable list
│   ├── EventCardView.swift     # Event card component
│   ├── ReminderCardView.swift  # Reminder card component
│   └── WeatherView.swift       # Weather display component
└── Assets.xcassets/            # App assets and icons
```

## Architecture

The app follows the **MVVM (Model-View-ViewModel)** pattern:

- **Models**: Pure data structures representing events, reminders, and weather
- **ViewModels**: Business logic, data fetching, and state management
- **Views**: SwiftUI views for the user interface

## Usage Permissions

The app requests the following permissions:

1. **Calendar Access**: To read and display your calendar events
2. **Reminders Access**: To read and manage your reminders
3. **Location Access**: To provide accurate weather information for your location

## Building the Project

1. Open `WeekView.xcodeproj` in Xcode
2. Select your development team in the project settings
3. Build and run on a simulator or device (iOS 17.0+)

**Note**: WeatherKit requires a valid Apple Developer Program membership to function on device.

## Key Features Explained

### Week Strip Navigation
- Shows 7 days of the current week
- Highlights the selected day
- Automatically updates when selecting dates outside the current week

### Day View
- Displays all events and reminders for the selected day
- Shows time information for each item
- Empty state when no events/reminders exist

### Event & Reminder Cards
- Color-coded based on calendar color
- Tap to open in stock iOS apps
- Reminders show completion status with toggle functionality

### Weather Display
- Shows current temperature and conditions
- Uses SF Symbols for weather icons
- Automatically updates based on device location

## Technologies Used

- **SwiftUI**: Modern declarative UI framework
- **EventKit**: Calendar and reminders integration
- **WeatherKit**: Weather data service
- **CoreLocation**: Location services for weather
- **Combine**: Reactive programming for data flow

## License

See LICENSE file for details.