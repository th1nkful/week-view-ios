import SwiftUI

struct WeatherView: View {
    @ObservedObject var viewModel: WeatherViewModel

    var body: some View {
        Group {
            if let weather = viewModel.weather {
                HStack(spacing: 8) {
                    Image(systemName: weather.symbolName)
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.temperatureString)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(weather.condition.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading weather...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            } else if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }
}

#Preview {
    WeatherView(viewModel: WeatherViewModel())
        .padding()
}
