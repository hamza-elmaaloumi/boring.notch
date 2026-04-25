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
            .padding(.top, 6)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
