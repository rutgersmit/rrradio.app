# rrradio — Native Radio App (macOS + iOS)

## Project Overview
Native radio streaming app built with SwiftUI, sharing one codebase across macOS and iOS. Port of the PWA at https://rrradio.nl.
For personal use only — no App Store distribution.

## Tech Stack
- SwiftUI — macOS 13+ and iOS 17+
- AVFoundation (AVPlayer) for streaming; AVAudioSession on iOS
- MediaPlayer framework (MPRemoteCommandCenter, MPNowPlayingInfoCenter)
- No third-party dependencies

## Targets & Schemes
- `rrradio` — macOS target, bundle ID `nl.rrradio.app`
- `rrradio-iOS` — iOS target, bundle ID `nl.rrradio.app.ios`

## Layout & Key Files
- `rrradio/Managers/`
  - `AudioPlayerManager.swift` — singleton, owns AVPlayer instance
  - `NowPlayingManager.swift` — MPNowPlayingInfoCenter + MPRemoteCommandCenter
  - `StationStore.swift` — persistence via UserDefaults/JSON
  - `CatalogFetcher.swift` — loads station catalog (remote, falls back to bundled)
- `rrradio/Models/` — `RadioStation.swift` and catalog models
- `rrradio/Views/` — SwiftUI views (ContentView, StationListView, PlayerControlsView, etc.)
- `RemoteConfig.swift` — remote catalog/image base URLs (GitHub-hosted)
- `AppColors.swift` — all color definitions for light/dark mode

## Build
```bash
# macOS
xcodebuild -scheme rrradio -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build

# iOS (simulator)
xcodebuild -scheme rrradio-iOS -configuration Release \
  -sdk iphonesimulator CODE_SIGNING_REQUIRED=NO build
```

## Conventions
- No hardcoded colors — use AppColors
- Platform-specific code in `#if os(macOS)` / `#if os(iOS)` blocks; guard all AppKit (NSImage/NSColor/NSCursor) uses
- Keep both targets compiling — shared code must build for macOS and iOS

## Git Workflow
- Always work on a `feature/...` or `fix/...` branch — never commit directly to `main`.
- Never commit without asking first.
