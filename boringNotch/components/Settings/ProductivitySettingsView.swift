import SwiftUI
import Defaults

struct ProductivitySettingsView: View {
    @State private var selectedTab: String = "settings"

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Settings").tag("settings")
                Text("Dashboard").tag("dashboard")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top)

            switch selectedTab {
            case "settings":
                ProductivitySettingsContent()
            case "dashboard":
                ProductivityDashboardView()
            default:
                ProductivitySettingsContent()
            }
        }
    }
}

struct ProductivitySettingsContent: View {
    @AppStorage("pomodoroFocus") private var pomodoroFocus: Int = 25
    @AppStorage("pomodoroShortBreak") private var pomodoroShortBreak: Int = 5
    @AppStorage("pomodoroLongBreak") private var pomodoroLongBreak: Int = 15

    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    @AppStorage("dailyFocusGoalMinutes") private var dailyFocusGoal: Int = 120
    @AppStorage("drinkingReminderInterval") private var reminderInterval: Int = 96
    @AppStorage("allowRemindersDuringFocus") private var allowDuringFocus: Bool = false

    @Default(.userHeight) var userHeight
    @Default(.userWeight) var userWeight
    @Default(.autoCalculateWaterGoal) var autoCalculateWaterGoal

    private var currentCupInfo: (icon: String, label: String) {
        let cup = WaterCup.predefinedCups[Defaults[.selectedCupIndex]]
        let ml = cup.isCustom ? Defaults[.customCupAmount] : cup.amount
        return (cup.shape.icon, "\(ml) ml")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                focusTimeCard
                waterIntakeCard
            }
            .padding(16)
        }
        .onChange(of: userHeight) { updateGoal() }
        .onChange(of: userWeight) { updateGoal() }
        .onChange(of: autoCalculateWaterGoal) { updateGoal() }
    }

    private var focusTimeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Focus Time", systemImage: "clock")
                .font(.headline)
                .foregroundStyle(.secondary)

            settingRow(label: "Daily focus time goal (minutes)", control: {
                Stepper("\(dailyFocusGoal)", value: $dailyFocusGoal, in: 15...480, step: 15)
            })

            settingRow(label: "Focus Duration (minutes)", control: {
                Stepper("\(pomodoroFocus)", value: $pomodoroFocus, in: 1...120)
            })

            settingRow(label: "Short Break (minutes)", control: {
                Stepper("\(pomodoroShortBreak)", value: $pomodoroShortBreak, in: 1...60)
            })

            settingRow(label: "Long Break (minutes)", control: {
                Stepper("\(pomodoroLongBreak)", value: $pomodoroLongBreak, in: 1...120)
            })

            Divider()

            Defaults.Toggle(key: .showPomodoroTimerInNotch) {
                Text("Show timer in notch when active")
            }

            Defaults.Toggle(key: .showNotHumanFace) {
                Text("Show face animation in notch")
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var waterIntakeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Water Intake", systemImage: "drop")
                .font(.headline)
                .foregroundStyle(.secondary)

            settingRow(label: "Height (cm)", control: {
                TextField("cm", value: $userHeight, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            })

            settingRow(label: "Weight (kg)", control: {
                TextField("kg", value: $userWeight, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            })

            Toggle("Auto-calculate water goal", isOn: $autoCalculateWaterGoal)

            settingRow(label: "Daily Goal (ml)", control: {
                TextField("Amount", value: $waterGoal, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .disabled(autoCalculateWaterGoal)
            })

            if autoCalculateWaterGoal {
                Text("Goal is automatically calculated based on biometrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            settingRow(label: "Default Cup", control: {
                HStack(spacing: 6) {
                    Image(systemName: currentCupInfo.icon)
                        .foregroundStyle(.blue)
                    Text(currentCupInfo.label)
                        .foregroundStyle(.secondary)
                }
            })

            Divider()

            Toggle("Enable drinking reminder", isOn: Binding(
                get: { DrinkingReminderManager.shared.isEnabled },
                set: { DrinkingReminderManager.shared.isEnabled = $0 }
            ))

            settingRow(label: "Reminder interval (minutes)", control: {
                Stepper("\(reminderInterval)", value: $reminderInterval, in: 15...240, step: 5)
                    .onChange(of: reminderInterval) { _, newValue in
                        DrinkingReminderManager.shared.intervalMinutes = newValue
                    }
            })

            Toggle("Allow reminders during focus sessions", isOn: $allowDuringFocus)

            ActiveHoursSlider()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func settingRow<Content: View>(label: String, control: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer()
            control()
        }
    }

    private func updateGoal() {
        if autoCalculateWaterGoal {
            waterGoal = ProductivityDataStore.shared.calculateWaterGoal(height: userHeight, weight: userWeight)
        }
    }
}
