import SwiftUI

struct ProductivityRootView: View {
    var body: some View {
        HStack(spacing: 20) {
            PomodoroTimerView()
            Divider()
            WaterTrackerView()
        }
        .padding()
        .frame(height: 200)
    }
}
