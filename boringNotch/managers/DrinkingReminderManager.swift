import AppKit
import Combine
import Defaults
import Foundation

@MainActor
class DrinkingReminderManager: ObservableObject {
    static let shared = DrinkingReminderManager()
    
    @Published var isEnabled: Bool {
        didSet {
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }
    
    @Published var intervalMinutes: Int = 96
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        isEnabled = false
        setupBindings()
    }
    
    private func setupBindings() {
        $intervalMinutes
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, self.isEnabled else { return }
                self.restartTimer()
            }
            .store(in: &cancellables)
    }
    
    private func start() {
        guard isEnabled else { return }
        scheduleTimer()
    }
    
    private func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        stop()
        start()
    }
    
    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fire()
            }
        }
    }
    
    private func fire() {
        guard isEnabled else { return }
        
        let dataStore = ProductivityDataStore.shared
        let dailyGoal = Defaults[.waterGoal]
        
        if dataStore.waterConsumedToday() >= dailyGoal {
            return
        }
        
        let quietStart = Defaults[.reminderQuietHoursStart]
        let quietEnd = Defaults[.reminderQuietHoursEnd]
        let currentHour = Calendar.current.component(.hour, from: Date())

        guard quietStart != quietEnd else { return }

        if quietStart < quietEnd {
            guard currentHour >= quietStart && currentHour < quietEnd else { return }
        } else {
            guard currentHour >= quietStart || currentHour < quietEnd else { return }
        }
        
        let isDuringFocus = PomodoroTimerStore.shared.isRunning && PomodoroTimerStore.shared.currentMode == .focus
        let allowDuringFocus = Defaults[.allowRemindersDuringFocus]
        
        if isDuringFocus && !allowDuringFocus {
            AudioPlayer().play(fileName: "water_stream", fileExtension: "caf", duration: 1)
            return
        }
        
        AudioPlayer().play(fileName: "water_stream", fileExtension: "caf", duration: 1)
        NotificationCenter.default.post(name: .drinkingReminderDidFire, object: nil)
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }
}
