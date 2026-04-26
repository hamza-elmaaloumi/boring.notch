import AppKit
import SwiftUI

@MainActor
final class PomodoroTimerStore: ObservableObject {
    static let shared = PomodoroTimerStore()

    enum Mode: String, CaseIterable {
        case focus = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"

        var iconName: String {
            switch self {
            case .focus: return "brain"
            case .shortBreak: return "cup.and.saucer.fill"
            case .longBreak: return "bed.double.fill"
            }
        }
    }

    @Published var currentMode: Mode = .focus
    @Published var timeRemaining: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var hasCompleted: Bool = false

    private var timer: Timer?
    private var deadline: Date?
    private var focusDuration: Int = 25 * 60
    private var shortBreakDuration: Int = 5 * 60
    private var longBreakDuration: Int = 15 * 60

    private init() {}

    func configureDurations(focus: Int, shortBreak: Int, longBreak: Int) {
        focusDuration = max(1, focus) * 60
        shortBreakDuration = max(1, shortBreak) * 60
        longBreakDuration = max(1, longBreak) * 60
        refreshState()
    }

    func selectMode(_ mode: Mode) {
        guard currentMode != mode else { return }
        currentMode = mode
        hasCompleted = false
        resetTimer()
    }

    func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    func resetTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
        hasCompleted = false
        timeRemaining = duration(for: currentMode)
    }

    func refreshState() {
        if hasCompleted {
            timeRemaining = 0
            return
        }

        if isRunning {
            updateRemainingTime()
        } else if deadline == nil {
            timeRemaining = duration(for: currentMode)
        } else {
            updateRemainingTime()
        }
    }

    private func duration(for mode: Mode) -> Int {
        switch mode {
        case .focus: return focusDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }

    private func startTimer() {
        if timeRemaining <= 0 {
            timeRemaining = duration(for: currentMode)
        }

        deadline = Date().addingTimeInterval(TimeInterval(timeRemaining))
        hasCompleted = false
        isRunning = true
        scheduleTimer()
        updateRemainingTime()
    }

    private func pauseTimer() {
        updateRemainingTime()
        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRemainingTime()
            }
        }
    }

    private func updateRemainingTime() {
        guard let deadline = deadline else {
            if !isRunning {
                timeRemaining = duration(for: currentMode)
            }
            return
        }

        let nextRemaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        timeRemaining = nextRemaining

        if nextRemaining == 0 {
            completeTimer()
        }
    }

    private func completeTimer() {
        guard isRunning || deadline != nil else { return }

        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
        timeRemaining = 0
        hasCompleted = true

        NSSound(named: "Glass")?.play()
        NSApp.requestUserAttention(.criticalRequest)

        NotificationCenter.default.post(name: .pomodoroTimerDidFinish, object: currentMode.rawValue)
    }
}

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
