import SwiftUI
import Defaults

struct SnippetsSettingsView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    @State private var draftTitle: String = ""
    @State private var draftText: String = ""
    @State private var selectedSnippetId: UUID? = nil
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSnippetId) {
                ForEach(clipboardManager.snippets) { snippet in
                    NavigationLink(value: snippet.id) {
                        Text(snippet.title)
                    }
                }
                .onDelete { indices in
                    clipboardManager.snippets.remove(atOffsets: indices)
                    clipboardManager.saveSnippets()
                    if let first = indices.first, clipboardManager.snippets.isEmpty || clipboardManager.snippets.indices.contains(first) == false {
                        selectedSnippetId = nil
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Snippets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addSnippet) {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            if let selectedId = selectedSnippetId, let index = clipboardManager.snippets.firstIndex(where: { $0.id == selectedId }) {
                Form {
                    Section {
                        TextField("Title", text: Binding(
                            get: { clipboardManager.snippets[index].title },
                            set: { newValue in
                                clipboardManager.snippets[index].title = newValue
                                clipboardManager.saveSnippets()
                            }
                        ))
                    } header: {
                        Text("Snippet Title")
                    }
                    
                    Section {
                        TextEditor(text: Binding(
                            get: { clipboardManager.snippets[index].fullText },
                            set: { newValue in
                                clipboardManager.snippets[index].fullText = newValue
                                clipboardManager.saveSnippets()
                            }
                        ))
                        .frame(minHeight: 200)
                        .font(.body)
                    } header: {
                        Text("Snippet Content")
                    }
                }
                .padding()
            } else {
                Text("Select a snippet or create a new one.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func addSnippet() {
        let newSnippet = Snippet(title: "New Snippet", fullText: "")
        clipboardManager.snippets.append(newSnippet)
        clipboardManager.saveSnippets()
        selectedSnippetId = newSnippet.id
    }
}
