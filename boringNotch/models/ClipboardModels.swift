import Foundation

struct Snippet: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var fullText: String
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var timestamp: Date = Date()
    var sourceBundleIdentifier: String? = nil
    var sourceApplicationName: String? = nil
}
