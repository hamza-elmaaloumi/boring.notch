# Water Cup Shape Fix — Execution Plan

> **Instructions for Build Agent:** You are operating in a fresh session with zero prior context. Do not make assumptions. Implement this plan task-by-task. After each task, if a build command is specified, run it and do not proceed until it passes.

## 1. Overview & Context

- **Goal:** Redraw the `TaperedGlassShape` and `TaperedGlassIcon` water fill to match the reference image — a clean, smooth glass with rounded corners at ALL four corners, slightly curved concave sides, and a gentle single-wave water fill that follows the glass geometry.

- **Core Workflow:** The `TaperedGlassIcon` is used in two places:
  1. `CupPickerView.swift:62` — custom cup cell at 28x34pt
  2. `WaterTrackerView.swift:349` — auxiliary button at 16x20pt

  Both must look clean at small sizes. No other files reference these shapes.

- **Discovered Codebase Constraints:**
  - `TaperedGlassShape` and `TaperedGlassIcon` are defined in `boringNotch/components/Productivity/WaterTrackerView.swift` (lines 51-137). They are NOT used anywhere else.
  - The glass stroke color is `.blue` (line 98). The water fill color is `Color(red: 0.28, green: 0.56, blue: 0.86)` (line 134). The water tracker arc uses `Color(red: 0.247, green: 0.663, blue: 0.988)` (line 239) — these should be unified.
  - The `TaperedGlassIcon` composes: stroke outline + masked water fill inside. The mask uses `TaperedGlassShape().scale(0.92).offset(y: 1)` (line 101).
  - All views use dark color scheme. Background behind the glass is `Color(white: 0.2)` circle (line 345).
  - The glass must render correctly at both 28x34 and 16x20 — bezier curves must be smooth at small sizes, no point-by-point generation.

## 2. Technical Architecture & Schemas

### What's wrong — detailed path analysis

**`TaperedGlassShape` current path (lines 51-86):**
```
1. move(topLeftX, 0)           ← sharp corner, no radius
2. addLine(topRightX, 0)       ← straight top, sharp corner
3. addLine(bottomRightX-R, H)  ← straight diagonal side
4. addArc(bottomRight)         ← tiny radius min(6, bottomWidth*0.15) ≈ 3px at 28w
5. addLine(bottomLeftX+R, H)   ← straight bottom
6. addArc(bottomLeft)          ← tiny radius
7. addLine(topLeftX, 0)        ← straight diagonal side, back to sharp start
```
Problems: top corners completely sharp, bottom corners too small, sides perfectly straight, no curvature.

**`TaperedGlassIcon` water fill (lines 105-136):**
```
1. move(bottomLeftX+1, h-2)    ← doesn't follow glass shape
2. addArc(bottomRightX-5, h-5, r:3) ← arc doesn't match glass bottom corners
3. addLine(topRightX-2, waterTop)   ← straight up, ignores glass taper
4. for x in stride(...) addLine     ← point-by-point sine = jagged at small sizes
5. closeSubpath()
```
Problems: water ignores glass geometry, wave is jagged, bottom alignment wrong.

### Target geometry

**Glass shape (reference image):**
- Top width: 100% of rect.width
- Bottom width: 72% of rect.width (keep current taper ratio)
- Top corner radius: 15% of rect.width (smooth, proportional)
- Bottom corner radius: 10% of rect.width (smaller but visible)
- Sides: slight inward concave curve via quadratic bezier
- Stroke: blue, 2pt lineWidth

**Water fill (reference image):**
- Fills from bottom of glass up to `fillPercentage`
- Water tapers with the glass shape (follows glass outline internally via mask)
- Top surface: one gentle sine wave (single period, ~6% amplitude of height)
- Wave drawn with cubic bezier curves, NOT point-by-point stride
- Color: `Color(red: 0.247, green: 0.663, blue: 0.988)` — unified with water tracker arc

## 3. Implementation Tasks

### Task 1: Rewrite `TaperedGlassShape` with rounded corners and curved sides

- **File Impacts:**
  - *Modify:* `boringNotch/components/Productivity/WaterTrackerView.swift` — replace lines 51-86

- **Detailed Instructions:**

  Replace the entire `TaperedGlassShape` struct with the following. The path uses named variables for every geometric point so the logic is auditable:

  ```swift
  struct TaperedGlassShape: Shape {
      func path(in rect: CGRect) -> Path {
          let w = rect.width
          let h = rect.height

          let bottomWidth = w * 0.72

          let topLeftX: CGFloat = 0
          let topRightX: CGFloat = w
          let bottomLeftX = (w - bottomWidth) / 2
          let bottomRightX = (w + bottomWidth) / 2

          let topRadius = w * 0.15
          let bottomRadius = w * 0.10

          let sideInset: CGFloat = w * 0.02

          return Path { path in
              // Start: top edge, after top-left corner
              path.move(to: CGPoint(x: topLeftX + topRadius, y: 0))

              // Top edge → top-right corner
              path.addLine(to: CGPoint(x: topRightX - topRadius, y: 0))
              path.addArc(
                  center: CGPoint(x: topRightX - topRadius, y: topRadius),
                  radius: topRadius,
                  startAngle: .degrees(270),
                  endAngle: .degrees(0),
                  clockwise: false
              )

              // Right side: gentle inward curve
              path.addQuadCurve(
                  to: CGPoint(x: bottomRightX, y: h - bottomRadius),
                  control: CGPoint(
                      x: topRightX - sideInset,
                      y: h * 0.5
                  )
              )

              // Bottom-right corner
              path.addArc(
                  center: CGPoint(x: bottomRightX - bottomRadius, y: h - bottomRadius),
                  radius: bottomRadius,
                  startAngle: .degrees(0),
                  endAngle: .degrees(90),
                  clockwise: false
              )

              // Bottom edge
              path.addLine(to: CGPoint(x: bottomLeftX + bottomRadius, y: h))

              // Bottom-left corner
              path.addArc(
                  center: CGPoint(x: bottomLeftX + bottomRadius, y: h - bottomRadius),
                  radius: bottomRadius,
                  startAngle: .degrees(90),
                  endAngle: .degrees(180),
                  clockwise: false
              )

              // Left side: gentle inward curve
              path.addQuadCurve(
                  to: CGPoint(x: topLeftX, y: topRadius),
                  control: CGPoint(
                      x: bottomLeftX + sideInset,
                      y: h * 0.5
                  )
              )

              // Top-left corner
              path.addArc(
                  center: CGPoint(x: topLeftX + topRadius, y: topRadius),
                  radius: topRadius,
                  startAngle: .degrees(180),
                  endAngle: .degrees(270),
                  clockwise: false
              )

              path.closeSubpath()
          }
      }
  }
  ```

  **Key geometry decisions:**
  - `topRadius = w * 0.15` — at 28pt width = 4.2pt radius. Visible, smooth, proportional.
  - `bottomRadius = w * 0.10` — at 28pt width = 2.8pt radius. Smaller than top, matches reference.
  - `sideInset = w * 0.02` — very subtle inward curve. At 28pt = 0.56pt. Just enough to break the straight line without looking warped.
  - `addQuadCurve` control point at `h * 0.5` — the curve peaks at the vertical midpoint.
  - Arc directions: `clockwise: false` for all corners (counterclockwise in screen coords = clockwise in math coords).

- **Verification Command:** `ruby update_prod_pbxproj.rb && xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5`

---

### Task 2: Rewrite `TaperedGlassIcon` water fill with smooth bezier wave

- **File Impacts:**
  - *Modify:* `boringNotch/components/Productivity/WaterTrackerView.swift` — replace lines 88-137

- **Detailed Instructions:**

  Replace the entire `TaperedGlassIcon` struct with the following. The water fill now:
  1. Uses the glass shape as a mask (no path alignment issues)
  2. Draws a filled rectangle from bottom to water level
  3. Applies a smooth sine wave on top using cubic bezier curves
  4. Uses the unified water color

  ```swift
  struct TaperedGlassIcon: View {
      var fillPercentage: CGFloat = 0.55

      private let waterColor = Color(red: 0.247, green: 0.663, blue: 0.988)

      var body: some View {
          TaperedGlassShape()
              .stroke(.blue, lineWidth: 2)
              .background(
                  waterFill
                      .mask(
                          TaperedGlassShape()
                              .scale(0.92)
                              .offset(y: 1)
                      )
              )
      }

      private var waterFill: some View {
          GeometryReader { geo in
              let w = geo.size.width
              let h = geo.size.height
              let waterTop = h * (1 - fillPercentage)
              let waveAmplitude: CGFloat = h * 0.06

              Path { path in
                  // Start at bottom-left
                  path.move(to: CGPoint(x: 0, y: h))

                  // Bottom edge to bottom-right
                  path.addLine(to: CGPoint(x: w, y: h))

                  // Right side up to water level
                  path.addLine(to: CGPoint(x: w, y: waterTop))

                  // Smooth sine wave from right to left (two cubic bezier segments)
                  // First half: right → center (peak)
                  path.addCurve(
                      to: CGPoint(x: w * 0.5, y: waterTop),
                      control1: CGPoint(x: w * 0.75, y: waterTop - waveAmplitude),
                      control2: CGPoint(x: w * 0.65, y: waterTop - waveAmplitude)
                  )

                  // Second half: center → left (trough)
                  path.addCurve(
                      to: CGPoint(x: 0, y: waterTop),
                      control1: CGPoint(x: w * 0.35, y: waterTop + waveAmplitude),
                      control2: CGPoint(x: w * 0.25, y: waterTop + waveAmplitude)
                  )

                  path.closeSubpath()
              }
              .fill(waterColor)
          }
      }
  }
  ```

  **Key water fill decisions:**
  - Water path goes from `(0, h)` to `(w, h)` to `(w, waterTop)` — fills the entire bottom of the rect. The glass shape mask clips it to the tapered shape.
  - `waveAmplitude = h * 0.06` — at 28pt height = 1.68pt. Very gentle, matches reference.
  - Two `addCurve` calls create a single sine wave period: peak at `w*0.75`, trough at `w*0.25`.
  - Control points at `±waveAmplitude` from `waterTop` create smooth S-curves.
  - Color unified with water tracker arc: `Color(red: 0.247, green: 0.663, blue: 0.988)`.
  - Removed the hardcoded `topLeftX`, `topRightX`, `bottomLeftX`, `bottomRightX` properties — they were incorrect and are no longer needed since the mask handles the glass shape.

- **Verification Command:** `xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5`

---

### Task 3: Final build verification

- **File Impacts:** None (build-only)

- **Detailed Instructions:**

  1. Run the full build:
     ```bash
     xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -10
     ```

  2. Confirm **`** BUILD SUCCEEDED **`**.

  3. If it fails, check:
     - `"cannot find 'TaperedGlassShape' in scope"` → the struct name was changed or removed
     - `"cannot find 'TaperedGlassIcon' in scope"` → same issue
     - Any other errors → examine the full build log

  4. Visually inspect the diff to confirm:
     - `TaperedGlassShape` now has 4 rounded corners (topRadius and bottomRadius)
     - Both sides use `addQuadCurve` instead of `addLine`
     - `TaperedGlassIcon` water fill uses `addCurve` instead of `stride` + `addLine`
     - Water color is `Color(red: 0.247, green: 0.663, blue: 0.988)`

- **Verification Command:** `xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5`

- **Git Commit Message:** `fix: redraw water glass shape with smooth corners and bezier wave fill`
