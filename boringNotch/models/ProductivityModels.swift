import Foundation

struct FocusSession: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date
    var durationSeconds: Int
    var mode: String
    var completed: Bool
}

struct WaterLogEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var amountMl: Int
    var wasDuringFocus: Bool
    var focusSessionId: UUID?
}
