# Fix: Pomodoro Daily Counter & Pause/Resume Bugs

## Overview

The pomodoro timer has three interrelated bugs that cause the daily focused-time counter to be
incorrect and focus progress to be silently lost. Together they make the "Today: Xh Ym focused"
summary untrustworthy and undermine the pomodoro feature's core value proposition.

| # | Bug | Severity | File |
|---|-----|----------|------|
| 1 | **Double counting on pause/resume** — every pause inflates the daily total | HIGH | `PomodoroTimerStore.swift` |
| 2 | **Mode switch discards unsaved progress** — switching from Focus to Break after a pause loses the session | MEDIUM | `PomodoroTimerStore.swift` |
| 3 | **Post-restart sessionStartDate inflation** — app relaunch after quit shows fake "today" hours | HIGH | `PomodoroTimerStore.swift` |

---

## Execution Order

Fix these **in order** — Fix 1 is the root cause of the daily counter corruption and Fix 3 depends on
understanding the `sessionStartDate` lifecycle that Fix 1 corrects.

---

## Fix 1 — Stop double-counting when user pauses and resumes

### Description of the Problem

The pomodoro timer has a "Today: Xh Ym focused" summary at `PomodoroTimerView.swift:23-38` that
combines two sources: saved sessions from `ProductivityDataStore.totalFocusTimeToday()` and a live
counter `PomodoroTimerStore.elapsedFocusedSeconds`. The live counter computes elapsed time from
`sessionStartDate` — the moment the current focus session began.

When the user pauses the timer, `pauseTimer()` saves an incomplete `FocusSession` with the time
elapsed so far, but **never clears `sessionStartDate`**. After resume, the live counter continues
counting from that same original start date. The result: the same time interval is counted twice —
once as a saved session and once as the live counter.

This gets **worse with every pause/resume cycle**. Each pause saves a larger session (accumulating
from the original start), and the live counter also grows from that same original start. The daily
summary quickly becomes meaningless.

### Evidence of the Issue (Walkthrough with Numbers)

**Setup:** Default 25-minute focus timer. User starts fresh with no sessions today.
`focusSessions = []`, `sessionStartDate = nil`.

| Step | Action | `focusSessions` (saved) | `sessionStartDate` | `elapsedFocusedSeconds` (live) | Displayed "Today" |
|------|--------|------------------------|-------------------|-------------------------------|-------------------|
| 1 | Start focus at t=0 | `[]` | t=0 | 0 | "Today: 0m focused" |
| 2 | Focus for 10 min (t=600) | `[]` | t=0 | 600 | "Today: 10m focused" |
| 3 | **Pause** at t=600 | `[{dur: 600}]` | **t=0 (NOT cleared)** | **600** | **"Today: 20m focused"** ← 2× |
| 4 | Resume, focus 5 min (t=900) | `[{dur: 600}]` | t=0 | 900 | "Today: 25m" ← still wrong |
| 5 | **Pause again** at t=900 | `[{dur: 600}, {dur: 900}]` | **t=0 (NOT cleared)** | **900** | **"Today: 40m focused"** ← 2.66× |

After step 5:
- `totalFocusTimeToday()` = 600 + 900 = **1500s (25 min)**
- `elapsedFocusedSeconds` = `Int(Date().timeIntervalSince(t=0))` = **900s (15 min)**
- Displayed = 1500 + 900 = **2400s (40 min)**
- **Actual focus time: 15 min. Displayed: 40 min.** Overcount: **166%.**

If the user pauses 3 times during a single 25-minute focus block, the overcount compounds further:

| Pauses | Actual work | Displayed "Today" | Overcount |
|--------|------------|-------------------|-----------|
| 0 | 25 min | 25 min | 0% |
| 1 | 25 min | 35 min | 40% |
| 2 | 25 min | 55 min | 120% |
| 3 | 25 min | 85 min | 240% |

### Effect on Application Reputation

This is a **credibility-destroying bug** for a productivity app. The pomodoro timer's daily summary
is the primary metric users rely on to track their focus. If it overcounts by 2–3× after a single
pause, users will:

1. **Mistrust all app statistics** — "If today's counter is wrong, are weekly/monthly stats also
   wrong?" User churn follows.
2. **Report the app as buggy in App Store reviews** — The "Today" counter is displayed prominently
   in both the timer view and the dashboard. Users notice numerical discrepancies immediately.
3. **Abandon the pomodoro feature** — The feature becomes noise instead of a useful tool,
   defeating its purpose.
4. **Spread negative word-of-mouth** — "The focus timer can't even count time correctly."

Since this is a **macOS notch enhancement app** that differentiates itself through polish and
utility, a broken core counter directly contradicts the app's value proposition.

### Root Cause (Code Analysis)

**File:** `boringNotch/models/PomodoroTimerStore.swift`

**`pauseTimer()` — Lines 178-199:**

```swift
private func pauseTimer() {
    updateRemainingTime()

    if currentMode == .focus, let start = sessionStartDate {
        let actualDuration = Int(Date().timeIntervalSince(start))
        if actualDuration > 0 {
            let session = FocusSession(
                startDate: start,
                endDate: Date(),
                durationSeconds: actualDuration,  // ① Saved: elapsed from start to now
                mode: currentMode.rawValue,
                completed: false
            )
            ProductivityDataStore.shared.saveFocusSession(session)
        }
    }
    // ② sessionStartDate is NOT cleared — it still points to the original start time

    timer?.invalidate()
    timer = nil
    isRunning = false
    deadline = nil
    // ❌ Missing: sessionStartDate = nil
}
```

**`elapsedFocusedSeconds` — Lines 39-42:**

```swift
var elapsedFocusedSeconds: Int {
    guard currentMode == .focus, let start = sessionStartDate else { return 0 }
    return Int(Date().timeIntervalSince(start))  // ③ Still counts from original start
}
```

**`todaySummaryText` — PomodoroTimerView.swift:24-26:**

```swift
let saved = ProductivityDataStore.shared.totalFocusTimeToday()  // includes the pause-saved session
let live = timerStore.elapsedFocusedSeconds                      // counts from same origin
let total = saved + live  // ← DOUBLE COUNT: same time appears in both sources
```

The design intent is clear: `saved` holds completed/paused segments and `live` shows the current
running segment. But because `sessionStartDate` is never invalidated on pause, the "live" segment
overlaps with the just-saved segment.

### Fix

Clear `sessionStartDate` after saving the incomplete session in `pauseTimer()`. Keep
`currentSessionId` so water-log cross-references (see `WaterTrackerView.swift:436-441`) still
work for the paused segment.

#### File: `boringNotch/models/PomodoroTimerStore.swift`

#### Before

Lines 178-199:

```swift
    private func pauseTimer() {
        updateRemainingTime()

        if currentMode == .focus, let start = sessionStartDate {
            let actualDuration = Int(Date().timeIntervalSince(start))
            if actualDuration > 0 {
                let session = FocusSession(
                    startDate: start,
                    endDate: Date(),
                    durationSeconds: actualDuration,
                    mode: currentMode.rawValue,
                    completed: false
                )
                ProductivityDataStore.shared.saveFocusSession(session)
            }
        }

        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
    }
```

#### After

```swift
    private func pauseTimer() {
        updateRemainingTime()

        if currentMode == .focus, let start = sessionStartDate {
            let actualDuration = Int(Date().timeIntervalSince(start))
            if actualDuration > 0 {
                let session = FocusSession(
                    startDate: start,
                    endDate: Date(),
                    durationSeconds: actualDuration,
                    mode: currentMode.rawValue,
                    completed: false
                )
                ProductivityDataStore.shared.saveFocusSession(session)
            }
            // Clear so elapsedFocusedSeconds stops counting from this origin.
            // currentSessionId is kept so existing water-log refs still work.
            sessionStartDate = nil
        }

        timer?.invalidate()
        timer = nil
        isRunning = false
        deadline = nil
    }
```

### What This Changes

- **After pause:** `sessionStartDate = nil` → `elapsedFocusedSeconds` returns 0 (the guard at
  line 40 fails) → `todaySummaryText` shows only `saved` (correct single count).
- **On resume:** `startTimer()` at line 160 checks `if sessionStartDate == nil, currentMode == .focus`
  → true → creates a **new** `sessionStartDate = Date()` and a **new** `currentSessionId = UUID()`.
  The resumed segment is tracked independently and correctly.
- **Water logs:** `currentSessionId` is NOT cleared in this fix, so any water entries logged during
  the original segment still reference the original session UUID. The new segment gets a new UUID.

#### Retrace with Fix Applied

| Step | Action | `focusSessions` (saved) | `sessionStartDate` | `elapsedFocusedSeconds` | Displayed "Today" |
|------|--------|------------------------|-------------------|------------------------|-------------------|
| 1 | Start at t=0 | `[]` | t=0 | 0 | "0m" |
| 2 | Focus 10 min | `[]` | t=0 | 600 | "10m" |
| 3 | **Pause** at t=600 | `[{dur: 600}]` | **nil** | **0** | **"10m" ← correct** |
| 4 | Resume, 5 min | `[{dur: 600}]` | t=600 | 300 (from t=600 to t=900) | "15m" ← correct |
| 5 | **Pause** at t=900 | `[{dur: 600}, {dur: 300}]` | nil | 0 | **"15m" ← correct** |

After step 5: `totalFocusTimeToday()` = 600 + 300 = 900s (15 min). **Matches actual focus time.** ✓

---

## Fix 2 — Save progress before mode switch discards it

### Description of the Problem

Users can switch between Focus, Short Break, and Long Break modes using the segmented picker at
`PomodoroTimerView.swift:43-49`. This calls `selectMode()` in `PomodoroTimerStore`.

If a user has been focusing, pauses the timer, then switches to a different mode (e.g., Short
Break), the focus session they just completed is **silently discarded** — it is never saved to
`ProductivityDataStore`. The user sees their daily counter unchanged and all progress is gone.

This is especially insidious because the user may not notice — the UI shows a fresh timer in the
new mode, and there is no confirmation dialog or undo.

### Evidence of the Issue (Walkthrough with Numbers)

**Setup:** User focused for 20 min, then paused.

| Step | Action | `currentMode` | `focusSessions` | Expected | Actual |
|------|--------|---------------|----------------|----------|--------|
| 1 | Focus for 20 min, pause | `.focus` | `[{dur: 1200}]` | Session saved | ✓ Saved |
| 2 | Tap "Short Break" in picker | `.shortBreak` | `[{dur: 1200}]` | Timer resets, session preserved | ✓ |
| 3 | Tap "Focus" again | `.focus` | **`[{dur: 1200}]`** | **Previous session still there** | **✓ It is** |
| 4 | Focus for 10 min, **pause** | `.focus` | `[{dur: 1200}]` | Saved session = 600s from this segment | **Wait – what's saved?** |

At step 4: `pauseTimer()` runs, but `sessionStartDate` is nil (it was cleared by the pause at step 1
and not re-created because the user didn't resume — they switched modes). So `pauseTimer()` hits
`if currentMode == .focus, let start = sessionStartDate` → **false** → nothing saved. The 10 min
are lost.

The actual damage path is simpler and more common:

1. Start focus timer → focus 20 min → **pause**
2. Switch mode to Short Break
3. `selectMode()` sets `currentMode = .shortBreak` → calls `resetTimer()`
4. `resetTimer()` checks `if currentMode == .focus` → **false** (it's now `.shortBreak`)
5. **20 min of focus are discarded without warning**

### Effect on Application Reputation

This creates a **hidden data-loss trap** that violates the principle of least surprise:

- Users learn the hard way that pausing then switching modes erases their work. Trust erodes.
- In a productivity app, losing time-tracking data is particularly infuriating — users may not
  realize it happened until they check their dashboard at the end of the day.
- Reviews mentioning "lost focus time" or "timer doesn't save correctly" directly impact ranking
  and conversion.
- The UX provides no feedback — the timer silently resets, giving the false impression that
  everything is fine.

### Root Cause (Code Analysis)

**File:** `boringNotch/models/PomodoroTimerStore.swift`

**`selectMode()` — Lines 92-97:**

```swift
func selectMode(_ mode: Mode) {
    guard currentMode != mode else { return }
    currentMode = mode          // ← MODE IS CHANGED FIRST
    hasCompleted = false
    resetTimer()                // ← THEN resetTimer() runs with new mode
}
```

**`resetTimer()` — Lines 107-133:**

```swift
func resetTimer() {
    if currentMode == .focus, let start = sessionStartDate {
        //                  ^^^^^^^^  already false by the time we get here
        // ... save session ...
    }
    // ... reset all state ...
}
```

The order is wrong. When `selectMode()` changes `currentMode` first, the guard at `resetTimer()`
line 108 sees the **new** mode, not the mode the user was actually focusing in. The session save is
skipped and all state (`sessionStartDate`, `currentSessionId`, `hasActiveSession`) is zeroed out
without ever recording the session.

The same bug applies for a **running** timer: if the user starts focus, then without pausing
switches to Short Break, the running timer is stopped and discarded. `selectMode()` doesn't call
`pauseTimer()` either, so `updateRemainingTime()` is never called to finalize `timeRemaining`.

### Fix

Reorder `selectMode()` so the current session is saved before `currentMode` is mutated. Two cases:

1. **Timer is running** → call `pauseTimer()` first (which saves and clears state properly).
2. **Timer is paused (`hasActiveSession = true`, `isRunning = false`)** → `pauseTimer()` won't
   trigger its run-logic since `isRunning` is false, so save the session explicitly.

#### File: `boringNotch/models/PomodoroTimerStore.swift`

#### Before

Lines 92-97:

```swift
    func selectMode(_ mode: Mode) {
        guard currentMode != mode else { return }
        currentMode = mode
        hasCompleted = false
        resetTimer()
    }
```

#### After

```swift
    func selectMode(_ mode: Mode) {
        guard currentMode != mode else { return }

        // Save the current session before switching, regardless of run state.
        if currentMode == .focus {
            if isRunning {
                // Running → pause first (saves session, clears sessionStartDate)
                pauseTimer()
            } else if hasActiveSession, let start = sessionStartDate {
                // Paused → save the incomplete session manually
                let actualDuration = Int(Date().timeIntervalSince(start))
                if actualDuration > 0 {
                    let session = FocusSession(
                        startDate: start,
                        endDate: Date(),
                        durationSeconds: actualDuration,
                        mode: currentMode.rawValue,
                        completed: false
                    )
                    ProductivityDataStore.shared.saveFocusSession(session)
                }
                sessionStartDate = nil
                currentSessionId = nil
                hasActiveSession = false
            }
        }

        currentMode = mode
        hasCompleted = false
        resetTimer()
    }
```

### What This Changes

- **Running focus + mode switch:** `pauseTimer()` runs, which saves the incomplete session, clears
  `sessionStartDate`, invalidates the timer, and sets `isRunning = false`. Then `resetTimer()`
  completes the state reset with the new mode. The session is preserved.
- **Paused focus + mode switch:** The incomplete session is saved manually, then `sessionStartDate`,
  `currentSessionId`, and `hasActiveSession` are cleared. Then `resetTimer()` runs with the new
  mode. The session is preserved.
- **All other states:** `currentMode != .focus` → the save block is skipped, and `selectMode()`
  falls through to the existing `currentMode = mode + resetTimer()` behavior. Unaffected.

---

## Fix 3 — Stale `sessionStartDate` after app relaunch

### Description of the Problem

When the app terminates gracefully, `PomodoroTimerStore` saves runtime state via
`savePersistedState()` (an `NSApplication.willTerminateNotification` observer at line 63-82) and
also saves an incomplete `FocusSession`. On next launch, `restorePersistedState()` restores
`sessionStartDate` to its pre-termination value.

If the app was closed for an extended period (overnight, over a weekend, etc.), this `sessionStartDate`
is far in the past. The computed property `elapsedFocusedSeconds` then returns `Int(Date().timeIntervalSince(sessionStartDate))`
— a huge number that represents wall-clock time, not focus time.

The `todaySummaryText` view at `PomodoroTimerView.swift:24-26` reads this immediately on launch:

```swift
let saved = ProductivityDataStore.shared.totalFocusTimeToday() // e.g., 600s from termination save
let live = timerStore.elapsedFocusedSeconds                     // e.g., 86400s (24 hours!)
let total = saved + live                                        // 87000s = "Today: 24h 10m focused"
```

The user sees **24+ hours of focus time** for a session that ended when they quit the app yesterday.

### Evidence of the Issue (Walkthrough with Numbers)

**Setup:** User quits app at 10 PM after focusing 10 min. Relaunches at 8 AM next day.

| Step | Action | `sessionStartDate` | `focusSessions` | `elapsedFocusedSeconds` | Displayed "Today" |
|------|--------|-------------------|----------------|------------------------|-------------------|
| 1 | Start focus at 9:50 PM | 9:50 PM | `[]` | 0 | "0m" |
| 2 | Focus 10 min, quit at 10 PM | 9:50 PM | `[{dur: 600}]` | 600 (if running) | — |
| 3 | App saves state & session | 9:50 PM (saved) | `[{dur: 600}]` | — | — |
| 4 | **Relaunch at 8 AM next day** | **9:50 PM (restored)** | `[{dur: 600}]` | `Int(now - 9:50PM)` = **36600 (10.1h)** | **"Today: 10h 10m focused"** |
| 5 | User taps Play (resume) | 9:50 PM (unchanged) | `[{dur: 600}]` | grows from 36600 | gets worse |

The `sessionStartDate` is now **wrong by 10 hours**. The today counter is nonsense.

Additionally, the termination handler at line 70-81 saves a `FocusSession` with `actualDuration`
computed from wall-clock time since `sessionStartDate` (which includes the full session duration,
not accounting for pauses). But the bigger issue is the `sessionStartDate` being restored.

### Effect on Application Reputation

This creates a **spectacularly wrong display** that users will notice immediately:

- First launch of the day shows "Today: 10h 30m focused" when they've done nothing. This is
  laughably incorrect and signals "this app is broken."
- If the user is tracking their focus seriously, an overnight 10-hour ghost session pollutes their
  daily stats forever (the saved session is real; the live counter is not, but the display is what
  the user sees).
- Users who don't understand the bug may think the app is maliciously inflating their stats or
  leaking data. Trust is destroyed.
- The dashboard's `ProgressRingView` (PomodoroDashboardView.swift:89-93) shows the daily goal ring
  as fully filled — a demoralizing or confusing visual.

### Root Cause (Code Analysis)

**File:** `boringNotch/models/PomodoroTimerStore.swift`

**`restorePersistedState()` — Lines 295-312:**

```swift
private func restorePersistedState() {
    guard let data = UserDefaults.standard.data(forKey: persistenceKey),
          let state = try? JSONDecoder().decode(PersistedState.self, from: data),
          let mode = Mode(rawValue: state.currentModeRaw)
    else { return }

    currentMode = mode
    timeRemaining = max(1, state.timeRemaining)
    hasActiveSession = state.hasActiveSession
    consecutiveFocusSessions = state.consecutiveFocusSessions

    if let sessionIdStr = state.currentSessionId, let uuid = UUID(uuidString: sessionIdStr) {
        currentSessionId = uuid
    }
    sessionStartDate = state.sessionStartDate  // ← unconditionally restored, could be hours old

    clearPersistedState()
}
```

The `PersistedState` at line 48-56 includes `sessionStartDate: Date?` and `deadline: Date?`. On
restore:

- `deadline` is **not restored** (not in the restore code) — the timer does not auto-resume.
- `isRunning` is **not restored** — the timer appears paused.
- But `sessionStartDate` **is restored unconditionally** — and `elapsedFocusedSeconds` counts from
  it immediately, even though the timer isn't running.

The `PersistedState` also saves `hasActiveSession: true` and `timeRemaining` from the moment of
termination. The restored `timeRemaining` is correct (e.g., if 15 min remain, it shows 15 min). But
`elapsedFocusedSeconds` is a **separate computed property** that the view renderers read — it is
not part of the countdown logic.

The termination handler also saves a `FocusSession` (lines 70-81):

```swift
if self.hasActiveSession && self.currentMode == .focus {
    let now = Date()
    let actualDuration = Int(now.timeIntervalSince(self.sessionStartDate ?? now))
    let session = FocusSession(
        startDate: self.sessionStartDate ?? now,
        endDate: now,
        durationSeconds: actualDuration,
        mode: self.currentMode.rawValue,
        completed: false
    )
    ProductivityDataStore.shared.saveFocusSession(session)
}
```

This means on relaunch, `totalFocusTimeToday()` includes this termination-saved session, AND
`elapsedFocusedSeconds` counts from the same `sessionStartDate`. The result is double-counting
on top of the time-travel issue.

### Fix

After restoring, validate `sessionStartDate`. If the timer is not running and the start date
is more than 5 minutes in the past, clear `sessionStartDate` to prevent `elapsedFocusedSeconds`
from returning a stale value.

The 5-minute threshold is chosen because:
- A quick relaunch (e.g., user quit by accident and reopened) should preserve the session
  for seamless resume.
- Anything longer means the session is effectively abandoned — the saved `FocusSession` (from the
  termination handler) already captured the work done.

#### File: `boringNotch/models/PomodoroTimerStore.swift`

#### Before

Lines 295-312:

```swift
    private func restorePersistedState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data),
              let mode = Mode(rawValue: state.currentModeRaw)
        else { return }

        currentMode = mode
        timeRemaining = max(1, state.timeRemaining)
        hasActiveSession = state.hasActiveSession
        consecutiveFocusSessions = state.consecutiveFocusSessions

        if let sessionIdStr = state.currentSessionId, let uuid = UUID(uuidString: sessionIdStr) {
            currentSessionId = uuid
        }
        sessionStartDate = state.sessionStartDate

        clearPersistedState()
    }
```

#### After

```swift
    private func restorePersistedState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data),
              let mode = Mode(rawValue: state.currentModeRaw)
        else { return }

        currentMode = mode
        timeRemaining = max(1, state.timeRemaining)
        hasActiveSession = state.hasActiveSession
        consecutiveFocusSessions = state.consecutiveFocusSessions

        if let sessionIdStr = state.currentSessionId, let uuid = UUID(uuidString: sessionIdStr) {
            currentSessionId = uuid
        }

        // Only keep sessionStartDate if the app was closed briefly (≤ 5 min).
        // Otherwise the live counter (elapsedFocusedSeconds) would show a huge
        // inflated value counting from the old start date.
        if let start = state.sessionStartDate {
            if Date().timeIntervalSince(start) > 300 {
                sessionStartDate = nil
            } else {
                sessionStartDate = start
            }
        }

        clearPersistedState()
    }
```

### What This Changes

- **Quick relaunch (≤ 5 min):** `sessionStartDate` is preserved. User sees the timer as they left
  it. `elapsedFocusedSeconds` shows a small, reasonable value (~0-300s). Good.
- **Long closure (> 5 min):** `sessionStartDate` is cleared → `elapsedFocusedSeconds` returns 0
  → `todaySummaryText` reflects only saved sessions, which were correctly recorded during
  termination. User sees accurate daily stats. Good.
- **No persisted state (fresh install, cleared data):** The `guard` at line 296 exits early. No
  change to existing behavior.
- **Saved `FocusSession` from termination:** Still present in `focusSessions`. `totalFocusTimeToday()`
  counts it correctly. The today summary shows only the saved time, without the inflated live counter.

#### Retrace with Fix Applied

**Setup:** Same as before — quit at 10 PM (10 min focus), relaunch at 8 AM.

| Step | Action | `sessionStartDate` | `focusSessions` | `elapsedFocusedSeconds` | Displayed "Today" |
|------|--------|-------------------|----------------|------------------------|-------------------|
| 1 | Quit at 10 PM | 9:50 PM (saved) | `[{dur: 600}]` | — | — |
| 2 | Relaunch at 8 AM | Restored from state | `[{dur: 600}]` | — | — |
| 3 | `restorePersistedState()` runs | Checks: `now - start > 300`? **Yes** → **sets nil** | — | 0 | "Today: 10m focused" ✓ |
| 4 | User taps Play (resume) | Creates **new** `sessionStartDate = 8 AM` | `[{dur: 600}]` | 0 → grows from 8 AM | Correct from now on ✓ |

---

## Verification Checklist

After applying all three fixes, these user flows should be tested by building and running the app:

### Fix 1 — Double counting

| Flow | Expected outcome |
|------|-----------------|
| Start → Pause (×1) → Resume → Complete | Daily counter = full duration (no inflation) |
| Start → Pause → Resume → Pause → Resume → Complete | Daily counter = full duration (no overcount) |
| Start → Pause → Resume → Pause (×3 rapid) → Resume → Complete | Daily counter = full duration |
| Start → Complete (no pause) | Daily counter = full duration (unchanged) |

### Fix 2 — Mode switch data loss

| Flow | Expected outcome |
|------|-----------------|
| Start Focus → Pause → Switch to Short Break → Switch back to Focus | Focus progress from first segment preserved |
| Start Focus (running, unpaused) → Switch to Short Break | Focus progress saved as incomplete session |
| Start Short Break → Pause → Switch to Focus | Break session not saved (not focus mode — correct) |
| Switch modes repeatedly with no active session | No spurious 0-duration sessions saved |

### Fix 3 — Post-restart inflation

| Flow | Expected outcome |
|------|-----------------|
| Quit while focus running → Relaunch 5+ min later | "Today" shows only saved time, no inflated live counter |
| Quit while focus paused → Relaunch 5+ min later | "Today" shows only saved time |
| Quit while focus running → Relaunch within 1 min | `sessionStartDate` preserved, live counter shows small offset |
| Force-kill app (no termination handler) → Relaunch | Timer starts fresh (no state to restore) |

### Regression checks

| Flow | Expected outcome |
|------|-----------------|
| Water log entry during focus → pause → resume → new water log | Both entries reference their respective session UUIDs |
| Dashboard daily chart | `sessionsToday()` counts match `totalFocusTimeToday()` |
| Dashboard weekly/monthly charts | Aggregations consistent across periods |
| Notch timer display (`showsTimeInNotch`) | Timer shows/hides correctly based on `isRunning` + `currentMode` |
