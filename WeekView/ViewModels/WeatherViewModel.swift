import Foundation
import WeatherKit
import CoreLocation

@MainActor
class WeatherViewModel: NSObject, ObservableObject {
    @Published var weather: WeatherModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationAndLoadWeather() async {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func loadWeather(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let currentWeather = try await weatherService.weather(for: location).currentWeather
            weather = WeatherModel(from: currentWeather)
        } catch {
            errorMessage = "Unable to load weather"
            print("Error loading weather: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

extension WeatherViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            if currentLocation == nil {
                currentLocation = location
                locationManager.stopUpdatingLocation()
                await loadWeather(for: location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Location unavailable"
            print("Location error: \(error.localizedDescription)")
        }
    }
}
