import SwiftUI

struct WaterLogListView: View {
    @ObservedObject var store: ProductivityDataStore = .shared

    private var todayLogs: [WaterLogEntry] {
        Array(store.drinkingEventsToday().reversed().prefix(5))
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
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(todayLogs) { log in
                            HStack(spacing: 4) {
                                Text(log.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(white: 0.5))
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
        }
        .frame(width: 80)
        .padding(6)
        .background(Color(white: 0.08))
        .cornerRadius(8)
    }
}
