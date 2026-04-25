import SwiftUI

struct WaterTrackerView: View {
    @AppStorage("waterConsumed") private var waterConsumed: Int = 0
    @AppStorage("waterGoal") private var waterGoal: Int = 2000 // default 2 liters
    @AppStorage("waterIncrement") private var waterIncrement: Int = 250 // 250ml per glass
    @AppStorage("waterUnit") private var waterUnit: String = "ml"
    
    var fillPercentage: Double {
        return min(Double(waterConsumed) / Double(max(1, waterGoal)), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Hydration")
                .font(.headline)
                .foregroundColor(.blue)
            
            ZStack(alignment: .bottom) {
                // Cup outline
                Path { path in
                    let w: CGFloat = 40
                    let h: CGFloat = 60
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addQuadCurve(to: CGPoint(x: w - 5, y: h), control: CGPoint(x: w, y: h - 10))
                    path.addLine(to: CGPoint(x: 5, y: h))
                    path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 0, y: h - 10))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 40, height: 60)
                
                // Water fill
                Path { path in
                    let w: CGFloat = 36
                    let h: CGFloat = 56 * fillPercentage
                    path.move(to: CGPoint(x: 1, y: 58 - h))
                    path.addLine(to: CGPoint(x: w + 3, y: 58 - h))
                    path.addQuadCurve(to: CGPoint(x: w - 2, y: 58), control: CGPoint(x: w + 2, y: 58 - 5))
                    path.addLine(to: CGPoint(x: 5, y: 58))
                    path.addQuadCurve(to: CGPoint(x: 1, y: 58 - h), control: CGPoint(x: 0, y: 58 - 5))
                }
                .fill(LinearGradient(gradient: Gradient(colors: [.cyan, .blue]), startPoint: .top, endPoint: .bottom))
                .animation(.easeInOut(duration: 0.5), value: fillPercentage)
                .frame(width: 40, height: 60)
                .clipShape(Rectangle().offset(y: 4))
            }
            .frame(height: 80)
            
            Text("\(waterConsumed) / \(waterGoal) \(waterUnit)")
                .font(.callout)
            
            HStack(spacing: 15) {
                Button(action: decrementWater) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: incrementWater) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func incrementWater() {
        waterConsumed += waterIncrement
    }
    
    private func decrementWater() {
        waterConsumed = max(0, waterConsumed - waterIncrement)
    }
}
