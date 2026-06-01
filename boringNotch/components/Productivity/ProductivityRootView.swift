import SwiftUI

struct ProductivityRootView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PomodoroTimerView()
                .frame(width: 130)
            Divider()
            WaterTrackerView()
            WaterLogListView()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}
