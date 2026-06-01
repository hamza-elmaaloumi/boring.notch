import SwiftUI

struct ActiveHoursSlider: View {
    @AppStorage("reminderQuietHoursStart") private var startHour: Int = 8
    @AppStorage("reminderQuietHoursEnd") private var endHour: Int = 0

    var body: some View {
        VStack(spacing: 6) {
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
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.12), radius: 3)
                        .offset(x: startPos / 24.0 * trackWidth - 9)
                        .gesture(DragGesture().onChanged { value in
                            let pos = min(max(0, value.location.x / trackWidth * 24), 24)
                            startHour = min(Int(pos), 23)
                        })

                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.12), radius: 3)
                        .offset(x: endPos / 24.0 * trackWidth - 9)
                        .gesture(DragGesture().onChanged { value in
                            let pos = min(max(0, value.location.x / trackWidth * 24), 24)
                            endHour = Int(pos) == 24 ? 0 : Int(pos)
                        })
                }
            }
            .frame(height: 30)

            HStack {
                Text(timeString(startHour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(endHour == 0 ? "12:00 AM" : timeString(endHour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timeString(_ hour: Int) -> String {
        let h = hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h == 0 ? 12 : h):00 \(ampm)"
    }
}
