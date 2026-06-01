import Charts
import SwiftUI

struct WaterDashboardView: View {
    @ObservedObject private var dataStore = ProductivityDataStore.shared
    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    @State private var selectedPeriod: String = "daily"
    @State private var hoveredLog: (time: Date, amount: Int)?
    @State private var hoveredDay: (day: String, ml: Int)?

    private func displayMl(_ ml: Int) -> String {
        return "\(ml)"
    }

    private func unitLabel() -> String {
        "ml"
    }

    var body: some View {
        VStack(spacing: 12) {
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

            Picker("", selection: $selectedPeriod) {
                Text("Daily").tag("daily")
                Text("Weekly").tag("weekly")
                Text("Monthly").tag("monthly")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var dailyView: some View {
        VStack(spacing: 12) {
            if dataStore.drinkingEventsToday().isEmpty {
                emptyState(icon: "drop", message: "Start drinking to see your progress.")
            } else {
                let consumed = dataStore.waterConsumedToday()
                let pct = waterGoal > 0 ? min(CGFloat(consumed) / CGFloat(waterGoal), 1) : 0

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.12))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: pct >= 1 ? [.green, .mint] : [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * pct))
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text("\(displayMl(consumed)) / \(displayMl(waterGoal)) \(unitLabel())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(pct * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                let events = dataStore.drinkingEventsToday()
                Chart(events, id: \.id) { log in
                    BarMark(
                        x: .value("Time", log.date, unit: .hour),
                        y: .value("Amount", log.amountMl)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.cyan.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    let plotFrame = proxy.plotFrame!
                                    let origin = geometry[plotFrame].origin
                                    let xPos = location.x - origin.x
                                    let hoveredDate: Date? = proxy.value(atX: xPos, as: Date.self)
                                    if let date = hoveredDate, let match = events.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                        hoveredLog = (time: match.date, amount: match.amountMl)
                                    }
                                case .ended:
                                    hoveredLog = nil
                                }
                            }
                    }
                }
                .overlay(alignment: .top) {
                    if let h = hoveredLog {
                        Text("\(h.time.formatted(date: .omitted, time: .shortened)) · \(displayMl(h.amount)) \(unitLabel())")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.top, 4)
                    }
                }
                .frame(height: 120)

                statRow(items: [
                    ("\(displayMl(consumed))", "Consumed"),
                    ("\(displayMl(waterGoal))", "Goal"),
                    ("\(events.count)", "Drinks")
                ])
            }
        }
    }

    private var weeklyView: some View {
        let data = dataStore.waterByDayThisWeek()
        let total = data.reduce(0) { $0 + $1.ml }
        let best = data.max(by: { $0.ml < $1.ml })

        return VStack(spacing: 12) {
            if data.allSatisfy({ $0.ml == 0 }) {
                emptyState(icon: "calendar", message: "Start drinking to see your progress.")
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("ml", item.ml)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.cyan.gradient)

                    RuleMark(
                        y: .value("Goal", Double(waterGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.5))
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    let plotFrame = proxy.plotFrame!
                                    let origin = geometry[plotFrame].origin
                                    let xPos = location.x - origin.x
                                    let day: String? = proxy.value(atX: xPos, as: String.self)
                                    if let day, let match = data.first(where: { $0.day == day }) {
                                        hoveredDay = (day: match.day, ml: match.ml)
                                    }
                                case .ended:
                                    hoveredDay = nil
                                }
                            }
                    }
                }
                .overlay(alignment: .top) {
                    if let h = hoveredDay {
                        Text("\(h.day) · \(displayMl(h.ml)) \(unitLabel())")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.top, 4)
                    }
                }
                .frame(height: 120)

                statRow(items: [
                    ("\(displayMl(total))", "Total"),
                    ("\(displayMl(best?.ml ?? 0))", "Best day"),
                    ("\(displayMl(waterGoal * 7))", "Goal")
                ])
            }
        }
    }

    private var monthlyView: some View {
        let data = dataStore.waterByDayThisMonth()
        let total = data.reduce(0) { $0 + $1.ml }
        let avg = total / max(data.count, 1)

        return VStack(spacing: 12) {
            if data.allSatisfy({ $0.ml == 0 }) {
                emptyState(icon: "calendar", message: "Start drinking to see your progress.")
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("ml", item.ml)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.cyan.gradient)

                    RuleMark(
                        y: .value("Goal", Double(waterGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.5))
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    let plotFrame = proxy.plotFrame!
                                    let origin = geometry[plotFrame].origin
                                    let xPos = location.x - origin.x
                                    let day: Int? = proxy.value(atX: xPos, as: Int.self)
                                    if let day, let match = data.first(where: { $0.day == day }) {
                                        hoveredDay = (day: "\(match.day)", ml: match.ml)
                                    }
                                case .ended:
                                    hoveredDay = nil
                                }
                            }
                    }
                }
                .overlay(alignment: .top) {
                    if let h = hoveredDay {
                        Text("\(h.day) · \(displayMl(h.ml)) \(unitLabel())")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.top, 4)
                    }
                }
                .frame(height: 120)

                statRow(items: [
                    ("\(displayMl(total))", "Total"),
                    ("\(displayMl(avg))", "Avg / day"),
                    ("\(displayMl(waterGoal))", "Daily goal")
                ])
            }
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(minHeight: 100)
        .frame(maxWidth: .infinity)
    }

    private func statRow(items: [(value: String, label: String)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.value)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                if item.label != items.last?.label {
                    Divider()
                        .frame(height: 24)
                }
            }
        }
    }
}
