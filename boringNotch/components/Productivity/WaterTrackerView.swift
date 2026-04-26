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
                VStack(spacing: 8) {
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
                    .frame(width: 78, height: 86)
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
                            .clipShape(Circle())
                .padding(.top, 2)
                    .buttonStyle(PlainButtonStyle())

                    Text(progressText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.95))
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
                                    .frame(width: 78, height: 86)
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
        path.addLine(to: CGPoint(x: 0, y: rect.height))
                                .frame(width: 108, height: 120)

        return path
    }
}
