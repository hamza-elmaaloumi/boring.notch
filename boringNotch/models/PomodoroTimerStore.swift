import AppKit
import Combine
import Foundation

@MainActor
final class PomodoroTimerStore: ObservableObject {
    static let shared = PomodoroTimerStore()

    enum Mode: String, CaseIterable, Codable {
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
    @Published var hasActiveSession: Bool = false
    @Published var consecutiveFocusSessions: Int = 0

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

    private struct PersistedState: Codable {
        let currentModeRaw: String
        let timeRemaining: Int
        let deadline: Date?
        let currentSessionId: String?
        let sessionStartDate: Date?
        let hasActiveSession: Bool
        let consecutiveFocusSessions: Int
    }

    private let persistenceKey = "pomodoro_timer_persisted_state"

    private init() {
        restorePersistedState()

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.savePersistedState()
            if self.hasActiveSession && self.currentMode == .focus {
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
        if currentMode == .focus, let start = sessionStartDate {
            let now = Date()
            let actualDuration = Int(now.timeIntervalSince(start))
            if actualDuration > 0 {
                let session = FocusSession(
                    startDate: start,
                    endDate: now,
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
        hasCompleted = false
        hasActiveSession = false
        consecutiveFocusSessions = 0
        currentSessionId = nil
        sessionStartDate = nil
        timeRemaining = duration(for: currentMode)
        clearPersistedState()
    }

    func refreshState() {
        if hasCompleted {
            timeRemaining = 0
            return
        }

        if isRunning {
            updateRemainingTime()
        } else if deadline == nil && !hasActiveSession {
            timeRemaining = duration(for: currentMode)
        } else if deadline != nil {
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
        if sessionStartDate == nil, currentMode == .focus {
            currentSessionId = UUID()
            sessionStartDate = Date()
        }

        if timeRemaining <= 0 {
            timeRemaining = duration(for: currentMode)
        }

        deadline = Date().addingTimeInterval(TimeInterval(timeRemaining))
        hasCompleted = false
        hasActiveSession = true
        isRunning = true
        scheduleTimer()
        updateRemainingTime()
        clearPersistedState()
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
            if !isRunning && !hasActiveSession {
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
            consecutiveFocusSessions += 1
        }

        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
        timeRemaining = 0
        hasCompleted = true
        currentSessionId = nil
        sessionStartDate = nil
        clearPersistedState()

        NSSound(named: "Glass")?.play()
        NSApp.requestUserAttention(.criticalRequest)

        NotificationCenter.default.post(name: .pomodoroTimerDidFinish, object: currentMode.rawValue)

        let next = nextMode()
        currentMode = next
        hasCompleted = false
        timeRemaining = duration(for: next)

        if next == .longBreak {
            consecutiveFocusSessions = 0
        }

        startTimer()
    }

    private func nextMode() -> Mode {
        switch currentMode {
        case .focus:
            return consecutiveFocusSessions % 4 == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    private func savePersistedState() {
        guard isRunning || hasActiveSession else { return }

        let state = PersistedState(
            currentModeRaw: currentMode.rawValue,
            timeRemaining: timeRemaining,
            deadline: deadline,
            currentSessionId: currentSessionId?.uuidString,
            sessionStartDate: sessionStartDate,
            hasActiveSession: hasActiveSession,
            consecutiveFocusSessions: consecutiveFocusSessions
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func restorePersistedState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data),
              let mode = Mode(rawValue: state.currentModeRaw)
        else { return }

        currentMode = mode
        timeRemaining = max(1, state.timeRemaining)
        hasActiveSession = state.hasActiveSession
        consecutiveFocusSessions = state.consecutiveFocusSessions

        if let sessionIdStr = state.currentSessionId, let uuid = UUID(uuidString: sessionIdStr) {
            currentSessionId = uuid
        }
        sessionStartDate = state.sessionStartDate

        clearPersistedState()
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }
}
