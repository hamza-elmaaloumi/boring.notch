import SwiftUI

struct WaterLogListView: View {
    @ObservedObject var store: ProductivityDataStore = .shared

    private var todayLogs: [WaterLogEntry] {
        store.drinkingEventsToday().reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's Drinks")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.6))
                .padding(.bottom, 2)

            if todayLogs.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "drop")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(white: 0.3))
                    Text("No entries yet")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(todayLogs) { log in
                            HStack(spacing: 8) {
                                Text(log.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.5))
                                Text("\(log.amountMl) ml")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.247, green: 0.663, blue: 0.988))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(white: 0.1))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .frame(width: 155)
        .padding(10)
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }
}
