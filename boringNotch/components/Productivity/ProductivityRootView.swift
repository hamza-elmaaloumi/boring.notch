import SwiftUI

struct ProductivityRootView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                PomodoroTimerView()
                    .frame(width: 130)
                IdeasNoteView()
                    .frame(width: 130)
            }
            .frame(maxHeight: .infinity, alignment: .top)

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
