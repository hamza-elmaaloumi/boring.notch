import SwiftUI

struct WaterLogListView: View {
    @ObservedObject var store: ProductivityDataStore = .shared

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f
    }()

    private func formattedTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date).lowercased()
    }

    private var todayLogs: [WaterLogEntry] {
        Array(store.drinkingEventsToday().prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Drinks")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.6))

            if todayLogs.isEmpty {
                Text("No entries yet")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(todayLogs) { log in
                        HStack(spacing: 4) {
                            Text(formattedTime(log.date))
                                .font(.system(size: 9))
                                .foregroundStyle(Color(white: 0.5))
                                .padding(.trailing, 2)
                            Text("\(log.amountMl)ml")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.247, green: 0.663, blue: 0.988))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.1))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .background(Color(white: 0.08))
        .cornerRadius(8)
        .onReceive(store.$waterLogs) { _ in }
    }
}
