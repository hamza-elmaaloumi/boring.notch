import SwiftUI

struct ProductivityRootView: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                PomodoroTimerView()
                Divider()
                WaterTrackerView()
                WaterLogListView()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }
}
