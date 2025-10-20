import SwiftUI

// MARK: - Models

enum WarningKind: String {
    case none, info, wind, rain, storm, heat, flood

    var icon: String {
        switch self {
        case .none:  return "checkmark.seal"
        case .info:  return "sun.max"
        case .wind:  return "wind"
        case .rain:  return "cloud.rain"
        case .storm: return "cloud.bolt.rain"
        case .heat:  return "sun.max.trianglebadge.exclamationmark"
        case .flood: return "drop.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .none:  return .green
        case .info:  return .yellow
        case .wind:  return .teal
        case .rain:  return .blue
        case .storm: return .orange
        case .heat:  return .red
        case .flood: return .indigo
        }
    }
}

struct MessageSection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let kind: WarningKind
    let message: String
}

// MARK: - ViewModel

@MainActor
final class MessagesVM: ObservableObject {
    @Published var today: MessageSection
    @Published var tomorrow: MessageSection
    @Published var later: MessageSection

    init() {
        today = MessageSection(
            title: "Today",
            subtitle: nil,
            kind: .info,
            message: "No Warnings right now. Stay safe and enjoy your day! 🌤️"
        )

        tomorrow = MessageSection(
            title: "Tomorrow",
            subtitle: nil,
            kind: .wind,
            message: "Strong Wind Alert: Gusts up to 45 km/h expected from southeast in the afternoon."
        )

        let fmt = DateFormatter(); fmt.dateFormat = "EEEE, d MMMM"
        let dateString = fmt.string(from: Date().addingTimeInterval(60*60*24*3))

        later = MessageSection(
            title: "Later this Week",
            subtitle: dateString,
            kind: .rain,
            message: "Early Warning — Heavy Rain Possible: Forecast models show a potential low-pressure system developing near the southern coast."
        )
    }

    func refresh() async {
        // TODO: connect to FastAPI endpoint if needed
    }
}

// MARK: - Message Card

struct MessageCard: View {
    let section: MessageSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: section.kind.icon)
                        .imageScale(.medium)
                        .foregroundStyle(section.kind.tint)
                }
                Spacer()
            }

            if let sub = section.subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(section.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Main View

struct MessagePageView: View {
    @StateObject private var vm = MessagesVM()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Messages")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.top, 8)

                MessageCard(section: vm.today)
                MessageCard(section: vm.tomorrow)
                MessageCard(section: vm.later)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        // 👇 Your custom background color asset
        .background(
            Color("bgcolor")
                .ignoresSafeArea()
        )
        .navigationTitle("WakaWeather")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.refresh() }
        .refreshable { await vm.refresh() }
    }
}

// MARK: - Preview

struct MessagePageView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView { MessagePageView() }
                .preferredColorScheme(.light)

            NavigationView { MessagePageView() }
                .preferredColorScheme(.dark)
        }
    }
}

