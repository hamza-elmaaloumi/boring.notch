import SwiftUI

struct ClipboardHistoryView: View {
    @Binding var currentState: ClipboardState
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    @State private var copiedItemId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                currentState = .snippets
            }) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    Text("All Snippets")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(red: 50.0/255.0, green: 50.0/255.0, blue: 50.0/255.0))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding([.horizontal, .top])
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(clipboardManager.history) { item in
                        ClipboardItemRow(
                            item: item,
                            isCopied: copiedItemId == item.id
                        ) {
                            copyToClipboard(item)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func copyToClipboard(_ item: ClipboardItem) {
        clipboardManager.copyText(item.text)
        
        withAnimation {
            copiedItemId = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedItemId == item.id {
                withAnimation {
                    copiedItemId = nil
                }
            }
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isCopied: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(item.text)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                
                if isCopied {
                    HStack(spacing: 4) {
                        Text("Copied")
                            .font(.caption)
                        Image(systemName: "checkmark")
                    }
                    .foregroundColor(.green)
                    .transition(.opacity)
                } else {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 0)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
