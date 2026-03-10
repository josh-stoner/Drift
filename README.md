# Drift

Behavioral pattern awareness for focused work. A macOS menu bar app that tracks work sessions, fires contextual nudges based on configurable patterns, and helps you build better time awareness.

## Features

- **Menu bar timer** — Start sessions with a task name and time estimate. Elapsed time shown in the menu bar.
- **Pattern-based nudges** — Configurable patterns fire at specific intervals (e.g., "You've been at this for 30 minutes"). System notifications + popover.
- **Session history** — Review past sessions with timeline, nudge events, and response data.
- **Retrospective view** — See how your estimates compare to actuals over time.
- **Data export/import** — JSON-based, fully portable.
- **Auto-update** — Built-in Sparkle updater checks for new releases.

## Install

### Download

1. Go to [Releases](https://github.com/josh-stoner/Drift/releases/latest)
2. Download `Drift-vX.X.X.zip`
3. Unzip and drag `Drift.app` to `/Applications`

### First Launch (Gatekeeper)

Since Drift is not notarized with an Apple Developer ID, macOS will block it on first launch:

1. Open `Drift.app` — you'll see "cannot be opened because the developer cannot be verified"
2. Open **System Settings > Privacy & Security**
3. Scroll down — you'll see "Drift was blocked". Click **Open Anyway**
4. Confirm in the dialog

You only need to do this once.

### Build from Source

Requires: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
git clone https://github.com/josh-stoner/Drift.git
cd Drift
xcodegen generate
open Drift.xcodeproj
# Build & Run (Cmd+R)
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel

## Tech

- SwiftUI + AppKit (NSStatusItem, NSPopover, NSWindow)
- `@Observable` / `@Bindable` (no ObservableObject)
- Catppuccin Mocha dark theme
- Sparkle 2 for auto-updates
- XcodeGen for project generation
- GitHub Actions for CI/CD

## License

Copyright 2026 Josh Stoner. All rights reserved.
