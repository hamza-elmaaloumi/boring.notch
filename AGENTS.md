# Boring Notch — Agent Guide

## Project

macOS 14+ SwiftUI app that enhances the MacBook notch.  
Xcode 16+, Swift 6.1. Entry point: `boringNotch/boringNotchApp.swift` (`@main struct DynamicNotchApp: App`).

## Build

```bash
# Debug / unsigned (no code signing)
xcodebuild -scheme boringNotch -configuration Debug CODE_SIGNING_ALLOWED=NO build

# Release archive (requires signing)
xcodebuild clean archive -project boringNotch.xcodeproj -scheme boringNotch -archivePath boringNotch -destination "generic/platform=macOS"

# Resolve SPM deps without building
xcodebuild -resolvePackageDependencies -project boringNotch.xcodeproj
```

DMG creation: `Configuration/dmg/create_dmg.sh <app_path> <output.dmg> <volume_name>` (requires `dmgbuild` Python package).

No npm/web tooling. No linter/formatter beyond Xcode defaults.

## Tests

**No test targets exist.** CI only builds — no test step.

## Dependencies

Swift Package Manager only. Resolved in `boringNotch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.  
Key packages: Sparkle (auto-updater), Defaults, KeyboardShortcuts, Lottie, AsyncXPCConnection, LaunchAtLogin-Modern, SkyLightWindow, MacroVisionKit, Pow.

## XPC Helper

`BoringNotchXPCHelper/` — XPC service for accessibility permissions and media key interception.  
Protocol: `BoringNotchXPCHelperProtocol`. Client: `XPCHelperClient`.

## Submodule

`mediaremote-adapter/` — framework for Now Playing source on macOS 15.4+. Requires `git submodule update --init`.

## Localization

Crowdin: https://crowdin.com/project/boring-notch. Source file: `boringNotch/Localizable.xcstrings`. New strings sync automatically from `dev` branch; Crowdin PRs merge translations back.

## Branch strategy

- **Code changes** → target `dev`. Never `main`.
- **Metadata only** (README, CONTRIBUTING, SECURITY, LICENSE, .gitignore, crowdin.yml, .github/) → may target `main`.
- Fork PRs are CI-enforced to only target `dev` or `main`.

## Release

- Admin comments `/release` on a PR from `dev` → `main`.
- Version extracted from comment via `.github/scripts/extract_version.py`.
- Pipeline: build → sign → DMG → Sparkle appcast → GitHub release → Homebrew cask update (`TheBoredTeam/homebrew-boring-notch`).
- Stable releases auto-merge `dev` → `main`. Beta releases only update appcast on `main`.
- Version lives in `boringNotch.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`); CI bumps it during release.

## App structure

```
boringNotch/
├── boringNotchApp.swift        — entry point
├── BoringViewCoordinator.swift — central view state
├── ContentView.swift           — root SwiftUI view
├── models/                     — BoringViewModel, BatteryStatusVM, etc.
├── managers/                   — Music, Calendar, Clipboard, Brightness, Volume
├── components/                 — UI by feature (Notch, Music, Shelf, Calendar, etc.)
├── observers/                  — MediaKeyInterceptor, DragDetector
├── extensions/                 — Swift extensions
├── helpers/ utils/ enums/     — shared utilities
├── metal/                      — Metal shaders
├── Shortcuts/                  — Siri Shortcuts
├── XPCHelperClient/            — XPC client
└── Localizable.xcstrings       — localizations

## 🚨 CRITICAL BUILD AND ARCHITECTURE RULES 🚨

### 1. NEW FILES & XCODE PROJECT LINKING (CRITICAL)
- We do not use Xcode; we compile via GitHub Actions. 
- **Rule of Order:** NEVER reference, instantiate, or use a new class, manager, or struct (e.g., `PomodoroTimerManager`) in a View unless you have explicitly created its underlying implementation file FIRST.
- **The Ruby Script:** IMMEDIATELY after creating ANY new `.swift` file, you MUST add its relative path to the linking script `update_prod_pbxproj.rb` (or ensure the script's dynamic scan will pick it up) AND run `ruby update_prod_pbxproj.rb` BEFORE committing or pushing.
- **Why:** If you skip running this script, the new file will not be linked to the Master List/Xcode target, and the compiler will throw a "cannot find in scope" error.
- **The script now dynamically scans the entire `boringNotch/` directory for Swift files, so any new file placed inside `boringNotch/` will be auto-linked. If you place a file outside this directory, you must add it manually to the script.**

### 2. macOS SWIFTUI RESTRICTIONS
- Never use iOS-only SwiftUI APIs. Specifically, `editMode` (`.environment(\.editMode, ...)`) is completely unavailable on macOS targets.
- To manage list editing, item deleting, or view toggling on macOS, use custom `@State` or `@Binding` boolean flags instead.

### 3. STRICT SWIFT 6 CONCURRENCY
- This project strictly enforces Swift 6 concurrency rules.
- **Non-Sendable Types:** Types like `NSImage`, `NSView`, and other AppKit/UI classes are non-Sendable. They CANNOT be passed across actor boundaries or stored inside background `Task` dictionaries.
- **UI & State:** If a Service or Manager holds `NSImage` state or updates the UI, you MUST mark the entire class with `@MainActor`.
- **Background Processing:** If you need to process images in the background, you must use thread-safe types like `Data` or `CGImage`. NEVER use `NSImage` for background processing.
- **`deinit` in `@MainActor` classes:** In Swift 6, `deinit` is NOT isolated to the class's global actor. You CANNOT call `@MainActor`-isolated methods from `deinit`. Inline cleanup directly instead (e.g., `timer?.invalidate(); timer = nil` rather than calling `stop()`).
- **Queue-based isolation is NOT recognized:** `.main` queue dispatch does NOT satisfy actor isolation in Swift 6. The compiler only tracks actor annotations, not dispatch queues. If a closure runs on `.main` queue but is not `@MainActor`-annotated, it is treated as non-isolated. Use `Task { @MainActor in ... }` to bridge.
- **`@Sendable` closures + non-Sendable `self`:** APIs like `NSItemProvider.loadItem(forTypeIdentifier:options:completionHandler:)` take `@Sendable` completion handlers. Capturing `self` (which is non-Sendable for AppKit/Foundation types) inside a `@Sendable` closure is illegal. ALWAYS use `[weak self]` capture list + `guard let self` in completion handlers passed to Foundation/AppKit APIs.

### 4. VERIFICATION PROCESS (NO XCODE ON DEV MACHINE)
- **I CANNOT BUILD locally.** Xcode is not installed on this machine. Every change I make is blind.
- **I must read the ENTIRE file before editing it** — not just the lines reported in the error. Unrelated bugs in the same file will surface once the compiler reaches it.
- **After every change, the user MUST build** to verify. Do not batch multiple fixes before asking for a build — errors compound and become harder to trace.
- **Never trust "ran successfully" from a script as proof the script did what was intended.** Verify the output matches expectations (e.g., check `grep` for the expected entries in `project.pbxproj` after running the linker script).

### 5. VIEWBUILDER RULES (SWIFTUI)
- `ViewBuilder` closures (in `body`, `.overlay`, `.background`, etc.) only accept:
  - `View`-conforming expressions (e.g., `Text(...)`, `Image(...)`, `Color(...)`)
  - `let` bindings of View types
  - Control flow (`if`, `switch`, `ForEach`)
- You CANNOT place arbitrary statements inside a `ViewBuilder` block:
  - Mutating objects: `formatter.dateFormat = ...` ❌
  - Calling void-returning functions: `someFunction()` ❌
  - Creating non-View objects that aren't captured by a `let` bound to a `View`:
    - `let formatter = DateFormatter()` ❌ (DateFormatter is not a View)
- **Fix:** Move logic into a computed property, helper function, or use SwiftUI's built-in formatters (e.g., `date.formatted(date:time:)` instead of `DateFormatter`).

### 6. KNOW YOUR DATA TYPES BEFORE COMPARISON
- Before using `proxy.value(atX: as: SomeType.self)` in a `.chartOverlay`, verify the actual type of the axis data. A chart's x-axis may use `String` for some data and `Int` for others depending on the backing struct.
- Never assume `.day` is a `String` — check whether the struct stores `day: String` (day name) or `day: Int` (day-of-month number).
- Rule: **Read the surrounding `BarMark(x: .value("Day", item.day))` usage** — if the stat lines later use `item.day` in string interpolation without formatting, the type might not be what you assume. Cross-check with the data store method signature.

### 7. SELECTOR SAFETY IN APPKIT
- `#selector(...)` requires the method to exist on the class or its superclass, and the method must be marked `@objc`. Before using `#selector(foo)`, verify:
  1. The method `foo` is defined in this class (or superclass), not in a different class.
  2. The method is exposed with `@objc` (e.g., `@objc private func foo()`).
- Dead classes (files that exist but are never instantiated or referenced) still get compiled. If they contain unresolvable selectors, they will fail the build. Audit the entire file, not just the parts you change.

### 8. FEATURE REQUEST CLARIFICATION PROTOCOL
- When the user asks to add, implement, or change a feature, you MUST reformulate the request in your own structured words before writing any code.
- The goal is to confirm shared understanding and eliminate ambiguity before implementation begins.
- Structure your reformulation as:
  1. **Summary** — One-line description of what the feature does
  2. **Behavior** — How it works from the user's perspective (inputs, outputs, interactions, UI flow)
  3. **Scope** — What is included and what is explicitly out of scope
  4. **Open questions** — Any ambiguities, missing details, or design choices needing clarification
- Do NOT proceed to implementation until the user confirms your reformulation is correct.
