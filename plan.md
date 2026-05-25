# Productivity section — Technical execution plan

## Data models

### New file: `boringNotch/models/ProductivityModels.swift`

```swift
struct FocusSession: Identifiable, Codable, Equatable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var durationSeconds: Int
    var mode: String           // "focus", "shortBreak", "longBreak"
    var completed: Bool        // true = finished, false = interrupted
}

struct WaterLogEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var amountMl: Int          // always stored in milliliters
    var wasDuringFocus: Bool
    var focusSessionId: UUID?
}
```

Water amounts always stored in ml. Convert to cups for display only using `let mlPerCup = 236.588`.

Sessions grouped by `startDate` (handles midnight-spanning correctly).

---

## Managers

### New file: `boringNotch/managers/ProductivityDataStore.swift`

- `@MainActor` singleton `ObservableObject`
- Owns `focusSessions: [FocusSession]` and `waterLogs: [WaterLogEntry]`
- Persists both as JSON in UserDefaults (same pattern as `ClipboardManager`)
- Provides computed stats grouped by day/week/month
- `checkDailyReset()` — resets `@AppStorage("waterConsumed")` to 0 if a new calendar day has started. Stores last reset date in `@AppStorage`. On first launch, set the date without resetting (so existing water is not wiped).
- Uses a midnight timer to auto-reset even if the app stays open overnight
- **Migration:** On first launch, if `UserDefaults.standard.integer(forKey: "waterConsumed")` > 0, save it as a `WaterLogEntry` with `date = Date()` before performing the daily reset, so the user does not lose today's existing progress. Store `"hasMigratedWaterData": true` in UserDefaults to run this only once.

### New file: `boringNotch/managers/DrinkingReminderManager.swift`

- `@MainActor` singleton `ObservableObject`
- Holds `isEnabled`, `intervalMinutes`
- Skips the reminder if `ProductivityDataStore.shared.waterConsumedToday() >= dailyGoal` (no need to notify if goal is met)
- Quiet hours: only fire reminders between a configurable start and end hour (default: 8:00 AM — 12:00 AM). Outside these hours, the reminder is silently skipped.
- `recalculateInterval(dailyGoal:, increment:)` formula:
  ```
  suggestedIntervalMinutes = max(15, (16 * 60 * increment) / dailyGoal)
  ```
  User can override `intervalMinutes` in Settings.
- On timer fire:
  - If a focus session is running: play a gentle sound only (do not open notch)
  - Otherwise: play water sound + post a `drinkingReminderDidFire` notification (same pattern as `pomodoroTimerDidFinish`). The AppDelegate registers an observer (next to the existing `pomodoroTimerDidFinish` observer) — on fire, it opens the notch and switches to the Productivity tab.
- Adds an `@AppStorage("allowRemindersDuringFocus")` toggle
- Timer automatically invalidates and recreates whenever `intervalMinutes` or `isEnabled` changes (using Combine publisher)
- Defines `static let drinkingReminderDidFire = Notification.Name("DrinkingReminderDidFire")` (alongside `pomodoroTimerDidFinish` in `boringNotchApp.swift`)

---

## Changes to existing files

### `boringNotch/components/Productivity/PomodoroTimerView.swift`

**`PomodoroTimerStore`:**
- Add `currentSessionId: UUID?` — set in `startTimer()` when `currentMode == .focus`
- Add `sessionStartDate: Date?` — set in `startTimer()`, used to calculate actual duration for interrupted sessions
- In `completeTimer()`: save a `FocusSession` with `completed: true`
- In `resetTimer()`: if `isRunning && currentMode == .focus`, save a `FocusSession` with `completed: false` (interrupted) before resetting
- `selectMode()` calls `resetTimer()` so this path is covered automatically
- Add a `NotificationCenter` observer for `NSApplication.willTerminateNotification` in `init()` that saves an interrupted focus session if one is running on quit

**`PomodoroTimerView`:**
- Above/below the timer text, show: `"Today: 1h 30m focused"` using `ProductivityDataStore.shared.totalFocusTimeToday()`

### `boringNotch/components/Productivity/WaterTrackerView.swift`

- In `incrementWater()`: convert to ml (`let amountMl = waterUnit == "cups" ? Int(Double(waterIncrement) * 236.588) : waterIncrement`), then save a `WaterLogEntry` with `amountMl`, `wasDuringFocus` based on `PomodoroTimerStore.shared.isRunning && .focus`, and `focusSessionId: PomodoroTimerStore.shared.currentSessionId`
- `.onAppear` calls `ProductivityDataStore.shared.checkDailyReset()`
- Observe midnight via timer for auto-reset

---

## Charts

Use **Apple Swift Charts** (add `import Charts` to each chart file) for all standard charts:
- Bar charts (session per day, day per week, etc.)
- Line charts (drinking events timeline)
- Scatter plots (combined weekly/monthly)

Only custom `Path`/`Shape` drawing for:
- Goal ring (Pomodoro daily tab)
- Dual-axis chart (Combined daily tab) — or use two stacked charts sharing the same X-axis as a simpler alternative

Every chart view has an **empty state** when data is absent:
- "No sessions yet. Complete a focus session to see your stats."
- "No water logged yet. Start drinking to see your progress."

---

## New settings views

### New file: `boringNotch/components/Productivity/Dashboard/ProductivityDashboardView.swift`

Root container with a segmented picker: **Pomodoro | Water | Combined**.

### New file: `boringNotch/components/Productivity/Dashboard/PomodoroDashboardView.swift`

Daily / Weekly / Monthly tabs with bar charts + goal ring + summary text.

### New file: `boringNotch/components/Productivity/Dashboard/WaterDashboardView.swift`

Daily / Weekly / Monthly tabs with bar charts + progress bar + drinking event line chart.

### New file: `boringNotch/components/Productivity/Dashboard/CombinedDashboardView.swift`

Daily / Weekly / Monthly tabs:
- Daily: dual-axis chart (or two stacked charts) per session
- Weekly: scatter plot, one dot per day
- Monthly: scatter plot with trend line

### Modified: `boringNotch/components/Settings/ProductivitySettingsView.swift`

Extract the existing settings body into a `ProductivitySettingsContent` subview. Then add a segmented picker at the top: **Settings | Dashboard**.
- "Settings" shows `ProductivitySettingsContent()`
- "Dashboard" shows `ProductivityDashboardView()`

Add new settings with `@AppStorage` keys:
- Daily focus time goal — key `"dailyFocusGoalMinutes"`, type `Int`, default `120` (minutes)
- Drinking reminder interval — key `"drinkingReminderInterval"`, type `Int` (auto-calculated. User can override)
- Toggle: "Allow reminders during focus" — key `"allowRemindersDuringFocus"`, type `Bool`, default `false`
- Quiet hours start — key `"reminderQuietHoursStart"`, type `Int`, default `8` (hour, 24h format)
- Quiet hours end — key `"reminderQuietHoursEnd"`, type `Int`, default `0` (hour, 24h format, 0 = midnight)

---

## Execution to-do list

- [ ] **Step 1:** Create `boringNotch/models/ProductivityModels.swift` — `FocusSession` + `WaterLogEntry` structs
- [ ] **Step 2:** Create `boringNotch/managers/ProductivityDataStore.swift` — data persistence + computed stats + daily reset
- [ ] **Step 3:** Create `boringNotch/managers/DrinkingReminderManager.swift` — timer + sound + notch open logic
- [ ] **Step 4:** Update `PomodoroTimerView.swift` — save sessions on complete + interruption, show "Today: Xh Xm"
- [ ] **Step 5:** Update `WaterTrackerView.swift` — save water logs on increment, daily reset
- [ ] **Step 6:** Create dashboard chart views (PomodoroDashboardView, WaterDashboardView, CombinedDashboardView)
- [ ] **Step 7:** Create `ProductivityDashboardView.swift` — root container with 3-way segmented picker
- [ ] **Step 8:** Update `ProductivitySettingsView.swift` — add segmented picker (Settings / Dashboard) + new settings fields
- [ ] **Step 9:** Run `ruby update_prod_pbxproj.rb` after all new files are created
