import SwiftUI

struct WaterTrackerView: View {
    @AppStorage("waterConsumed") private var waterConsumed: Int = 0
    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    @AppStorage("waterIncrement") private var waterIncrement: Int = 200
    @AppStorage("waterUnit") private var waterUnit: String = "ml"

    @State private var animateBubbles = false
    @State private var wavePhase: CGFloat = 0

    private struct BubbleConfig: Identifiable {
        let id = UUID()
        let x: CGFloat
        let size: CGFloat
        let travel: CGFloat
        let duration: Double
        let delay: Double
    }

    private let bubbles: [BubbleConfig] = [
        .init(x: -16, size: 5, travel: 10, duration: 1.9, delay: 0.0),
        .init(x: -4, size: 4, travel: 11, duration: 1.6, delay: 0.2),
        .init(x: 8, size: 6, travel: 13, duration: 2.1, delay: 0.15),
        .init(x: 20, size: 4, travel: 9, duration: 1.8, delay: 0.3),
        .init(x: -10, size: 5, travel: 11, duration: 2.0, delay: 0.4),
        .init(x: 14, size: 4, travel: 8, duration: 1.7, delay: 0.1)
    ]

    private var fillPercentage: CGFloat {
        let safeGoal = max(1, waterGoal)
        let ratio = CGFloat(waterConsumed) / CGFloat(safeGoal)
        return min(max(ratio, 0), 1)
    }

    private var progressText: String {
        "\(waterConsumed)/\(max(1, waterGoal)) \(waterUnit)"
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Hydration")
                .font(.headline)
                .foregroundColor(.blue)

            ZStack(alignment: .bottom) {
                ZStack {
                    CupShape()
                        .fill(Color.white.opacity(0.06))

                    GeometryReader { proxy in
                        let cupHeight = proxy.size.height
                        let fillHeight = max(0, (cupHeight - 8) * fillPercentage)
                        let innerCup = CupShape().inset(by: 4)

                        VStack(spacing: 0) {
                            Spacer(minLength: 0)

                            ZStack(alignment: .top) {
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.96),
                                        Color.blue.opacity(0.84)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                WaterWaveShape(waveHeight: 3.0, phase: wavePhase)
                                    .fill(Color.white.opacity(0.24))
                                    .frame(height: 14)
                                    .offset(y: -6)

                                ZStack {
                                    ForEach(bubbles) { bubble in
                                        Circle()
                                            .fill(Color.white.opacity(0.34))
                                            .frame(width: bubble.size, height: bubble.size)
                                            .offset(
                                                x: bubble.x,
                                                y: animateBubbles ? -bubble.travel : 0
                                            )
                                            .animation(
                                                .easeInOut(duration: bubble.duration)
                                                    .repeatForever(autoreverses: true)
                                                    .delay(bubble.delay),
                                                value: animateBubbles
                                            )
                                    }
                                }
                                .padding(.top, 10)
                                .opacity(fillPercentage > 0.05 ? 1 : 0)
                            }
                            .frame(width: proxy.size.width, height: fillHeight, alignment: .top)
                            .clipped()
                        }
                        .frame(width: proxy.size.width, height: cupHeight, alignment: .bottom)
                        .clipShape(innerCup)
                        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: fillPercentage)
                    }

                    CupShape()
                        .stroke(Color.white.opacity(0.38), lineWidth: 2)
                }
                .frame(width: 78, height: 98)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 5)

                HStack(spacing: 10) {
                    Button(action: decrementWater) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.gray.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text(progressText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(minWidth: 84)

                    Button(action: incrementWater) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.cyan.opacity(0.95))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .offset(y: 10)
            }
            .frame(width: 108, height: 120)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            animateBubbles = true
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }

    private func incrementWater() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            waterConsumed += waterIncrement
        }
    }

    private func decrementWater() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            waterConsumed = max(0, waterConsumed - waterIncrement)
        }
    }
}

private struct CupShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let left = rect.minX + insetAmount
        let right = rect.maxX - insetAmount
        let top = rect.minY + insetAmount
        let bottom = rect.maxY - insetAmount
        let width = max(0, right - left)
        let height = max(0, bottom - top)

        let rimInset = width * 0.11
        let baseInset = width * 0.24

        let leftRim = CGPoint(x: left + rimInset, y: top)
        let rightRim = CGPoint(x: right - rimInset, y: top)
        let rightBase = CGPoint(x: right - baseInset, y: bottom)
        let leftBase = CGPoint(x: left + baseInset, y: bottom)

        path.move(to: leftRim)
        path.addLine(to: rightRim)

        path.addCurve(
            to: rightBase,
            control1: CGPoint(x: rightRim.x + width * 0.07, y: top + height * 0.30),
            control2: CGPoint(x: rightBase.x + width * 0.05, y: top + height * 0.78)
        )

        path.addQuadCurve(
            to: leftBase,
            control: CGPoint(x: left + width * 0.5, y: bottom + height * 0.05)
        )

        path.addCurve(
            to: leftRim,
            control1: CGPoint(x: leftBase.x - width * 0.05, y: top + height * 0.78),
            control2: CGPoint(x: leftRim.x - width * 0.07, y: top + height * 0.30)
        )

        path.closeSubpath()

        return path
    }

    func inset(by amount: CGFloat) -> CupShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

private struct WaterWaveShape: Shape {
    var waveHeight: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = rect.height * 0.55

        path.move(to: CGPoint(x: 0, y: baseline))

        let step: CGFloat = 3
        var x: CGFloat = 0
        while x <= rect.width {
            let relative = x / max(rect.width, 1)
            let y = baseline + sin(relative * .pi * 2 + phase) * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}
