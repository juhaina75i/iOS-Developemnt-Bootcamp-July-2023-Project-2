//
//  ContentView.swift
//  wheatherApp
//
//  Created by Juhaina on 02/02/1445 AH.
//

import SwiftUI

struct WeatherData: Codable {
    var main: Main
    var weather: [Weather]

    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }

    static func decode(data: Data) -> WeatherData? {
        return try? JSONDecoder().decode(WeatherData.self, from: data)
    }
}

struct Main: Codable {
    var temp: Double
}

struct Weather: Codable {
    var description: String
    var icon: String
}

enum WeatherError: Error, LocalizedError {
    case decodingError, serverError, unknown
    
    var errorDescription: String? {
        switch self {
        case .decodingError: return "Failed to decode the data."
        case .serverError: return "Server error. Please try again later."
        case .unknown: return "An unknown error occurred. Please try again."
        }
    }
}

extension Double {
    func toCelsius() -> Double { return self - 273.15 }
    func toFahrenheit() -> Double { return (self - 273.15) * 9/5 + 32 }
}

class APIService {
    private let apiKey = "86f5b45c0e08b6165526f4c120590de7"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    private var cacheKey: String { "weatherCache" }
    private var historyKey: String { "searchHistory" }

    func saveToCache(city: String, data: WeatherData) {
        let key = cacheKey + city
        if let encodedData = data.encode() {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
    }

    func getFromCache(city: String) -> WeatherData? {
        let key = cacheKey + city
        if let data = UserDefaults.standard.data(forKey: key) {
            return WeatherData.decode(data: data)
        }
        return nil
    }

    func saveToHistory(city: String) {
        var cities = getSearchHistory()
        cities.removeAll { $0 == city }
        cities.insert(city, at: 0)
        UserDefaults.standard.set(cities, forKey: historyKey)
    }

    func getSearchHistory() -> [String] {
        return UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }
    
    func getWeather(for city: String, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)?q=\(city)&appid=\(apiKey)") else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                completion(.failure(WeatherError.serverError))
                return
            }
            if let data = data {
                do {
                    let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                    completion(.success(weatherData))
                } catch {
                    completion(.failure(WeatherError.decodingError))
                }
            } else {
                completion(.failure(WeatherError.unknown))
            }
        }.resume()
    }
}

struct ContentView: View {
    @State private var city: String = ""
    @State private var weatherData: WeatherData?
    @State private var errorMessage: String?
    @State private var showingHistory = false

    private let apiService = APIService()

    var searchHistory: [String] {
        apiService.getSearchHistory()
    }

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter city", text: $city, onCommit: fetchWeather)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            if let data = weatherData {
                let tempCelsius = data.main.temp.toCelsius()
                let tempFahrenheit = data.main.temp.toFahrenheit()
                Text(String(format: "%.2f°C | %.2f°F", tempCelsius, tempFahrenheit))
                Image(systemName: iconName(for: data.weather.first?.icon ?? ""))
                    .resizable().scaledToFit().frame(width: 50, height: 50)
                Text(data.weather.first?.description ?? "")
            }

            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }

            Button("Search history") {
                showingHistory.toggle()
            }
            .sheet(isPresented: $showingHistory) {
                SearchHistoryView(cities: searchHistory) { selectedCity in
                    city = selectedCity
                    fetchWeather()
                    showingHistory = false
                }
            }
        }.padding()
    }

    func fetchWeather() {
        if let cachedData = apiService.getFromCache(city: city) {
            self.weatherData = cachedData
            self.errorMessage = nil
            return
        }

        apiService.getWeather(for: city) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self.weatherData = data
                    self.errorMessage = nil
                    self.apiService.saveToCache(city: self.city, data: data)
                    self.apiService.saveToHistory(city: self.city)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    if let weatherError = error as? WeatherError {
                        self.errorMessage = weatherError.errorDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func iconName(for code: String) -> String {
        switch code {
        case "01d", "01n": return "sun.max"
        case "02d", "02n": return "cloud.sun"
        case "03d", "03n", "04d", "04n": return "cloud"
        case "09d", "09n": return "cloud.rain"
        case "10d", "10n": return "cloud.sun.rain"
        case "11d", "11n": return "cloud.bolt"
        case "13d", "13n": return "cloud.snow"
        case "50d", "50n": return "cloud.fog"
        default: return "questionmark.circle"
        }
    }
}

struct SearchHistoryView: View {
    let cities: [String]
    var onSelect: (String) -> Void

    var body: some View {
        List(cities, id: \.self) { city in
            Button(city) {
                onSelect(city)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
