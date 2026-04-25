import SwiftUI

struct PomodoroTimerView: View {
    @AppStorage("pomodoroFocus") private var pomodoroFocus: Int = 25
    @AppStorage("pomodoroShortBreak") private var pomodoroShortBreak: Int = 5
    @AppStorage("pomodoroLongBreak") private var pomodoroLongBreak: Int = 15

    @ObservedObject private var timerManager = PomodoroTimerManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { timerManager.currentMode },
                set: { timerManager.setMode($0) }
            )) {
                ForEach(PomodoroTimerMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.iconName).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 10)
            .frame(maxWidth: 210)
            .frame(maxWidth: .infinity)
            
            Text(timerManager.timeString)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .monospacedDigit()
            
            HStack(spacing: 14) {
                Button(action: timerManager.toggleTimer) {
                    Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: timerManager.resetTimer) {
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
            timerManager.syncTimeRemaining(triggerCompletion: true)
        }
        .onChange(of: pomodoroFocus) { _, _ in
            timerManager.handleDurationPreferenceChange(for: .focus)
        }
        .onChange(of: pomodoroShortBreak) { _, _ in
            timerManager.handleDurationPreferenceChange(for: .shortBreak)
        }
        .onChange(of: pomodoroLongBreak) { _, _ in
            timerManager.handleDurationPreferenceChange(for: .longBreak)
        }
    }
}
