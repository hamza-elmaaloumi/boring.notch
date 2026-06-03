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
            VStack(alignment: .leading, spacing: 20) {
                Text("Productivity Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                GroupBox(label: Text("Focus Goals").font(.headline)) {
                    VStack(spacing: 15) {
                        HStack {
                            Text("Daily focus time goal (minutes)")
                            Spacer()
                            Stepper("\(dailyFocusGoal)", value: $dailyFocusGoal, in: 15...480, step: 15)
                        }
                    }
                    .padding()
                }

                GroupBox(label: Text("Pomodoro Timer (Minutes)").font(.headline)) {
                    VStack(spacing: 15) {
                        HStack {
                            Text("Focus Duration")
                            Spacer()
                            Stepper("\(pomodoroFocus)", value: $pomodoroFocus, in: 1...120)
                        }

                        HStack {
                            Text("Short Break")
                            Spacer()
                            Stepper("\(pomodoroShortBreak)", value: $pomodoroShortBreak, in: 1...60)
                        }

                        HStack {
                            Text("Long Break")
                            Spacer()
                            Stepper("\(pomodoroLongBreak)", value: $pomodoroLongBreak, in: 1...120)
                        }
                    }
                    .padding()
                }

                GroupBox(label: Text("Biometrics (for Hydration Goal)").font(.headline)) {
                    VStack(spacing: 15) {
                        HStack {
                            Text("Height (cm)")
                            Spacer()
                            TextField("cm", value: $userHeight, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }

                        HStack {
                            Text("Weight (kg)")
                            Spacer()
                            TextField("kg", value: $userWeight, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }
                        
                        Toggle("Auto-calculate water goal", isOn: $autoCalculateWaterGoal)
                    }
                    .padding()
                }

                GroupBox(label: Text("Hydration Tracker").font(.headline)) {
                    VStack(spacing: 15) {
                        HStack {
                            Text("Daily Goal (ml)")
                            Spacer()
                            TextField("Amount", value: $waterGoal, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .disabled(autoCalculateWaterGoal)
                        }
                        
                        if autoCalculateWaterGoal {
                            Text("Goal is automatically calculated based on biometrics.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Default Cup")
                            Spacer()
                            Image(systemName: currentCupInfo.icon)
                                .foregroundStyle(.blue)
                            Text(currentCupInfo.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                GroupBox(label: Text("Drinking Reminder").font(.headline)) {
                    VStack(spacing: 15) {
                        Toggle("Enable drinking reminder", isOn: Binding(
                            get: { DrinkingReminderManager.shared.isEnabled },
                            set: { DrinkingReminderManager.shared.isEnabled = $0 }
                        ))

                        HStack {
                            Text("Reminder interval (minutes)")
                            Spacer()
                            Stepper("\(reminderInterval)", value: $reminderInterval, in: 15...240, step: 5)
                                .onChange(of: reminderInterval) { _, newValue in
                                    DrinkingReminderManager.shared.intervalMinutes = newValue
                                }
                        }

                        Toggle("Allow reminders during focus sessions", isOn: $allowDuringFocus)

                        ActiveHoursSlider()
                    }
                    .padding()
                }

                GroupBox(label: Text("Notch Display").font(.headline)) {
                    VStack(spacing: 15) {
                        Defaults.Toggle(key: .showPomodoroTimerInNotch) {
                            Text("Show timer in notch when active")
                        }
                        Defaults.Toggle(key: .showNotHumanFace) {
                            Text("Show face animation in notch")
                        }
                    }
                    .padding()
                }

                Spacer()
            }
            .padding(30)
        }
        .onChange(of: userHeight) { updateGoal() }
        .onChange(of: userWeight) { updateGoal() }
        .onChange(of: autoCalculateWaterGoal) { updateGoal() }
    }
    
    private func updateGoal() {
        if autoCalculateWaterGoal {
            waterGoal = ProductivityDataStore.shared.calculateWaterGoal(height: userHeight, weight: userWeight)
        }
    }
}
