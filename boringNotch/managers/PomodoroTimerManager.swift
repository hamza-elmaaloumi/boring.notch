import AppKit
import Combine
import Foundation
import UserNotifications

enum PomodoroTimerMode: String, CaseIterable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var iconName: String {
        switch self {
        case .focus:
            return "brain"
        case .shortBreak:
            return "cup.and.saucer.fill"
        case .longBreak:
            return "bed.double.fill"
        }
    }
}

@MainActor
final class PomodoroTimerManager: ObservableObject {
    static let shared = PomodoroTimerManager()

    @Published private(set) var currentMode: PomodoroTimerMode = .focus
    @Published private(set) var timeRemaining: Int = 25 * 60
    @Published private(set) var isRunning: Bool = false

    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private enum StorageKeys {
        static let mode = "pomodoroTimer.mode"
        static let running = "pomodoroTimer.running"
        static let endDate = "pomodoroTimer.endDate"
        static let pausedRemaining = "pomodoroTimer.pausedRemaining"
        static let sessionID = "pomodoroTimer.sessionID"
        static let completedSessionID = "pomodoroTimer.completedSessionID"
    }

    private var ticker: Timer?
    private var endDate: Date?
    private var activeSessionID: String?
    private var completedSessionID: String?
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        requestNotificationAuthorization()
        restorePersistedState()

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.syncTimeRemaining(triggerCompletion: true)
                }
            }
            .store(in: &cancellables)
    }

    func setMode(_ mode: PomodoroTimerMode) {
        guard currentMode != mode else { return }
        currentMode = mode
        resetTimer()
    }

    func toggleTimer() {
        isRunning ? pauseTimer() : startTimer()
    }

    func startTimer() {
        guard !isRunning else { return }

        if timeRemaining <= 0 {
            timeRemaining = modeDuration(for: currentMode) * 60
        }

        isRunning = true
        activeSessionID = UUID().uuidString
        completedSessionID = nil
        endDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        startTickerIfNeeded()
        persistState()
    }

    func pauseTimer() {
        guard isRunning else { return }
        syncTimeRemaining(triggerCompletion: false)
        isRunning = false
        endDate = nil
        stopTicker()
        persistState()
    }

    func resetTimer() {
        isRunning = false
        stopTicker()
        endDate = nil
        activeSessionID = nil
        completedSessionID = nil
        timeRemaining = modeDuration(for: currentMode) * 60
        persistState()
    }

    func handleDurationPreferenceChange(for mode: PomodoroTimerMode) {
        if currentMode == mode {
            resetTimer()
        }
    }

    func syncTimeRemaining(triggerCompletion: Bool = false) {
        guard isRunning, let endDate else { return }

        let remaining = Int(ceil(endDate.timeIntervalSinceNow))
        if remaining > 0 {
            timeRemaining = remaining
            return
        }

        timeRemaining = 0
        if triggerCompletion {
            completeCurrentSession()
        }
    }

    private func completeCurrentSession() {
        guard let sessionID = activeSessionID, completedSessionID != sessionID else { return }

        completedSessionID = sessionID
        let finishedMode = currentMode

        isRunning = false
        endDate = nil
        stopTicker()

        playAlarmAndSendNotification(for: finishedMode)
        NotificationCenter.default.post(name: .pomodoroTimerFinished, object: nil, userInfo: ["mode": finishedMode.rawValue])

        switchModeAutomatically(from: finishedMode)
        timeRemaining = modeDuration(for: currentMode) * 60
        activeSessionID = nil

        persistState()
    }

    private func switchModeAutomatically(from finishedMode: PomodoroTimerMode) {
        if finishedMode == .focus {
            currentMode = .shortBreak
        } else {
            currentMode = .focus
        }
    }

    private func modeDuration(for mode: PomodoroTimerMode) -> Int {
        let defaults = UserDefaults.standard

        switch mode {
        case .focus:
            return max(1, defaults.integer(forKey: "pomodoroFocus") == 0 ? 25 : defaults.integer(forKey: "pomodoroFocus"))
        case .shortBreak:
            return max(1, defaults.integer(forKey: "pomodoroShortBreak") == 0 ? 5 : defaults.integer(forKey: "pomodoroShortBreak"))
        case .longBreak:
            return max(1, defaults.integer(forKey: "pomodoroLongBreak") == 0 ? 15 : defaults.integer(forKey: "pomodoroLongBreak"))
        }
    }

    private func startTickerIfNeeded() {
        guard ticker == nil else { return }

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.syncTimeRemaining(triggerCompletion: true)
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func playAlarmAndSendNotification(for mode: PomodoroTimerMode) {
        NSSound(named: "Glass")?.play()

        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Finished"
        content.body = "\(mode.rawValue) session completed."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pomodoro.finished.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            // Best-effort request. If denied, sound and notch auto-open still notify the user.
        }
    }

    private func restorePersistedState() {
        let defaults = UserDefaults.standard

        if let modeRaw = defaults.string(forKey: StorageKeys.mode),
           let restoredMode = PomodoroTimerMode(rawValue: modeRaw)
        {
            currentMode = restoredMode
        }

        activeSessionID = defaults.string(forKey: StorageKeys.sessionID)
        completedSessionID = defaults.string(forKey: StorageKeys.completedSessionID)
        isRunning = defaults.bool(forKey: StorageKeys.running)

        if isRunning {
            let interval = defaults.double(forKey: StorageKeys.endDate)
            if interval > 0 {
                endDate = Date(timeIntervalSince1970: interval)
                syncTimeRemaining(triggerCompletion: true)

                if isRunning {
                    startTickerIfNeeded()
                }
            } else {
                isRunning = false
                timeRemaining = modeDuration(for: currentMode) * 60
            }
        } else {
            let storedRemaining = defaults.integer(forKey: StorageKeys.pausedRemaining)
            if storedRemaining > 0 {
                timeRemaining = storedRemaining
            } else {
                timeRemaining = modeDuration(for: currentMode) * 60
            }
        }
    }

    private func persistState() {
        let defaults = UserDefaults.standard

        defaults.set(currentMode.rawValue, forKey: StorageKeys.mode)
        defaults.set(isRunning, forKey: StorageKeys.running)
        defaults.set(activeSessionID, forKey: StorageKeys.sessionID)
        defaults.set(completedSessionID, forKey: StorageKeys.completedSessionID)

        if let endDate {
            defaults.set(endDate.timeIntervalSince1970, forKey: StorageKeys.endDate)
        } else {
            defaults.removeObject(forKey: StorageKeys.endDate)
        }

        if isRunning {
            defaults.removeObject(forKey: StorageKeys.pausedRemaining)
        } else {
            defaults.set(timeRemaining, forKey: StorageKeys.pausedRemaining)
        }
    }
}
