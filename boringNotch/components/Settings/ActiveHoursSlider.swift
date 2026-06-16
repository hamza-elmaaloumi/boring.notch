import SwiftUI

struct ActiveHoursSlider: View {
    @AppStorage("reminderQuietHoursStart") private var startHour: Int = 8
    @AppStorage("reminderQuietHoursEnd") private var endHour: Int = 0

    @State private var startDisplayHour: String = ""
    @State private var startIsAM: Bool = true
    @State private var endDisplayHour: String = ""
    @State private var endIsAM: Bool = true
    @State private var isSyncing: Bool = false

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

                TextField("1", text: $startDisplayHour)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .onChange(of: startDisplayHour) { _, _ in
                        guard !isSyncing else { return }
                        updateStartFromText()
                    }

                Picker("", selection: $startIsAM) {
                    Text("AM").tag(true)
                    Text("PM").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 70)
                .onChange(of: startIsAM) { _, _ in
                    guard !isSyncing else { return }
                    updateStartFromText()
                }
            }

            HStack(spacing: 8) {
                Label("End", systemImage: "sunset.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                TextField("12", text: $endDisplayHour)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .onChange(of: endDisplayHour) { _, _ in
                        guard !isSyncing else { return }
                        updateEndFromText()
                    }

                Picker("", selection: $endIsAM) {
                    Text("AM").tag(true)
                    Text("PM").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 70)
                .onChange(of: endIsAM) { _, _ in
                    guard !isSyncing else { return }
                    updateEndFromText()
                }
            }
        }
        .onAppear {
            UserDefaults.standard.set(startHour, forKey: "reminderQuietHoursStart")
            UserDefaults.standard.set(endHour, forKey: "reminderQuietHoursEnd")
            syncDisplayFromSlider()
        }
        .onChange(of: startHour) { _, _ in
            syncDisplayFromSlider()
        }
        .onChange(of: endHour) { _, _ in
            syncDisplayFromSlider()
        }
    }

    private func syncDisplayFromSlider() {
        isSyncing = true
        defer { isSyncing = false }

        startDisplayHour = hourTo12(startHour)
        startIsAM = startHour < 12

        endDisplayHour = hourTo12(endHour)
        endIsAM = endHour < 12
    }

    private func hourTo12(_ hour: Int) -> String {
        switch hour {
        case 0: return "12"
        case 1...11: return "\(hour)"
        case 12: return "12"
        default: return "\(hour - 12)"
        }
    }

    private func updateStartFromText() {
        guard let h = Int(startDisplayHour), h >= 1, h <= 12 else { return }
        startHour = startIsAM ? (h == 12 ? 0 : h) : (h == 12 ? 12 : h + 12)
    }

    private func updateEndFromText() {
        guard let h = Int(endDisplayHour), h >= 1, h <= 12 else { return }
        endHour = endIsAM ? (h == 12 ? 0 : h) : (h == 12 ? 12 : h + 12)
    }
}
