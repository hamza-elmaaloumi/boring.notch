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
            .padding(.top, 20)
            .padding(.bottom, 10)
        }
        .frame(maxHeight: 400)
    }
}
