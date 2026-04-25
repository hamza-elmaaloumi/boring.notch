import SwiftUI

struct SnippetCollectionView: View {
    @Binding var currentState: ClipboardState
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    @State private var copiedSnippetId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                currentState = .history
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("All Snippets")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
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
                    if clipboardManager.snippets.isEmpty {
                        Text("No snippets saved. Open Settings to add snippets.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(clipboardManager.snippets) { snippet in
                            SnippetItemRow(
                                snippet: snippet,
                                isCopied: copiedSnippetId == snippet.id
                            ) {
                                copyToClipboard(snippet)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func copyToClipboard(_ snippet: Snippet) {
        clipboardManager.copyText(snippet.fullText)
        
        withAnimation {
            copiedSnippetId = snippet.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedSnippetId == snippet.id {
                withAnimation {
                    copiedSnippetId = nil
                }
            }
        }
    }
}

struct SnippetItemRow: View {
    let snippet: Snippet
    let isCopied: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.accentColor)
                Text(snippet.title)
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
            .padding()
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
