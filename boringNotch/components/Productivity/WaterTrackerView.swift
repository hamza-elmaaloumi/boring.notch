import SwiftUI
import Defaults
import AppKit

struct WaterWave: Shape {
    var peakHeight: CGFloat = 32

    func path(in rect: CGRect) -> Path {
        Path { path in
            let baseY = rect.height * 0.7
            let peakY = baseY - peakHeight
            let midX = rect.width / 2

            path.move(to: CGPoint(x: 0, y: baseY))
            path.addCurve(
                to: CGPoint(x: midX, y: peakY),
                control1: CGPoint(x: rect.width * 0.20, y: baseY),
                control2: CGPoint(x: rect.width * 0.40, y: peakY - 4)
            )
            path.addCurve(
                to: CGPoint(x: rect.width, y: baseY),
                control1: CGPoint(x: rect.width * 0.60, y: peakY - 4),
                control2: CGPoint(x: rect.width * 0.80, y: baseY)
            )
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

struct WaterGlassIcon: View {
    let filled: Bool
    var iconName: String = "waterbottle.fill"

    var body: some View {
        ZStack {
            Image(systemName: iconName)
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

struct TaperedGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let bottomWidth = w * 0.72

        let topLeftX: CGFloat = 0
        let topRightX: CGFloat = w
        let bottomLeftX = (w - bottomWidth) / 2
        let bottomRightX = (w + bottomWidth) / 2

        let topRadius = w * 0.15
        let bottomRadius = w * 0.10

        let sideInset: CGFloat = w * 0.02

        return Path { path in
            path.move(to: CGPoint(x: topLeftX + topRadius, y: 0))

            path.addLine(to: CGPoint(x: topRightX - topRadius, y: 0))
            path.addArc(
                center: CGPoint(x: topRightX - topRadius, y: topRadius),
                radius: topRadius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )

            path.addQuadCurve(
                to: CGPoint(x: bottomRightX, y: h - bottomRadius),
                control: CGPoint(
                    x: topRightX - sideInset,
                    y: h * 0.5
                )
            )

            path.addArc(
                center: CGPoint(x: bottomRightX - bottomRadius, y: h - bottomRadius),
                radius: bottomRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )

            path.addLine(to: CGPoint(x: bottomLeftX + bottomRadius, y: h))

            path.addArc(
                center: CGPoint(x: bottomLeftX + bottomRadius, y: h - bottomRadius),
                radius: bottomRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )

            path.addQuadCurve(
                to: CGPoint(x: topLeftX, y: topRadius),
                control: CGPoint(
                    x: bottomLeftX + sideInset,
                    y: h * 0.5
                )
            )

            path.addArc(
                center: CGPoint(x: topLeftX + topRadius, y: topRadius),
                radius: topRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )

            path.closeSubpath()
        }
    }
}

struct TaperedGlassIcon: View {
    var fillPercentage: CGFloat = 0.55

    private let waterColor = Color(red: 0.247, green: 0.663, blue: 0.988)

    var body: some View {
        TaperedGlassShape()
            .stroke(.blue, lineWidth: 2)
            .background(
                waterFill
                    .mask(
                        TaperedGlassShape()
                            .scale(0.92)
                            .offset(y: 1)
                    )
            )
    }

    private var waterFill: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let waterTop = h * (1 - fillPercentage)
            let waveAmplitude: CGFloat = h * 0.06

            Path { path in
                path.move(to: CGPoint(x: 0, y: h))

                path.addLine(to: CGPoint(x: w, y: h))

                path.addLine(to: CGPoint(x: w, y: waterTop))

                path.addCurve(
                    to: CGPoint(x: w * 0.5, y: waterTop),
                    control1: CGPoint(x: w * 0.75, y: waterTop - waveAmplitude),
                    control2: CGPoint(x: w * 0.65, y: waterTop - waveAmplitude)
                )

                path.addCurve(
                    to: CGPoint(x: 0, y: waterTop),
                    control1: CGPoint(x: w * 0.35, y: waterTop + waveAmplitude),
                    control2: CGPoint(x: w * 0.25, y: waterTop + waveAmplitude)
                )

                path.closeSubpath()
            }
            .fill(waterColor)
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
    @EnvironmentObject var vm: BoringViewModel

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

    private let innerArcDiameter: CGFloat = 184
    private let innerArcSpan: CGFloat = 0.278
    private let innerArcRotation: CGFloat = 220

    private var center: CGPoint {
        CGPoint(x: containerSize / 2, y: containerSize / 2)
    }

    private var arcRadius: CGFloat {
        arcDiameter / 2
    }

    private var innerArcRadius: CGFloat {
        innerArcDiameter / 2
    }

    private var arcStartAngle: CGFloat {
        arcRotation
    }

    private var arcEndAngle: CGFloat {
        arcRotation + arcSpan * 360
    }

    private var activeHoursProgress: CGFloat {
        max(ProductivityDataStore.shared.activeDayProgress, 0.001)
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
            innerArcTrack
                .zIndex(1)
            innerArcProgress
                .zIndex(1)
        }
        .frame(width: containerSize, height: containerSize)
        .onAppear {
            ProductivityDataStore.shared.checkDailyReset()
            updateGoalIfNeeded()
        }
        .onChange(of: showCupPicker) { _, newValue in
            vm.isCupPickerActive = newValue
        }
        .onChange(of: userHeight) { updateGoalIfNeeded() }
        .onChange(of: userWeight) { updateGoalIfNeeded() }
        .onChange(of: autoCalculateWaterGoal) { updateGoalIfNeeded() }
    }

    // MARK: - Arc

    private var arcTrack: some View {
        Circle()
            .trim(from: 0, to: arcSpan)
            .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 3, lineCap: .round))
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

    private var innerArcTrack: some View {
        Circle()
            .trim(from: 0, to: innerArcSpan)
            .stroke(Color.green.opacity(0.12), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(innerArcRotation))
            .frame(width: innerArcDiameter, height: innerArcDiameter)
    }

    private var innerArcProgress: some View {
        Circle()
            .trim(from: 0, to: innerArcSpan * min(activeHoursProgress, 1))
            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(innerArcRotation))
            .frame(width: innerArcDiameter, height: innerArcDiameter)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: activeHoursProgress)
    }

    // MARK: - Inner Card

    private var innerCard: some View {
        Circle()
            .fill(Color(white: 0.12))
            .frame(width: innerDiameter, height: innerDiameter)
    }

    // MARK: - Endpoint Icons

    private var endpointIcons: some View {
        let startRad = (arcStartAngle - 4) * .pi / 180
        let endRad = (arcEndAngle + 4) * .pi / 180
        let r = arcRadius
        return ZStack {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .position(
                    x: center.x + r * cos(startRad),
                    y: center.y + r * sin(startRad)
                )

            Image(systemName: "drop.fill")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .position(
                    x: center.x + r * cos(endRad),
                    y: center.y + r * sin(endRad)
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
                    .foregroundStyle(Color(white: 0.5))
            }
        }
        .offset(y: -12)
    }

    // MARK: - Water Wave

    private var waterWave: some View {
        Button(action: incrementWater) {
            WaterWave()
                .fill(Color(red: 0.2, green: 0.35, blue: 0.55))
                .frame(width: innerDiameter, height: innerDiameter)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Quick Add Button

    private var quickAddButton: some View {
        VStack(spacing: 3) {
            WaterGlassIcon(filled: true, iconName: currentCup.shape.icon)

            Text("\(currentCup.amount) ml")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.247, green: 0.663, blue: 0.988))
        }
        .offset(x: -6, y: innerDiameter * 0.2)
        .allowsHitTesting(false)
    }

    // MARK: - Auxiliary Button

    private var auxiliaryButton: some View {
        Button {
            showCupPicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 40, height: 40)
                    .shadow(color: .white.opacity(0.08), radius: 4, x: 0, y: 2)

                TaperedGlassIcon(fillPercentage: 0.55)
                    .frame(width: 16, height: 20)

                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.blue)
                }
                .position(x: 36, y: 36)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(PlainButtonStyle())
        .position(
            x: center.x + innerDiameter * 0.5 + 10,
            y: center.y + innerDiameter * 0.48 + 6
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
        AudioPlayer().play(fileName: "water_stream", fileExtension: "caf", duration: 1)

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
