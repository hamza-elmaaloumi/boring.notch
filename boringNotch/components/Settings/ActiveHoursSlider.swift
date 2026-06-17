import Defaults
import SwiftUI

struct ActiveHoursSlider: View {
    @Default(.reminderQuietHoursStart) var startHour
    @Default(.reminderQuietHoursEnd) var endHour

    var body: some View {
        VStack(spacing: 8) {
            Text("Active hours")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                let trackWidth = geo.size.width
                let startPos = CGFloat(startHour)
                let endPos = endHour == 0 ? 24.0 : CGFloat(endHour)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 8)

                    if startPos <= endPos {
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max((endPos - startPos) / 24.0 * trackWidth, 0), height: 8)
                            .offset(x: startPos / 24.0 * trackWidth)
                    } else {
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: (24.0 - startPos) / 24.0 * trackWidth, height: 8)
                            .offset(x: startPos / 24.0 * trackWidth)
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: endPos / 24.0 * trackWidth, height: 8)
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.12), radius: 3)
                        .position(x: startPos / 24.0 * trackWidth, y: 15)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.12), radius: 3)
                        .position(x: endPos / 24.0 * trackWidth, y: 15)
                }
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let raw = value.location.x / trackWidth * 24
                            let pos = min(max(0, raw), 24)
                            let startDist = abs(pos - startPos)
                            let endDist = abs(pos - endPos)
                            if startDist <= endDist {
                                startHour = min(Int(pos), 23)
                            } else {
                                endHour = Int(pos) == 24 ? 0 : Int(pos)
                            }
                        }
                )
            }
            .frame(height: 30)

            HStack(spacing: 8) {
                Label("Start", systemImage: "sunrise.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Stepper("\(startHour):00", value: $startHour, in: 0...23)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 100)
            }

            HStack(spacing: 8) {
                Label("End", systemImage: "sunset.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Stepper("\(endHour == 0 ? 24 : endHour):00", value: $endHour, in: 0...23)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 100)
            }
        }
    }
}
