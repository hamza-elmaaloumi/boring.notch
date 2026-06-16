# Persistent Ideas Note Implementation Plan

> **Instructions for Build Agent:** You are operating in a fresh session with zero prior context. Do not make assumptions. Implement this plan task-by-task. After each task, if a build command is specified, run it and do not proceed until it passes.

## 1. Overview & Context

- **Goal:** Add a multi-line text input field in the Productivity tab, positioned below the Pomodoro timer, that spans the remaining vertical space down to the notch bottom. Notes are persistent across notch open/close cycles and app restarts.

- **Core Workflow:** User opens the Productivity tab → sees the Pomodoro timer at top-left → below it, a text area with placeholder "Write your ideas..." → types notes → notes auto-save to UserDefaults via the `Defaults` package → notes persist until the user manually edits or deletes them.

- **Discovered Codebase Constraints:**
  - Swift 6 concurrency is strictly enforced — all classes holding UI state must be `@MainActor`. For this feature, the view is already `@MainActor` by virtue of being a SwiftUI `View`.
  - New `.swift` files must be placed inside `boringNotch/` (any subdirectory) and then linked via `ruby update_prod_pbxproj.rb`. The script dynamically scans `boringNotch/` for all `.swift` files, so placing the file in `boringNotch/components/Productivity/` is sufficient.
  - The `Defaults` package (`import Defaults`) is used project-wide for persistent key-value storage. The `@Default` property wrapper is the standard pattern (e.g., `@Default(.ideasNote) var ideasNote`).
  - All views use dark color scheme (`.preferredColorScheme(.dark)` in ContentView). Background colors follow a grayscale scale: `Color(white: 0.08)`, `Color(white: 0.1)`, `Color(white: 0.12)`.
  - `TextEditor` must use `.scrollContentBackground(.hidden)` on macOS to make the background transparent (matching the notch's dark background).
  - No test targets exist in the project — verification is done via Xcode build (`xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build`).

## 2. Technical Architecture & Schemas

### System Design

```
ProductivityRootView (HStack)
│
├── VStack (left column, .frame(maxHeight: .infinity))
│   ├── PomodoroTimerView (fixed 130pt wide, intrinsic height ~200pt)
│   └── IdeasNoteView (130pt wide, fills remaining vertical space)
│
├── Divider()
│
├── WaterTrackerView (300x300pt fixed)
└── WaterLogListView (.frame(maxWidth: .infinity))
```

### Data Model / Schema Changes

**UserDefaults key** (via `Defaults` package — no raw key used):

| Key | Type | Default | Location |
|-----|------|---------|----------|
| `ideasNote` | `String` | `""` | `Constants.swift:232` (under `// MARK: Productivity`) |

Declaration in `Defaults.Keys` extension:
```swift
static let ideasNote = Key<String>("ideasNote", default: "")
```

### External Dependencies

**None.** The `Defaults` package is already a project dependency. No new packages, APIs, or environment variables.

## 3. Implementation Tasks

### Task 1: Add `ideasNote` Defaults Key

- **File Impacts:**
  - *Modify:* `boringNotch/models/Constants.swift` — line 233 (after `customCupAmount`)

- **Detailed Instructions:**
  1. Open `boringNotch/models/Constants.swift`.
  2. Navigate to the `// MARK: Productivity` section (currently lines 230–233).
  3. After `static let customCupAmount = Key<Int>("customCupAmount", default: 250)`, add a new line:
     ```swift
     static let ideasNote = Key<String>("ideasNote", default: "")
     ```

- **Verification Command:** Run `grep -n "ideasNote" boringNotch/models/Constants.swift` to confirm the key exists.

---

### Task 2: Create `IdeasNoteView.swift`

- **File Impacts:**
  - *Create:* `boringNotch/components/Productivity/IdeasNoteView.swift`

- **Detailed Instructions:**

  1. Create the file at the path above with the following content:

  ```swift
  import SwiftUI
  import Defaults

  struct IdeasNoteView: View {
      @Default(.ideasNote) private var text

      var body: some View {
          ZStack(alignment: .topLeading) {
              if text.isEmpty {
                  Text("Write your ideas...")
                      .foregroundColor(Color(white: 0.4))
                      .padding(.horizontal, 4)
                      .padding(.vertical, 6)
                      .font(.system(size: 11))
              }

              TextEditor(text: $text)
                  .scrollContentBackground(.hidden)
                  .background(Color.clear)
                  .font(.system(size: 11))
                  .foregroundColor(.white)
                  .frame(maxHeight: .infinity)
                  .padding(.horizontal, 2)
          }
          .frame(maxHeight: .infinity)
          .background(Color(white: 0.08))
          .cornerRadius(8)
          .padding(.bottom, 4)
      }
  }
  ```

  2. Ensure the file is inside `boringNotch/components/Productivity/` so the Ruby script picks it up automatically.

  **Key design decisions:**
  - `.scrollContentBackground(.hidden)` — required on macOS to make TextEditor background transparent, otherwise it renders an opaque white background.
  - `Color(white: 0.08)` — matches the background shade used by `WaterLogListView` (`WaterLogListView.swift:53`), consistent with the dark notch theme.
  - Placeholder overlay via `ZStack` — a `Text` view with `Color(white: 0.4)` appears only when `text.isEmpty`. This is simpler and more robust than using a `TextEditor` placeholder extension.
  - `font(.system(size: 11))` — matches the caption-level text size used throughout the Productivity tab (same as `WaterLogListView` and `todaySummaryText` in PomodoroTimerView).
  - `.padding(.bottom, 4)` — aligns the bottom of the card with the notch bottom padding (ProductivityRootView has `.padding(.bottom, 10)`).

- **Verification Command:** `ls boringNotch/components/Productivity/IdeasNoteView.swift`

---

### Task 3: Modify `ProductivityRootView` to Embed the Notes View

- **File Impacts:**
  - *Modify:* `boringNotch/components/Productivity/ProductivityRootView.swift` — replace PomodoroTimerView line with a VStack

- **Detailed Instructions:**

  1. Open `boringNotch/components/Productivity/ProductivityRootView.swift`.
  2. Replace the current `HStack` body with:

  ```swift
  struct ProductivityRootView: View {
      var body: some View {
          HStack(alignment: .top, spacing: 12) {
              VStack(spacing: 8) {
                  PomodoroTimerView()
                      .frame(width: 130)
                  IdeasNoteView()
                      .frame(width: 130)
              }
              .frame(maxHeight: .infinity, alignment: .top)

              Divider()
              WaterTrackerView()
              WaterLogListView()
                  .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(.horizontal, 12)
          .padding(.top, 4)
          .padding(.bottom, 10)
      }
  }
  ```

  **Key layout details:**
  - `VStack(spacing: 8)` — groups the Pomodoro timer (top) and the notes field (bottom). The `8pt` spacing matches the internal spacing of `PomodoroTimerView` (`.padding(.horizontal, 10)` and internal `VStack(spacing: 8)`).
  - `.frame(maxHeight: .infinity, alignment: .top)` — makes the left column stretch to the full height of the `HStack` (380pt notch minus 14pt vertical padding = 366pt). The PomodoroTimerView sits at the top, and IdeasNoteView fills the remaining space.
  - Both `PomodoroTimerView` and `IdeasNoteView` are constrained to `width: 130` to maintain the same column width as before.
  - `Divider()` remains between the left column and the water tracking column.
  - `WaterTrackerView` and `WaterLogListView` are unchanged.

- **Verification Command:** Run the build (see Task 5), or at minimum visually inspect the diff shows correct indentation and structure.

---

### Task 4: Link the New File via Ruby Script

- **File Impacts:**
  - *Run:* `update_prod_pbxproj.rb` (no file editing)

- **Detailed Instructions:**
  1. Open terminal in the project root (`boringNotch/`).
  2. Run:
     ```bash
     ruby update_prod_pbxproj.rb
     ```
  3. Confirm the output: `Linked N Swift files to target 'boringNotch'` (the count should have incremented by 1 from the previous count).

  4. Verify the file was added to the project:
     ```bash
     grep -c "IdeasNoteView" boringNotch.xcodeproj/project.pbxproj
     ```
     Expected output: `1` or more (the file reference appears in the pbxproj).

  **Why this is required:** The project does not use Xcode's automatic file registration. The `update_prod_pbxproj.rb` script dynamically scans `boringNotch/` for `.swift` files and adds them to the Xcode project's `sourceBuildPhase`. Without this step, the compiler would fail with "cannot find 'IdeasNoteView' in scope".

- **Verification Command:** `ruby update_prod_pbxproj.rb` and then `grep -c "IdeasNoteView" boringNotch.xcodeproj/project.pbxproj`

---

### Task 5: Full Build Verification

- **File Impacts:**
  - *Run:* `xcodebuild` from project root

- **Detailed Instructions:**
  1. From the project root (`boringNotch/`), run:
     ```bash
     xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build
     ```

  2. The build must succeed with **`** BUILD SUCCEEDED **`** message.

  3. If the build fails, examine the error. Likely issues:
     - `"cannot find 'IdeasNoteView' in scope"` → Task 4 was not run, or the file is outside `boringNotch/`.
     - `"Value of type 'IdeasNoteView' has no member 'init'"` → Check the struct is `public` or internal (no access modifier = internal by default, which is fine).
     - `"'scrollContentBackground' is unavailable"` → Verify `import SwiftUI` is present. On older macOS targets, this modifier requires macOS 13+; the project targets macOS 14+, so it's safe.

- **Verification Command:** `xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5`
