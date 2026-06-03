import AppKit
import Combine
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

    var currentSessionId: UUID?
    var sessionStartDate: Date?

    var elapsedFocusedSeconds: Int {
        guard currentMode == .focus, let start = sessionStartDate else { return 0 }
        return Int(Date().timeIntervalSince(start))
    }

    var showsTimeInNotch: Bool {
        currentMode == .focus && timeRemaining > 0 && !hasCompleted
    }

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.isRunning && self.currentMode == .focus {
                let now = Date()
                let actualDuration = Int(now.timeIntervalSince(self.sessionStartDate ?? now))
                let session = FocusSession(
                    startDate: self.sessionStartDate ?? now,
                    endDate: now,
                    durationSeconds: actualDuration,
                    mode: self.currentMode.rawValue,
                    completed: false
                )
                ProductivityDataStore.shared.saveFocusSession(session)
            }
        }
    }

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
        if isRunning && currentMode == .focus {
            let now = Date()
            let actualDuration = Int(now.timeIntervalSince(sessionStartDate ?? now))
            let session = FocusSession(
                startDate: sessionStartDate ?? now,
                endDate: now,
                durationSeconds: actualDuration,
                mode: currentMode.rawValue,
                completed: false
            )
            ProductivityDataStore.shared.saveFocusSession(session)
        }

        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
        hasCompleted = false
        currentSessionId = nil
        sessionStartDate = nil
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

        if currentMode == .focus {
            currentSessionId = UUID()
            sessionStartDate = Date()
        }

        deadline = Date().addingTimeInterval(TimeInterval(timeRemaining))
        hasCompleted = false
        isRunning = true
        scheduleTimer()
        updateRemainingTime()
    }

    private func pauseTimer() {
        updateRemainingTime()

        if currentMode == .focus, let start = sessionStartDate {
            let actualDuration = Int(Date().timeIntervalSince(start))
            if actualDuration > 0 {
                let session = FocusSession(
                    startDate: start,
                    endDate: Date(),
                    durationSeconds: actualDuration,
                    mode: currentMode.rawValue,
                    completed: false
                )
                ProductivityDataStore.shared.saveFocusSession(session)
            }
        }

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

        if currentMode == .focus, let start = sessionStartDate {
            let session = FocusSession(
                startDate: start,
                endDate: Date(),
                durationSeconds: duration(for: currentMode),
                mode: currentMode.rawValue,
                completed: true
            )
            ProductivityDataStore.shared.saveFocusSession(session)
        }

        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
        timeRemaining = 0
        hasCompleted = true
        currentSessionId = nil
        sessionStartDate = nil

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
