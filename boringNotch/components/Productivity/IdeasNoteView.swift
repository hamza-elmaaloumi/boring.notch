import SwiftUI

struct IdeasNoteView: View {
    @AppStorage("ideasNote") private var text: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Write your ideas...")
                    .foregroundColor(Color(white: 0.4))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .font(.system(size: 11))
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
        }
        .frame(maxHeight: .infinity)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(white: 0.25), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }
}
