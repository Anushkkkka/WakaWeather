import SwiftUI

// MARK: - Data models
struct ConfidencePayload: Decodable {
    struct Source: Decodable { let name: String, temp: Double, rain: Double, wind: Double, condition: String }
    struct RangePair: Decodable { let min: Double, max: Double } // we’ll map JSON to this
    let city: String
    let country: String
    let confidence: Double
    let label: String
    let temp_range: RangePair
    let rain_range: RangePair
    let conditions: [String]
    let wind_max: Double
    let severe: Bool
    let alert: String?
    let recommendation: String
    let satellite_url: String
    let sources: [Source]
    let generated_at: String
}

@MainActor
final class ConfidenceVM: ObservableObject {
    @Published var data: ConfidencePayload?
    @Published var isLoading = false
    @Published var error: String?

    // Change this to wherever you run the Python API
    private let endpoint = URL(string:
        "http://127.0.0.1:8000/confidence?city=Suva&lat=-18.1248&lon=178.4501")!


    func load() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let (d, _) = try await URLSession.shared.data(from: endpoint)
            let decoded = try JSONDecoder().decode(ConfidencePayload.self, from: d)
            self.data = decoded
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ConfidenceView: View {
    private let bg = Color("bgcolor")
    @StateObject private var vm = ConfidenceVM()

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let d = vm.data {
                        gauge(d)
                        quickFacts(d)
                        if d.severe { severeBanner(d) }
                        recommendations(d)
                        sourcesList(d)
                        footer(d)
                    } else if vm.isLoading {
                        ProgressView("Calculating confidence…")
                            .padding()
                    } else if let err = vm.error {
                        errorView(err)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .task { await vm.load() }
        .navigationTitle("Confidence")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "gauge.medium")
            Text("Forecast Confidence")
                .font(.system(size: 24, weight: .semibold))
            Spacer()
        }
    }

    private func gauge(_ d: ConfidencePayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(.black.opacity(0.08), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                // Foreground ring
                Circle()
                    .trim(from: 0, to: min(d.confidence/100.0, 1.0))
                    .stroke(angularGradientFor(d.label), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: d.confidence)
                VStack {
                    Text("\(Int(round(d.confidence)))%")
                        .font(.system(size: 40, weight: .bold))
                    Text(d.label)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)

            HStack(spacing: 10) {
                Label(d.city, systemImage: "mappin.and.ellipse")
                Spacer()
                Button {
                    if let url = URL(string: d.satellite_url) { UIApplication.shared.open(url) }
                } label: {
                    Label("Satellite View", systemImage: "dot.radiowaves.left.and.right")
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func quickFacts(_ d: ConfidencePayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            HStack {
                fact("Temp", "\(round1(d.temp_range.min))–\(round1(d.temp_range.max))°C", "thermometer")
                Divider().frame(height: 28)
                fact("Rain", "\(round1(d.rain_range.min))–\(round1(d.rain_range.max)) mm", "cloud.rain")
                Divider().frame(height: 28)
                fact("Wind", "\(round1(d.wind_max)) m/s", "wind")
            }
            .padding(.vertical, 4)

            if !d.conditions.isEmpty {
                Text("Conditions: \(d.conditions.joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func severeBanner(_ d: ConfidencePayload) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(d.alert ?? "Severe weather risk")
                .font(.subheadline)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding()
        .background(Color.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func recommendations(_ d: ConfidencePayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.headline)
            Text(d.recommendation)
        }
        .padding(14)
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sourcesList(_ d: ConfidencePayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.headline)
            ForEach(d.sources, id: \.name) { s in
                HStack {
                    Text(s.name).font(.subheadline).bold()
                    Spacer()
                    Text("\(round1(s.temp))°C, \(round1(s.rain)) mm, \(round1(s.wind)) m/s")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func footer(_ d: ConfidencePayload) -> some View {
        HStack {
            Text("Last updated \(d.generated_at)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await vm.load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func errorView(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
            Text("Couldn’t load confidence")
            Text(err).font(.footnote).foregroundStyle(.secondary)
            Button("Try Again") { Task { await vm.load() } }
        }
        .padding()
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fact(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline)
            }
        }
    }

    private func round1(_ x: Double) -> String { String(format: "%.1f", x) }

    private func angularGradientFor(_ label: String) -> AngularGradient {
        switch label.lowercased() {
        case "high":     return AngularGradient(colors: [.green, .green], center: .center)
        case "moderate": return AngularGradient(colors: [.orange, .orange], center: .center)
        default:         return AngularGradient(colors: [.red, .red], center: .center)
        }
    }
}

struct ConfidenceView_Previews: PreviewProvider {
    static var previews: some View {
        ConfidenceView()
        ConfidenceView().environment(\.colorScheme, .dark)
    }
}

