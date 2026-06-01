import SwiftUI
import Defaults

struct WaterTrackerView: View {
    @AppStorage("waterConsumed") private var waterConsumed: Int = 0
    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    
    @Default(.selectedCupIndex) var selectedCupIndex
    @Default(.customCupAmount) var customCupAmount
    @Default(.userHeight) var userHeight
    @Default(.userWeight) var userWeight
    @Default(.autoCalculateWaterGoal) var autoCalculateWaterGoal

    @State private var showCupPicker = false

    private var currentCup: WaterCup {
        var cup = WaterCup.predefinedCups[selectedCupIndex]
        if cup.isCustom {
            cup.amount = customCupAmount
        }
        return cup
    }

    private var fillPercentage: CGFloat {
        let safeGoal = max(1, waterGoal)
        return min(max(CGFloat(waterConsumed) / CGFloat(safeGoal), 0), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Image(systemName: "person.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue.opacity(0.05))
                    .offset(y: 5)
                
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: fillPercentage)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fillPercentage)
                
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(waterConsumed)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                        Text("/\(max(1, waterGoal))ml")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                HStack {
                    Image(systemName: "heart.break.fill")
                        .foregroundStyle(.gray.opacity(0.5))
                        .offset(x: -70)
                    Spacer()
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.blue)
                        .offset(x: 70)
                }
                .frame(width: 140)

                // Increment Button
                VStack {
                    Spacer()
                    Button(action: incrementWater) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: currentCup.shape.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.blue)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            
                            Text("\(currentCup.amount) ml")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(y: 45)
                }
                
                // Cup Switcher (Popover)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showCupPicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "arrow.2.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 32, height: 32)
                        .offset(x: 60, y: 30)
                        .popover(isPresented: $showCupPicker) {
                            CupPickerView(
                                selectedCupIndex: $selectedCupIndex,
                                customCupAmount: $customCupAmount
                            )
                        }
                    }
                }
            }
            .frame(width: 180, height: 180)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            ProductivityDataStore.shared.checkDailyReset()
            updateGoalIfNeeded()
        }
        .onChange(of: userHeight) { updateGoalIfNeeded() }
        .onChange(of: userWeight) { updateGoalIfNeeded() }
        .onChange(of: autoCalculateWaterGoal) { updateGoalIfNeeded() }
    }

    private func updateGoalIfNeeded() {
        if autoCalculateWaterGoal {
            let newGoal = ProductivityDataStore.shared.calculateWaterGoal(height: userHeight, weight: userWeight)
            if waterGoal != newGoal {
                waterGoal = newGoal
            }
        }
    }

    private func incrementWater() {
        let increment = currentCup.amount
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            waterConsumed += increment
        }

        let isDuringFocus = PomodoroTimerStore.shared.isRunning && PomodoroTimerStore.shared.currentMode == .focus
        let log = WaterLogEntry(
            date: Date(),
            amountMl: increment,
            wasDuringFocus: isDuringFocus,
            focusSessionId: isDuringFocus ? PomodoroTimerStore.shared.currentSessionId : nil
        )
        ProductivityDataStore.shared.saveWaterLog(log)
    }
}
