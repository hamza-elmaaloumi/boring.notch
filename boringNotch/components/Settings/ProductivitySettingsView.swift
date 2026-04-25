import SwiftUI

struct ProductivitySettingsView: View {
    @AppStorage("pomodoroFocus") private var pomodoroFocus: Int = 25
    @AppStorage("pomodoroShortBreak") private var pomodoroShortBreak: Int = 5
    @AppStorage("pomodoroLongBreak") private var pomodoroLongBreak: Int = 15
    
    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    @AppStorage("waterIncrement") private var waterIncrement: Int = 250
    @AppStorage("waterUnit") private var waterUnit: String = "ml"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Productivity Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
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
                                Text("oz").tag("oz")
                                Text("cups").tag("cups")
                            }
                            .frame(width: 100)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}
