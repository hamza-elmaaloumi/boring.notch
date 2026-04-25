import Cocoa
import Combine
import Foundation

@MainActor
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = []
    @Published var snippets: [Snippet] = []
    
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private let textType = NSPasteboard.PasteboardType.string
    
    private let historyKey = "clipboard_history"
    private let snippetsKey = "saved_snippets"
    
    private init() {
        loadHistory()
        loadSnippets()
        self.lastChangeCount = pasteboard.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let copiedString = pasteboard.string(forType: textType), !copiedString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addHistoryItem(copiedString)
        }
    }
    
    func addHistoryItem(_ text: String) {
        // Prevent immediate duplicates
        if let first = history.first, first.text == text {
            return
        }
        
        // Remove existing duplicate to move it to top
        history.removeAll { $0.text == text }
        
        let newItem = ClipboardItem(text: text)
        history.insert(newItem, at: 0)
        
        if history.count > 30 {
            history = Array(history.prefix(30))
        }
        
        saveHistory()
    }
    
    func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            history = decoded
        }
    }
    
    func saveSnippets() {
        if let data = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(data, forKey: snippetsKey)
        }
    }
    
    private func loadSnippets() {
        if let data = UserDefaults.standard.data(forKey: snippetsKey),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
        }
    }
    
    func copyText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: textType)
        // Update change count so we don't treat our own copy as a new history item
        lastChangeCount = pasteboard.changeCount
        addHistoryItem(text)
    }
}
