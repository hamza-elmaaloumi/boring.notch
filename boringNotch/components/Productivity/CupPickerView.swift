import SwiftUI

struct CupPickerView: View {
    @Binding var selectedCupIndex: Int
    @Binding var customCupAmount: Int
    @Environment(\.dismiss) var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(WaterCup.predefinedCups.filter { !$0.isCustom }) { cup in
                        cupCell(cup)
                    }
                }

                Divider()

                customCupCell
            }
            .padding()
        }
        .frame(width: 340, height: 380)
    }

    private func cupCell(_ cup: WaterCup) -> some View {
        Button {
            selectedCupIndex = cup.id
            dismiss()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: cup.shape.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(selectedCupIndex == cup.id ? .blue : .white)

                Text(cup.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)

                Text("\(cup.amount) ml")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedCupIndex == cup.id ? Color.blue.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedCupIndex == cup.id ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var customCupCell: some View {
        HStack(spacing: 12) {
            Image(systemName: WaterCupShape.cup.icon)
                .font(.system(size: 28))
                .foregroundStyle(selectedCupIndex == 6 ? .blue : .white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Custom")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text("Enter your own amount")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("ml", value: $customCupAmount, formatter: numberFormatter)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 70)

            Button("Select") {
                selectedCupIndex = 6
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedCupIndex == 6 ? Color.blue.opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedCupIndex == 6 ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var numberFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimum = 1
        f.maximum = 5000
        return f
    }
}
