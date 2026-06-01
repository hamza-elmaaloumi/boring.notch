import SwiftUI

struct ProductivityDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Focus Time", systemImage: "clock")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    PomodoroDashboardView()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 12) {
                    Label("Water Intake", systemImage: "drop")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    WaterDashboardView()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}
