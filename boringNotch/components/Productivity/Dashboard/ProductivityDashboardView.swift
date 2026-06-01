import SwiftUI

struct ProductivityDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PomodoroDashboardView()
                Divider()
                WaterDashboardView()
            }
            .padding()
        }
    }
}
