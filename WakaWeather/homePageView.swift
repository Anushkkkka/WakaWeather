import SwiftUI

// MARK: - Models
struct Hour: Identifiable {
    let id = UUID()
    let time: String
    let temp: String
    let symbol: String   // SF Symbol name
}

// MARK: - Home Page
struct homePageView: View {
    // Colors
    private let bg = Color("bgcolor")                  // from Assets
    private let card = Color.white.opacity(0.65)
    private let text = Color.black.opacity(0.9)
    private let subtle = Color.black.opacity(0.6)

    // State
    @State private var showSettings = false

    // Sample hourly data
    private let hours: [Hour] = [
        .init(time: "2 pm", temp: "24°", symbol: "sun.max"),
        .init(time: "3 pm", temp: "25°", symbol: "sun.max"),
        .init(time: "4 pm", temp: "25°", symbol: "sun.max"),
        .init(time: "5 pm", temp: "24°", symbol: "sun.max"),
        .init(time: "6 pm", temp: "22°", symbol: "cloud"),
        .init(time: "7 pm", temp: "20°", symbol: "cloud"),
        .init(time: "8 pm", temp: "18°", symbol: "moon")
    ]

    var body: some View {
        NavigationStack
       {
        
        ZStack {
            bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    // Header
                    HStack {
                        // Hamburger: quick actions + open settings sheet
                        Menu {
                            Button("Settings") { showSettings = true }
                            Button("Language") { showSettings = true }
                            Button("Dark / Light Mode") { showSettings = true }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }

                        Spacer()
                        Text("WakaWeather")
                            .font(.system(size: 24, weight: .semibold))
                        Spacer()
                        NavigationLink (destination: ChatView()) {
                            Image(systemName: "text.bubble")
                        }
                    }
                    .foregroundStyle(text)
                    .padding(.top, 8)
                    .sheet(isPresented: $showSettings) {
                        SettingsSheet()
                    }

                    // Search
                    SearchBar()

                    // Title
                    Text("Home")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(text)
                        .padding(.top, 4)

                    // Main weather card
                    WeatherCard(card: card, text: text, subtle: subtle)

                    // Hourly header
                    HStack {
                        Text("Hourly")
                            .font(.headline)
                            .foregroundStyle(text)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(subtle)
                    }

                    // Hourly row
                    HourlyRow(hours: hours, chipBackground: card, text: text, subtle: subtle)

                    // Warnings section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Warnings")
                            .font(.headline)
                            .foregroundStyle(text)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("No warnings right now. Stay safe and enjoy your day! 🌤️")
                                .foregroundStyle(text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Components

private struct SearchBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Text("Search").foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "mic.fill").foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.06))
        )
    }
}

private struct WeatherCard: View {
    let card: Color
    let text: Color
    let subtle: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("Suva")
                    .font(.system(size: 32, weight: .semibold))
                    .italic()
                    .foregroundStyle(text)

                Spacer()

                Text("Wed 22 Oct")
                    .font(.subheadline)
                    .foregroundStyle(subtle)
            }

            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.yellow, .blue)
                        .font(.system(size: 44))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sunny")
                            .font(.headline)
                            .foregroundStyle(text)

                        HStack(spacing: 8) {
                            Image(systemName: "wind")
                            Text("22 km/h")
                        }
                        .font(.subheadline)
                        .foregroundStyle(subtle)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("25°C")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(text)

                    HStack(spacing: 6) {
                        Text("/")
                            .font(.title3)
                            .foregroundStyle(subtle)
                        Text("16°C")
                            .font(.headline)
                            .foregroundStyle(subtle)
                    }
                }
            }
        }
        .padding(16)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HourlyRow: View {
    let hours: [Hour]
    let chipBackground: Color
    let text: Color
    let subtle: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(hours) { hour in
                    VStack(spacing: 6) {
                        Image(systemName: hour.symbol)
                            .font(.system(size: 20))
                            .foregroundStyle(text)
                        Text(hour.temp)
                            .font(.subheadline)
                            .foregroundStyle(text)
                        Text(hour.time)
                            .font(.caption)
                            .foregroundStyle(subtle)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Settings Sheet
private struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("appLanguage") private var appLanguage = "English"

    private let languages = ["English", "Fijian", "Samoan", "Tongan", "Tok Pisin"]

    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
                
                Section("Language") {
                    Picker("Language", selection: $appLanguage) {
                        ForEach(languages, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("WakaWeather").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    }
}

// MARK: - Preview
struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            homePageView()
            homePageView().environment(\.colorScheme, .dark)
        }
    }
    
}
