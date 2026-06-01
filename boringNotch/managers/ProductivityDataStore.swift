import Combine
import Foundation
import Defaults

@MainActor
class ProductivityDataStore: ObservableObject {
    static let shared = ProductivityDataStore()
    
    @Published var focusSessions: [FocusSession] = []
    @Published var waterLogs: [WaterLogEntry] = []
    
    private let focusSessionsKey = "focus_sessions"
    private let waterLogsKey = "water_logs"
    private let lastResetDateKey = "last_water_reset_date"
    private let migratedKey = "hasMigratedWaterData"
    
    private var midnightTimer: Timer?
    
    private init() {
        loadFocusSessions()
        loadWaterLogs()
        migrateOldWaterData()
        checkDailyReset()
        scheduleMidnightReset()
    }
    
    deinit {
        midnightTimer?.invalidate()
    }
    
    private func scheduleMidnightReset() {
        let now = Date()
        guard let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) else { return }
        
        let interval = nextMidnight.timeIntervalSince(now)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performDailyReset()
                self?.scheduleMidnightReset()
            }
        }
    }
    
    private func migrateOldWaterData() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        let oldWater = UserDefaults.standard.integer(forKey: "waterConsumed")
        if oldWater > 0 {
            let log = WaterLogEntry(
                date: Date(),
                amountMl: oldWater,
                wasDuringFocus: false,
                focusSessionId: nil
            )
            waterLogs.append(log)
            saveWaterLogs()
        }
        UserDefaults.standard.set(true, forKey: migratedKey)
    }
    
    func checkDailyReset() {
        let storedDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        if let stored = storedDate {
            if Calendar.current.startOfDay(for: stored) != today {
                performDailyReset()
            }
        } else {
            UserDefaults.standard.set(today, forKey: lastResetDateKey)
        }
    }
    
    private func performDailyReset() {
        UserDefaults.standard.set(0, forKey: "waterConsumed")
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: lastResetDateKey)
        
        if Defaults[.autoCalculateWaterGoal] {
            let goal = calculateWaterGoal(height: Defaults[.userHeight], weight: Defaults[.userWeight])
            UserDefaults.standard.set(goal, forKey: "waterGoal")
        }
    }
    
    func calculateWaterGoal(height: Double, weight: Double) -> Int {
        let total = Int(weight * 35)
        return max(1000, min(5000, total))
    }
    
    func saveFocusSession(_ session: FocusSession) {
        focusSessions.append(session)
        saveAll()
    }
    
    func saveWaterLog(_ log: WaterLogEntry) {
        waterLogs.append(log)
        saveWaterLogs()
    }
    
    private func saveAll() {
        saveFocusSessions()
        saveWaterLogs()
    }
    
    private func saveFocusSessions() {
        if let data = try? JSONEncoder().encode(focusSessions) {
            UserDefaults.standard.set(data, forKey: focusSessionsKey)
        }
    }
    
    private func saveWaterLogs() {
        if let data = try? JSONEncoder().encode(waterLogs) {
            UserDefaults.standard.set(data, forKey: waterLogsKey)
        }
    }
    
    private func loadFocusSessions() {
        if let data = UserDefaults.standard.data(forKey: focusSessionsKey),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            focusSessions = decoded
        }
    }
    
    private func loadWaterLogs() {
        if let data = UserDefaults.standard.data(forKey: waterLogsKey),
           let decoded = try? JSONDecoder().decode([WaterLogEntry].self, from: data) {
            waterLogs = decoded
        }
    }
}

extension ProductivityDataStore {
    
    func totalFocusTimeToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return focusSessions
            .filter { Calendar.current.startOfDay(for: $0.startDate) == today }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    func totalFocusTimeThisWeek() -> Int {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return focusSessions
            .filter { $0.startDate >= weekStart }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    func totalFocusTimeThisMonth() -> Int {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        return focusSessions
            .filter { $0.startDate >= monthStart }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    func sessionsToday() -> [FocusSession] {
        let today = Calendar.current.startOfDay(for: Date())
        return focusSessions
            .filter { Calendar.current.startOfDay(for: $0.startDate) == today }
            .sorted { $0.startDate > $1.startDate }
    }
    
    func averageFocusTimePerSessionToday() -> Int {
        let sessions = sessionsToday()
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.durationSeconds } / sessions.count
    }
    
    func focusTimeByDayThisWeek() -> [(day: String, minutes: Int)] {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var result: [(day: String, minutes: Int)] = []
        
        for i in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let total = focusSessions
                .filter { Calendar.current.startOfDay(for: $0.startDate) == Calendar.current.startOfDay(for: day) }
                .reduce(0) { $0 + $1.durationSeconds }
            result.append((dayNames[i], total / 60))
        }
        
        return result
    }
    
    func focusTimeByDayThisMonth() -> [(day: Int, minutes: Int)] {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        guard let range = Calendar.current.range(of: .day, in: .month, for: monthStart) else { return [] }
        var result: [(day: Int, minutes: Int)] = []
        
        for day in range {
            guard let date = Calendar.current.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let total = focusSessions
                .filter { Calendar.current.startOfDay(for: $0.startDate) == Calendar.current.startOfDay(for: date) }
                .reduce(0) { $0 + $1.durationSeconds }
            result.append((day, total / 60))
        }
        
        return result
    }
    
    func waterConsumedToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return waterLogs
            .filter { Calendar.current.startOfDay(for: $0.date) == today }
            .reduce(0) { $0 + $1.amountMl }
    }
    
    func waterConsumedThisWeek() -> Int {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return waterLogs
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.amountMl }
    }
    
    func waterConsumedThisMonth() -> Int {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        return waterLogs
            .filter { $0.date >= monthStart }
            .reduce(0) { $0 + $1.amountMl }
    }
    
    func drinkingEventsToday() -> [WaterLogEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return waterLogs
            .filter { Calendar.current.startOfDay(for: $0.date) == today }
            .sorted { $0.date > $1.date }
    }
    
    func waterByDayThisWeek() -> [(day: String, ml: Int)] {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var result: [(day: String, ml: Int)] = []
        
        for i in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let total = waterLogs
                .filter { Calendar.current.startOfDay(for: $0.date) == Calendar.current.startOfDay(for: day) }
                .reduce(0) { $0 + $1.amountMl }
            result.append((dayNames[i], total))
        }
        
        return result
    }
    
    func waterByDayThisMonth() -> [(day: Int, ml: Int)] {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        guard let range = Calendar.current.range(of: .day, in: .month, for: monthStart) else { return [] }
        var result: [(day: Int, ml: Int)] = []
        
        for day in range {
            guard let date = Calendar.current.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let total = waterLogs
                .filter { Calendar.current.startOfDay(for: $0.date) == Calendar.current.startOfDay(for: date) }
                .reduce(0) { $0 + $1.amountMl }
            result.append((day, total))
        }
        
        return result
    }
    
    func waterDuringFocusToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return waterLogs
            .filter { Calendar.current.startOfDay(for: $0.date) == today && $0.wasDuringFocus }
            .reduce(0) { $0 + $1.amountMl }
    }
    
    func waterOutsideFocusToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return waterLogs
            .filter { Calendar.current.startOfDay(for: $0.date) == today && !$0.wasDuringFocus }
            .reduce(0) { $0 + $1.amountMl }
    }
    
    func dailyFocusVsWaterThisWeek() -> [(day: String, focusMinutes: Int, waterMl: Int)] {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var result: [(day: String, focusMinutes: Int, waterMl: Int)] = []
        
        for i in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let dayStart = Calendar.current.startOfDay(for: day)
            let focus = focusSessions
                .filter { Calendar.current.startOfDay(for: $0.startDate) == dayStart }
                .reduce(0) { $0 + $1.durationSeconds } / 60
            let water = waterLogs
                .filter { Calendar.current.startOfDay(for: $0.date) == dayStart }
                .reduce(0) { $0 + $1.amountMl }
            result.append((dayNames[i], focus, water))
        }
        
        return result
    }
    
    func dailyFocusVsWaterThisMonth() -> [(day: Int, focusMinutes: Int, waterMl: Int)] {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        guard let range = Calendar.current.range(of: .day, in: .month, for: monthStart) else { return [] }
        var result: [(day: Int, focusMinutes: Int, waterMl: Int)] = []
        
        for day in range {
            guard let date = Calendar.current.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let dayStart = Calendar.current.startOfDay(for: date)
            let focus = focusSessions
                .filter { Calendar.current.startOfDay(for: $0.startDate) == dayStart }
                .reduce(0) { $0 + $1.durationSeconds } / 60
            let water = waterLogs
                .filter { Calendar.current.startOfDay(for: $0.date) == dayStart }
                .reduce(0) { $0 + $1.amountMl }
            result.append((day, focus, water))
        }
        
        return result
    }
}
