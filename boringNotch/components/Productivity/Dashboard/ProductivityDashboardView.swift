import SwiftUI

struct ProductivityDashboardView: View {
    @State private var selectedDashboard: String = "pomodoro"

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedDashboard) {
                Text("Pomodoro").tag("pomodoro")
                Text("Water").tag("water")
                Text("Combined").tag("combined")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            switch selectedDashboard {
            case "pomodoro":
                PomodoroDashboardView()
            case "water":
                WaterDashboardView()
            case "combined":
                CombinedDashboardView()
            default:
                PomodoroDashboardView()
            }
        }
    }
}
