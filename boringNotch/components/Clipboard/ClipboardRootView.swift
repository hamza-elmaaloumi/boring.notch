import SwiftUI

enum ClipboardState {
    case history
    case snippets
}

struct ClipboardRootView: View {
    @State private var currentState: ClipboardState = .history
    
    var body: some View {
        VStack {
            switch currentState {
            case .history:
                ClipboardHistoryView(currentState: $currentState)
                    .transition(.move(edge: .leading))
            case .snippets:
                SnippetCollectionView(currentState: $currentState)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentState)
        .frame(maxHeight: 400)
    }
}
