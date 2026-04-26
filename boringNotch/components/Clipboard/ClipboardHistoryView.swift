import SwiftUI

struct ClipboardHistoryView: View {
    @Binding var currentState: ClipboardState
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @EnvironmentObject private var vm: BoringViewModel
    
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
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color(red: 50.0/255.0, green: 50.0/255.0, blue: 50.0/255.0))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.top, 4)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(clipboardManager.history) { item in
                        ClipboardItemRow(
                            item: item,
                            isCopied: copiedItemId == item.id
                        ) {
                            withAnimation(.smooth) {
                                vm.close()
                            }
                            copyToClipboard(item)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func copyToClipboard(_ item: ClipboardItem) {
        clipboardManager.copyText(
            item.text,
            sourceBundleIdentifier: item.sourceBundleIdentifier,
            sourceApplicationName: item.sourceApplicationName
        )
        
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
            HStack(spacing: 10) {
                sourceIcon

                Text(item.text)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isCopied ? .green : .secondary)
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

    @ViewBuilder
    private var sourceIcon: some View {
        if let bundleIdentifier = item.sourceBundleIdentifier,
           let appIcon = AppIconAsNSImage(for: bundleIdentifier) {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "doc")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
        }
    }
}
