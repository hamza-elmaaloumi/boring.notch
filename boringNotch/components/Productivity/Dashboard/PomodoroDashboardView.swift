import Charts
import SwiftUI

struct PomodoroDashboardView: View {
    @ObservedObject private var dataStore = ProductivityDataStore.shared
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 120
    @State private var selectedPeriod: String = "daily"

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
            if dataStore.sessionsToday().isEmpty {
                emptyState(icon: "clock", message: "Complete a focus session to see your stats.")
            } else {
                let sessions = dataStore.sessionsToday()

                HStack(alignment: .top, spacing: 16) {
                    Chart(sessions, id: \.id) { session in
                        BarMark(
                            x: .value("Time", session.startDate, unit: .hour),
                            y: .value("Minutes", session.durationSeconds / 60)
                        )
                        .cornerRadius(4)
                        .foregroundStyle(session.completed ? Color.green.gradient : Color.orange.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .frame(height: 140)

                    let total = dataStore.totalFocusTimeToday()
                    ProgressRingView(
                        progress: total > 0 ? CGFloat(total) / CGFloat(dailyGoal * 60) : 0,
                        label: "\(dailyGoal)m goal"
                    )
                    .frame(width: 80, height: 80)
                }

                let total = dataStore.totalFocusTimeToday()
                let hours = total / 3600
                let mins = (total % 3600) / 60
                let avg = dataStore.averageFocusTimePerSessionToday() / 60

                statRow(items: [
                    ("\(dataStore.sessionsToday().count)", "Sessions"),
                    ("\(hours)h \(mins)m", "Total"),
                    ("\(avg)m", "Average")
                ])
            }
        }
    }

    private var weeklyView: some View {
        let data = dataStore.focusTimeByDayThisWeek()
        let total = data.reduce(0) { $0 + $1.minutes }
        let avg = total / max(data.count, 1)

        return VStack(spacing: 12) {
            if data.allSatisfy({ $0.minutes == 0 }) {
                emptyState(icon: "calendar", message: "Complete a focus session to see your stats.")
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Minutes", item.minutes)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.accentColor.gradient)

                    RuleMark(
                        y: .value("Goal", Double(dailyGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.5))
                }
                .frame(height: 140)

                statRow(items: [
                    ("\(total / 60)h \(total % 60)m", "Total"),
                    ("\(avg)m", "Avg / day"),
                    ("\(dailyGoal)m", "Daily goal")
                ])
            }
        }
    }

    private var monthlyView: some View {
        let data = dataStore.focusTimeByDayThisMonth()
        let total = data.reduce(0) { $0 + $1.minutes }
        let activeDays = data.filter { $0.minutes > 0 }
        let avg = activeDays.isEmpty ? 0 : activeDays.map { $0.minutes }.reduce(0, +) / activeDays.count

        return VStack(spacing: 12) {
            if data.allSatisfy({ $0.minutes == 0 }) {
                emptyState(icon: "calendar", message: "Complete a focus session to see your stats.")
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Minutes", item.minutes)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.accentColor.gradient)

                    RuleMark(
                        y: .value("Goal", Double(dailyGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.5))
                }
                .frame(height: 140)

                statRow(items: [
                    ("\(total / 60)h \(total % 60)m", "Total"),
                    ("\(avg)m", "Avg / day"),
                    ("\(activeDays.count)", "Active days")
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

struct ProgressRingView: View {
    let progress: CGFloat
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(
                        AngularGradient(colors: [.accentColor, .accentColor.opacity(0.6)], center: .center),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
