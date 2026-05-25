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
- **The Ruby Script:** IMMEDIATELY after creating ANY new file, you MUST run the command: `ruby update_prod_pbxproj.rb`. 
- **Why:** If you skip running this script, the new file will not be linked to the Master List/Xcode target, and the compiler will throw a "cannot find in scope" error.

### 2. STRICT SWIFT 6 CONCURRENCY
- This project strictly enforces Swift 6 concurrency rules.
- **Non-Sendable Types:** Types like `NSImage`, `NSView`, and other AppKit/UI classes are non-Sendable. They CANNOT be passed across actor boundaries or stored inside background `Task` dictionaries.
- **UI & State:** If a Service or Manager holds `NSImage` state or updates the UI, you MUST mark the entire class with `@MainActor`.
- **Background Processing:** If you need to process images in the background, you must use thread-safe types like `Data` or `CGImage`. NEVER use `NSImage` for background processing.
