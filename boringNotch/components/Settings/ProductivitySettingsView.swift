import SwiftUI

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
    @AppStorage("waterIncrement") private var waterIncrement: Int = 200
    @AppStorage("waterUnit") private var waterUnit: String = "ml"

    @AppStorage("dailyFocusGoalMinutes") private var dailyFocusGoal: Int = 120
    @AppStorage("drinkingReminderInterval") private var reminderInterval: Int = 96
    @AppStorage("allowRemindersDuringFocus") private var allowDuringFocus: Bool = false
    @AppStorage("reminderQuietHoursStart") private var quietStart: Int = 8
    @AppStorage("reminderQuietHoursEnd") private var quietEnd: Int = 0

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

                GroupBox(label: Text("Hydration Tracker").font(.headline)) {
                    VStack(spacing: 15) {
                        HStack {
                            Text("Daily Goal")
                            Spacer()
                            TextField("Amount", value: $waterGoal, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }

                        HStack {
                            Text("Increment Amount")
                            Spacer()
                            TextField("Amount", value: $waterIncrement, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }

                        HStack {
                            Text("Measurement Unit")
                            Spacer()
                            Picker("", selection: $waterUnit) {
                                Text("ml").tag("ml")
                                Text("cups").tag("cups")
                            }
                            .frame(width: 100)
                            .onChange(of: waterUnit) { _, unit in
                                if unit == "cups" {
                                    waterGoal = 8
                                    waterIncrement = 1
                                } else {
                                    waterGoal = 2000
                                    waterIncrement = 200
                                }
                            }
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

                        HStack {
                            Text("Auto-calculated from goal")
                            Spacer()
                            Button("Recalculate") {
                                DrinkingReminderManager.shared.recalculateInterval(
                                    dailyGoal: waterGoal,
                                    increment: waterIncrement
                                )
                                reminderInterval = DrinkingReminderManager.shared.intervalMinutes
                            }
                            .buttonStyle(.link)
                        }

                        Toggle("Allow reminders during focus sessions", isOn: $allowDuringFocus)

                        HStack {
                            Text("Quiet hours start")
                            Spacer()
                            Stepper("\(quietStart):00", value: $quietStart, in: 0...23)
                        }

                        HStack {
                            Text("Quiet hours end")
                            Spacer()
                            Stepper("\(quietEnd):00", value: $quietEnd, in: 0...23)
                        }
                    }
                    .padding()
                }

                Spacer()
            }
            .padding(30)
        }
        .onAppear {
            if waterUnit != "ml" && waterUnit != "cups" {
                waterUnit = "ml"
                waterGoal = 2000
                waterIncrement = 200
            }
        }
    }
}
