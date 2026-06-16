import SwiftUI

struct PomodoroTimerView: View {
    @AppStorage("pomodoroFocus") private var pomodoroFocus: Int = 25
    @AppStorage("pomodoroShortBreak") private var pomodoroShortBreak: Int = 5
    @AppStorage("pomodoroLongBreak") private var pomodoroLongBreak: Int = 15

    @ObservedObject private var timerStore = PomodoroTimerStore.shared

    private var modeBinding: Binding<PomodoroTimerStore.Mode> {
        Binding(
            get: { timerStore.currentMode },
            set: { timerStore.selectMode($0) }
        )
    }

    private var timeString: String {
        let minutes = timerStore.timeRemaining / 60
        let seconds = timerStore.timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var todaySummaryText: some View {
        let saved = ProductivityDataStore.shared.totalFocusTimeToday()
        let live = timerStore.elapsedFocusedSeconds
        let total = saved + live
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let accent = Color.red
        return Group {
            if hours > 0 {
                Text("Today: ") + Text("\(hours)h \(minutes)m").foregroundColor(accent) + Text(" focused")
            } else {
                Text("Today: ") + Text("\(minutes)m").foregroundColor(accent) + Text(" focused")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: modeBinding) {
                ForEach(PomodoroTimerStore.Mode.allCases, id: \.self) { mode in
                    Image(systemName: mode.iconName).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 10)
            .frame(maxWidth: 210)
            .frame(maxWidth: .infinity)

            Text(timeString)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .monospacedDigit()

            todaySummaryText

            HStack(spacing: 14) {
                Button(action: timerStore.toggleTimer) {
                    Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: timerStore.resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            timerStore.configureDurations(
                focus: pomodoroFocus,
                shortBreak: pomodoroShortBreak,
                longBreak: pomodoroLongBreak
            )
            timerStore.refreshState()
        }
        .onChange(of: pomodoroFocus) { _, _ in
            timerStore.configureDurations(
                focus: pomodoroFocus,
                shortBreak: pomodoroShortBreak,
                longBreak: pomodoroLongBreak
            )
            if timerStore.currentMode == .focus {
                timerStore.resetTimer()
            }
        }
        .onChange(of: pomodoroShortBreak) { _, _ in
            timerStore.configureDurations(
                focus: pomodoroFocus,
                shortBreak: pomodoroShortBreak,
                longBreak: pomodoroLongBreak
            )
            if timerStore.currentMode == .shortBreak {
                timerStore.resetTimer()
            }
        }
        .onChange(of: pomodoroLongBreak) { _, _ in
            timerStore.configureDurations(
                focus: pomodoroFocus,
                shortBreak: pomodoroShortBreak,
                longBreak: pomodoroLongBreak
            )
            if timerStore.currentMode == .longBreak {
                timerStore.resetTimer()
            }
        }
    }
}
