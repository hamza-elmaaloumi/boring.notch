import SwiftUI

struct ProductivityRootView: View {
    var body: some View {
        VStack {
            HStack(spacing: 20) {
                PomodoroTimerView()
                Divider()
                WaterTrackerView()
            }
            .padding()
        }
        .frame(maxHeight: 400)
    }
}
