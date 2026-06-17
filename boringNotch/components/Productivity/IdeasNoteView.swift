import SwiftUI

struct IdeasNoteView: View {
    @AppStorage("ideasNote") private var text: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Write your ideas...")
                    .foregroundColor(.red.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .font(.system(size: 11, design: .monospaced))
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.red)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, 4)
    }
}
