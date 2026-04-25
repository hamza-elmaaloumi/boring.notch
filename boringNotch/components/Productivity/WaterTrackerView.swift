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
        .init(x: -24, size: 6, travel: 10, duration: 1.9, delay: 0.0),
        .init(x: -8, size: 4, travel: 12, duration: 1.6, delay: 0.2),
        .init(x: 10, size: 7, travel: 14, duration: 2.1, delay: 0.15),
        .init(x: 24, size: 5, travel: 9, duration: 1.8, delay: 0.3),
        .init(x: -16, size: 5, travel: 11, duration: 2.0, delay: 0.4),
        .init(x: 18, size: 4, travel: 8, duration: 1.7, delay: 0.1)
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
        VStack(spacing: 10) {
            Text("Hydration")
                .font(.headline)
                .foregroundColor(.blue)

            ZStack {
                GlassShape()
                    .fill(Color.white.opacity(0.05))

                GlassShape()
                    .stroke(Color.white.opacity(0.35), lineWidth: 2.2)

                GeometryReader { proxy in
                    let fillHeight = max(8, (proxy.size.height - 8) * fillPercentage)

                    ZStack(alignment: .top) {
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.95),
                                Color.blue.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        WaterWaveShape(waveHeight: 3.5, phase: wavePhase)
                            .fill(Color.white.opacity(0.24))
                            .frame(height: 14)
                            .offset(y: 1)

                        ZStack {
                            ForEach(bubbles) { bubble in
                                Circle()
                                    .fill(Color.white.opacity(0.35))
                                    .frame(width: bubble.size, height: bubble.size)
                                    .offset(
                                        x: bubble.x,
                                        y: animateBubbles ? -bubble.travel : bubble.travel
                                    )
                                    .animation(
                                        .easeInOut(duration: bubble.duration)
                                            .repeatForever(autoreverses: true)
                                            .delay(bubble.delay),
                                        value: animateBubbles
                                    )
                            }
                        }
                        .opacity(fillPercentage > 0.05 ? 1 : 0)
                    }
                    .frame(width: proxy.size.width - 8, height: fillHeight, alignment: .top)
                    .clipShape(GlassShape())
                    .offset(x: 4, y: proxy.size.height - fillHeight - 4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: fillPercentage)
                }
            }
            .frame(width: 102, height: 126)

            HStack(spacing: 12) {
                Button(action: decrementWater) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())

                Text(progressText)
                    .font(.callout.weight(.semibold))
                    .frame(minWidth: 88)

                Button(action: incrementWater) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
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
        waterConsumed += waterIncrement
    }

    private func decrementWater() {
        waterConsumed = max(0, waterConsumed - waterIncrement)
    }
}

private struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topInset = rect.width * 0.16
        let bottomInset = rect.width * 0.06

        path.move(to: CGPoint(x: topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - topInset, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - bottomInset, y: rect.height),
            control: CGPoint(x: rect.width * 1.02, y: rect.height * 0.46)
        )
        path.addLine(to: CGPoint(x: bottomInset, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: topInset, y: 0),
            control: CGPoint(x: -rect.width * 0.02, y: rect.height * 0.46)
        )
        path.closeSubpath()

        return path
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
