import Charts
import SwiftUI

struct CombinedDashboardView: View {
    @ObservedObject private var dataStore = ProductivityDataStore.shared
    @State private var selectedPeriod: String = "daily"

    var body: some View {
        VStack {
            Picker("", selection: $selectedPeriod) {
                Text("Daily").tag("daily")
                Text("Weekly").tag("weekly")
                Text("Monthly").tag("monthly")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            switch selectedPeriod {
            case "daily":
                dailyView
            case "weekly":
                weeklyView
            case "monthly":
                monthlyView
            default:
                dailyView
            }
        }
    }

    private var dailyView: some View {
        let sessions = dataStore.sessionsToday()
        let waterDuring = dataStore.waterDuringFocusToday()
        let waterOutside = dataStore.waterOutsideFocusToday()

        return ScrollView {
            if sessions.isEmpty && waterDuring == 0 && waterOutside == 0 {
                VStack {
                    Spacer()
                    Text("No data yet. Complete a focus session and log water to see your combined stats.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus sessions today")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Chart(sessions, id: \.id) { session in
                        BarMark(
                            x: .value("Time", session.startDate, unit: .hour),
                            y: .value("Minutes", session.durationSeconds / 60)
                        )
                        .foregroundStyle(session.completed ? Color.green : Color.orange)
                    }
                    .chartYAxisLabel("Minutes")
                    .frame(height: 120)

                    Divider()

                    Text("Water during vs. outside focus")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Chart {
                        BarMark(
                            x: .value("Context", "During focus"),
                            y: .value("ml", waterDuring)
                        )
                        .foregroundStyle(Color.cyan.opacity(0.8))

                        BarMark(
                            x: .value("Context", "Outside focus"),
                            y: .value("ml", waterOutside)
                        )
                        .foregroundStyle(Color.blue.opacity(0.5))
                    }
                    .chartYAxisLabel("ml")
                    .frame(height: 120)

                    Text("Today: \(waterDuring)ml during focus · \(waterOutside)ml outside focus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }

    private var weeklyView: some View {
        let data = dataStore.dailyFocusVsWaterThisWeek()

        return VStack {
            if data.allSatisfy({ $0.focusMinutes == 0 && $0.waterMl == 0 }) {
                Spacer()
                Text("No data yet. Complete focus sessions and log water to see your combined stats.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                Chart(data, id: \.day) { item in
                    PointMark(
                        x: .value("Focus (minutes)", item.focusMinutes),
                        y: .value("Water (ml)", item.waterMl)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(60)
                }
                .chartXAxisLabel("Focus minutes")
                .chartYAxisLabel("Water ml")
                .frame(height: 200)
                .padding()

                Text("Each dot represents one day. See if your most focused days are also your most hydrated days.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private var monthlyView: some View {
        let data = dataStore.dailyFocusVsWaterThisMonth()
        let aboveThreshold = data.filter { $0.focusMinutes > 120 }
        let belowThreshold = data.filter { $0.focusMinutes <= 120 && $0.focusMinutes > 0 }
        let aboveAvgWater = aboveThreshold.isEmpty ? 0 : aboveThreshold.map { $0.waterMl }.reduce(0, +) / aboveThreshold.count
        let belowAvgWater = belowThreshold.isEmpty ? 0 : belowThreshold.map { $0.waterMl }.reduce(0, +) / belowThreshold.count

        return VStack {
            if data.allSatisfy({ $0.focusMinutes == 0 && $0.waterMl == 0 }) {
                Spacer()
                Text("No data yet. Complete focus sessions and log water to see your combined stats.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                Chart(data, id: \.day) { item in
                    PointMark(
                        x: .value("Focus (minutes)", item.focusMinutes),
                        y: .value("Water (ml)", item.waterMl)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(40)
                }
                .chartXAxisLabel("Focus minutes")
                .chartYAxisLabel("Water ml")
                .frame(height: 200)
                .padding()

                if aboveAvgWater > 0 || belowAvgWater > 0 {
                    Text("Days with 2h+ focus averaged \(aboveAvgWater)ml water. Days with less focus averaged \(belowAvgWater)ml water.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
}
