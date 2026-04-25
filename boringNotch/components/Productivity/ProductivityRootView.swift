import SwiftUI

struct ProductivityRootView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                PomodoroTimerView()
                Divider()
                WaterTrackerView()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .frame(maxHeight: 150, alignment: .top)
    }
}
