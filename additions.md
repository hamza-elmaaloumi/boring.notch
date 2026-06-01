# Dashboard UI changes

## Remove combined diagram
- Delete `boringNotch/components/Productivity/Dashboard/CombinedDashboardView.swift`
- Remove any reference to `CombinedDashboardView` from `ProductivityDashboardView.swift`
- Remove `CombinedDashboardView` from Xcode project target (run `python update_prod_pbxproj.rb`)

## Remove dashboard switching toggle
- `ProductivityDashboardView.swift` currently has a `Picker` with 3 options: Pomodoro, Water, Combined
- Replace it with a **vertical stack** that shows PomodoroDashboardView on top and WaterDashboardView below
- No segmented picker, no switching — both visible at once

## Move period toggles to bottom of each diagram
- `PomodoroDashboardView.swift`: Move the `Picker` (Daily / Weekly / Monthly) from the top of the `VStack` to the **bottom**, after the chart content
- `WaterDashboardView.swift`: Same — move the `Picker` from the top to the bottom
- Each diagram's period picker controls only its own diagram (they remain independent)
