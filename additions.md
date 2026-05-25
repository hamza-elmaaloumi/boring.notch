## Productivity section changes

### 1. Pomodoro

- Each time a focus session completes, save it with: date, time, duration, and whether it was finished or interrupted.
- Display on the pomodoro timer in the notch: "Today: 1h 30m focused" so you can see daily progress at a glance.
- Allow setting a daily focus time goal in Settings.

### 2. Water tracker

- Reset water consumed to 0 at the start of each new day. Save water consumption history with date and time so hydration habits can be tracked over time.
- Drinking reminder: opens the notch automatically + plays a water sound. The user sets a daily water goal; the reminder interval is calculated automatically based on that goal, and the user can still manually edit the interval in Settings.
- Log water during focus sessions: track how much water was consumed inside focus sessions vs. outside of them.

### 3. Settings → Dashboard section

A new section in Settings with three separate dashboards, each having Daily, Weekly, and Monthly tabs.

#### 3a. Pomodoro Dashboard

**Daily tab:**
- Bar chart with one bar per focus session (X-axis = start time, Y-axis = duration in minutes). Green if finished, red/orange if interrupted.
- Summary line below: *"3 sessions · 1h 15m total · 25m avg"*
- Goal ring or progress bar: *"Focus goal: 1h 15m / 2h"*

**Weekly tab:**
- Bar chart with one bar per day (Mon–Sun). Y-axis = total focus minutes. Line overlay showing the daily goal.
- Summary: *"This week: 8h 20m focused · 4.2h avg per day"*

**Monthly tab:**
- Bar chart with one bar per day of the month (1–30/31). Y-axis = total focus minutes. Goal line overlay.
- Summary: *"This month: 32h 15m focused · 1h 05m avg per day"*

#### 3b. Water Dashboard

**Daily tab:**
- Horizontal progress bar: *"600ml / 2000ml"* with color gradient (red → green).
- Line chart or dots showing each drinking event throughout the day (X-axis = time, Y-axis = amount).
- Summary: *"Next reminder in 45 min"*

**Weekly tab:**
- Bar chart with one bar per day (Mon–Sun). Y-axis = total ml. Goal line.
- Summary: *"This week: 8.5L / 14L goal · Best day: Wednesday (2.1L)"*

**Monthly tab:**
- Same as weekly with 30 bars (one per day).
- Summary: *"This month: 38L / 60L goal · Average: 1.27L per day"*

#### 3c. Combined Dashboard

Purpose: show the relationship between focus and hydration (not just two charts side by side).

**Daily tab:**
- Dual-axis chart: bars = focus minutes per session (left Y-axis), line = water in ml (right Y-axis). X-axis = each session of the day.
- Summary: *"Today: 600ml during focus · 200ml outside focus"*

**Weekly tab:**
- Scatter plot: one dot per day. X-axis = total focus minutes. Y-axis = total water ml. Shows if more focus correlates with more water.
- Summary: *"Your most focused days are also your most hydrated days"*

**Monthly tab:**
- Same scatter plot with 30 dots (one per day). Optional trend line.
- Summary: *"Days above 2h focus averaged 1.8L water. Days below 1h focus averaged 1.1L water."*

Session history and charts live only in this Settings dashboard — they are not shown in the notch.
