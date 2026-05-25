import Charts
import SwiftUI

struct WaterDashboardView: View {
    @ObservedObject private var dataStore = ProductivityDataStore.shared
    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    @AppStorage("waterUnit") private var waterUnit: String = "ml"
    @State private var selectedPeriod: String = "daily"

    private let mlPerCup: Double = 236.588

    private func displayMl(_ ml: Int) -> String {
        if waterUnit == "cups" {
            return String(format: "%.1f", Double(ml) / mlPerCup)
        }
        return "\(ml)"
    }

    private func unitLabel() -> String {
        waterUnit
    }

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
        VStack {
            if dataStore.drinkingEventsToday().isEmpty {
                Spacer()
                Text("No water logged yet. Start drinking to see your progress.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                let consumed = dataStore.waterConsumedToday()
                let pct = waterGoal > 0 ? min(CGFloat(consumed) / CGFloat(waterGoal), 1) : 0

                VStack(spacing: 4) {
                    ProgressView(value: pct)
                        .tint(pct >= 1 ? .green : .cyan)
                        .scaleEffect(x: 1, y: 3, anchor: .center)

                    Text("\(displayMl(consumed)) / \(displayMl(waterGoal)) \(unitLabel())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                let events = dataStore.drinkingEventsToday()
                Chart(events, id: \.id) { log in
                    BarMark(
                        x: .value("Time", log.date, unit: .hour),
                        y: .value("Amount", log.amountMl)
                    )
                    .foregroundStyle(Color.cyan.opacity(0.7))
                }
                .chartXAxisLabel("Time")
                .chartYAxisLabel("ml")
                .frame(height: 140)
                .padding()
            }
        }
    }

    private var weeklyView: some View {
        let data = dataStore.waterByDayThisWeek()
        let total = data.reduce(0) { $0 + $1.ml }
        let best = data.max(by: { $0.ml < $1.ml })

        return VStack {
            if data.allSatisfy({ $0.ml == 0 }) {
                Spacer()
                Text("No water logged yet. Start drinking to see your progress.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("ml", item.ml)
                    )
                    .foregroundStyle(Color.cyan.opacity(0.7))

                    RuleMark(
                        y: .value("Goal", Double(waterGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.6))
                }
                .chartXAxisLabel("Day")
                .chartYAxisLabel(unitLabel())
                .frame(height: 160)
                .padding()

                Text("This week: \(displayMl(total)) / \(displayMl(waterGoal * 7)) \(unitLabel()) goal · Best day: \(best?.day ?? "") (\(displayMl(best?.ml ?? 0)) \(unitLabel()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var monthlyView: some View {
        let data = dataStore.waterByDayThisMonth()
        let total = data.reduce(0) { $0 + $1.ml }

        return VStack {
            if data.allSatisfy({ $0.ml == 0 }) {
                Spacer()
                Text("No water logged yet. Start drinking to see your progress.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("ml", item.ml)
                    )
                    .foregroundStyle(Color.cyan.opacity(0.7))

                    RuleMark(
                        y: .value("Goal", Double(waterGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.6))
                }
                .chartXAxisLabel("Day")
                .chartYAxisLabel(unitLabel())
                .frame(height: 160)
                .padding()

                let avg = total / max(data.count, 1)
                Text("This month: \(displayMl(total)) / \(displayMl(waterGoal * data.count)) \(unitLabel()) goal · Average: \(displayMl(avg)) \(unitLabel()) per day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
