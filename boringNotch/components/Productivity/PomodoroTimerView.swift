import SwiftUI

struct PomodoroTimerView: View {
    @State private var timeRemaining: Int = 25 * 60
    @State private var timer: Timer?
    @State private var isRunning: Bool = false
    @State private var isWorkSession: Bool = true
    
    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Text(isWorkSession ? "Focus" : "Break")
                .font(.headline)
                .foregroundColor(isWorkSession ? .red : .green)
            
            Text(timeString)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .monospacedDigit()
            
            HStack(spacing: 20) {
                Button(action: toggleTimer) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
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
                    isWorkSession.toggle()
                    timeRemaining = isWorkSession ? 25 * 60 : 5 * 60
                }
            }
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        isRunning = false
        isWorkSession = true
        timeRemaining = 25 * 60
    }
    
    private func playAlarm() {
        NSSound(named: "Glass")?.play()
    }
}
