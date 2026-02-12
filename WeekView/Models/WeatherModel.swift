import Foundation
import WeatherKit

struct WeatherModel {
    let temperature: Double
    let condition: String
    let symbolName: String
    
    private static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()
    
    init(from weather: CurrentWeather) {
        self.temperature = weather.temperature.value
        self.condition = weather.condition.description
        self.symbolName = weather.symbolName
    }
    
    var temperatureString: String {
        let measurement = Measurement(value: temperature, unit: UnitTemperature.celsius)
        return Self.measurementFormatter.string(from: measurement)
    }
}
