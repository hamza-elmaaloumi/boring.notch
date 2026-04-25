import SwiftUI

struct PomodoroTimerView: View {
    @AppStorage("pomodoroFocus") private var pomodoroFocus: Int = 25
    @AppStorage("pomodoroShortBreak") private var pomodoroShortBreak: Int = 5
    @AppStorage("pomodoroLongBreak") private var pomodoroLongBreak: Int = 15
    
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
    
    @State private var currentMode: Mode = .focus
    
    @State private var timeRemaining: Int = 25 * 60
    @State private var timer: Timer?
    @State private var isRunning: Bool = false
    
    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $currentMode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Image(systemName: mode.iconName).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 10)
            .frame(maxWidth: 210)
            .frame(maxWidth: .infinity)
            .onChange(of: currentMode) { _, _ in
                resetTimer()
            }
            
            Text(timeString)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .monospacedDigit()
            
            HStack(spacing: 14) {
                Button(action: toggleTimer) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: resetTimer) {
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
            timeRemaining = modeDuration(for: currentMode) * 60
        }
        .onChange(of: pomodoroFocus) { _, _ in
            if currentMode == .focus {
                resetTimer()
            }
        }
        .onChange(of: pomodoroShortBreak) { _, _ in
            if currentMode == .shortBreak {
                resetTimer()
            }
        }
        .onChange(of: pomodoroLongBreak) { _, _ in
            if currentMode == .longBreak {
                resetTimer()
            }
        }
    }
    
    private func modeDuration(for mode: Mode) -> Int {
        switch mode {
        case .focus: return pomodoroFocus
        case .shortBreak: return pomodoroShortBreak
        case .longBreak: return pomodoroLongBreak
        }
    }
    
    private func toggleTimer() {
        if isRunning {
            timer?.invalidate()
            isRunning = false
        } else {
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    playAlarm()
                    switchModeAutomatically()
                }
            }
        }
    }
    
    private func switchModeAutomatically() {
        if currentMode == .focus {
            currentMode = .shortBreak
        } else {
            currentMode = .focus
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        isRunning = false
        timeRemaining = modeDuration(for: currentMode) * 60
    }
    
    private func playAlarm() {
        NSSound(named: "Glass")?.play()
    }
}
