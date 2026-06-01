import Charts
import SwiftUI

struct PomodoroDashboardView: View {
    @ObservedObject private var dataStore = ProductivityDataStore.shared
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 120
    @State private var selectedPeriod: String = "daily"

    var body: some View {
        VStack {
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
            .padding(.horizontal)
        }
    }

    private var dailyView: some View {
        VStack {
            if dataStore.sessionsToday().isEmpty {
                Spacer()
                Text("No sessions yet. Complete a focus session to see your stats.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                let sessions = dataStore.sessionsToday()
                Chart(sessions, id: \.id) { session in
                    BarMark(
                        x: .value("Time", session.startDate, unit: .hour),
                        y: .value("Minutes", session.durationSeconds / 60)
                    )
                    .foregroundStyle(session.completed ? Color.green : Color.orange)
                }
                .chartXAxisLabel("Session start")
                .chartYAxisLabel("Minutes")
                .frame(height: 160)
                .padding()

                let total = dataStore.totalFocusTimeToday()
                let hours = total / 3600
                let mins = (total % 3600) / 60
                let avg = dataStore.averageFocusTimePerSessionToday() / 60
                Text("\(dataStore.sessionsToday().count) sessions · \(hours)h \(mins)m total · \(avg)m avg")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressRingView(
                    progress: total > 0 ? CGFloat(total) / CGFloat(dailyGoal * 60) : 0,
                    label: "Focus goal: \(hours)h \(mins)m / \(dailyGoal)m"
                )
                .frame(width: 100, height: 100)
                .padding()
            }
        }
    }

    private var weeklyView: some View {
        let data = dataStore.focusTimeByDayThisWeek()
        let total = data.reduce(0) { $0 + $1.minutes }

        return VStack {
            if data.allSatisfy({ $0.minutes == 0 }) {
                Spacer()
                Text("No sessions yet. Complete a focus session to see your stats.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(Color.accentColor)

                    RuleMark(
                        y: .value("Goal", Double(dailyGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.6))
                }
                .chartXAxisLabel("Day")
                .chartYAxisLabel("Minutes")
                .frame(height: 160)
                .padding()

                Text("This week: \(total / 60)h \(total % 60)m · \(total / 7)m avg per day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var monthlyView: some View {
        let data = dataStore.focusTimeByDayThisMonth()
        let total = data.reduce(0) { $0 + $1.minutes }

        return VStack {
            if data.allSatisfy({ $0.minutes == 0 }) {
                Spacer()
                Text("No sessions yet. Complete a focus session to see your stats.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(Color.accentColor)

                    RuleMark(
                        y: .value("Goal", Double(dailyGoal))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.red.opacity(0.6))
                }
                .chartXAxisLabel("Day")
                .chartYAxisLabel("Minutes")
                .frame(height: 160)
                .padding()

                let avg = data.filter { $0.minutes > 0 }.map { $0.minutes }.reduce(0, +) / max(data.filter { $0.minutes > 0 }.count, 1)
                Text("This month: \(total / 60)h \(total % 60)m · \(avg)m avg per day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ProgressRingView: View {
    let progress: CGFloat
    let label: String

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
