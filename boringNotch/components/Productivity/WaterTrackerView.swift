import SwiftUI
import Defaults

struct WaterWave: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let waveTopY = rect.height * 0.72
            path.move(to: CGPoint(x: 0, y: waveTopY))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: waveTopY),
                control: CGPoint(x: rect.width * 0.5, y: waveTopY - 14)
            )
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

struct WaterGlassIcon: View {
    let filled: Bool

    var body: some View {
        ZStack {
            Image(systemName: "waterbottle.fill")
                .font(.system(size: 22))
                .foregroundStyle(filled ? .blue : .blue.opacity(0.4))

            if filled {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct WaterTrackerView: View {
    @AppStorage("waterConsumed") private var waterConsumed: Int = 0
    @AppStorage("waterGoal") private var waterGoal: Int = 2000

    @Default(.selectedCupIndex) var selectedCupIndex
    @Default(.customCupAmount) var customCupAmount
    @Default(.userHeight) var userHeight
    @Default(.userWeight) var userWeight
    @Default(.autoCalculateWaterGoal) var autoCalculateWaterGoal

    @State private var showCupPicker = false

    private let containerSize: CGFloat = 300
    private let arcDiameter: CGFloat = 236
    private let innerDiameter: CGFloat = 210

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

    private let arcSpan: CGFloat = 0.611
    private let arcRotation: CGFloat = 160

    private var center: CGPoint {
        CGPoint(x: containerSize / 2, y: containerSize / 2)
    }

    private var arcRadius: CGFloat {
        arcDiameter / 2
    }

    private var endpointOffset: CGSize {
        let angle: CGFloat = 20
        let rad = angle * .pi / 180
        let r = arcRadius + 6
        return CGSize(width: r * cos(rad), height: r * sin(rad))
    }

    var body: some View {
        ZStack {
            arcTrack
            arcProgress
            innerCard
            endpointIcons
            centerText
            waterWave
            quickAddButton
            auxiliaryButton
        }
        .frame(width: containerSize, height: containerSize)
        .onAppear {
            ProductivityDataStore.shared.checkDailyReset()
            updateGoalIfNeeded()
        }
        .onChange(of: userHeight) { updateGoalIfNeeded() }
        .onChange(of: userWeight) { updateGoalIfNeeded() }
        .onChange(of: autoCalculateWaterGoal) { updateGoalIfNeeded() }
    }

    // MARK: - Arc

    private var arcTrack: some View {
        Circle()
            .trim(from: 0, to: arcSpan)
            .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(arcRotation))
            .frame(width: arcDiameter, height: arcDiameter)
    }

    private var arcProgress: some View {
        Circle()
            .trim(from: 0, to: arcSpan * min(fillPercentage, 1))
            .stroke(Color(red: 0.247, green: 0.663, blue: 0.988), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(arcRotation))
            .frame(width: arcDiameter, height: arcDiameter)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fillPercentage)
    }

    // MARK: - Inner Card

    private var innerCard: some View {
        Circle()
            .fill(.white)
            .frame(width: innerDiameter, height: innerDiameter)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
    }

    // MARK: - Endpoint Icons

    private var endpointIcons: some View {
        ZStack {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .position(
                    x: center.x - endpointOffset.width,
                    y: center.y + endpointOffset.height
                )

            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                Image(systemName: "sparkles")
                    .font(.system(size: 7))
                    .foregroundStyle(.blue)
            }
            .position(
                x: center.x + endpointOffset.width,
                y: center.y + endpointOffset.height
            )
        }
    }

    // MARK: - Center Text

    private var centerText: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(waterConsumed)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.247, green: 0.663, blue: 0.988))
                Text("/\(max(1, waterGoal))ml")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
            }
        }
        .offset(y: -12)
    }

    // MARK: - Water Wave

    private var waterWave: some View {
        WaterWave()
            .fill(Color(red: 0.851, green: 0.918, blue: 0.992))
            .frame(width: innerDiameter, height: innerDiameter)
            .clipShape(Circle())
    }

    // MARK: - Quick Add Button

    private var quickAddButton: some View {
        VStack(spacing: 3) {
            Button(action: incrementWater) {
                WaterGlassIcon(filled: true)
            }
            .buttonStyle(PlainButtonStyle())

            Text("\(currentCup.amount) ml")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.247, green: 0.663, blue: 0.988))
        }
        .offset(y: innerDiameter * 0.28)
    }

    // MARK: - Auxiliary Button

    private var auxiliaryButton: some View {
        Button {
            showCupPicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)

                HStack(spacing: 2) {
                    Image(systemName: "waterbottle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Image(systemName: "arrow.trianglehead.2.circlepath")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .position(
            x: center.x + innerDiameter * 0.5 + 18,
            y: center.y + innerDiameter * 0.48 + 18
        )
        .popover(isPresented: $showCupPicker) {
            CupPickerView(
                selectedCupIndex: $selectedCupIndex,
                customCupAmount: $customCupAmount
            )
        }
    }

    // MARK: - Helpers

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
