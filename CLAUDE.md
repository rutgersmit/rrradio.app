# rrradio — macOS Native App

## Project Overview
Native macOS radio streaming app built with SwiftUI. Port of the PWA at https://rrradio.nl.
For personal use only — no App Store distribution.

## Tech Stack
- SwiftUI, macOS 13+
- AVFoundation (AVPlayer) for streaming
- MediaPlayer framework (MPRemoteCommandCenter, MPNowPlayingInfoCenter)
- No third-party dependencies

## Key Files
- `AudioPlayerManager.swift` — singleton, owns AVPlayer instance
- `NowPlayingManager.swift` — MPNowPlayingInfoCenter + MPRemoteCommandCenter
- `StationStore.swift` — persistence via UserDefaults/JSON
- `AppColors.swift` — all color definitions for light/dark mode

## Build
```bash
xcodebuild -scheme rrradio -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build
```

## Conventions
- No hardcoded colors — use AppColors
- Platform-specific code in `#if os(macOS)` / `#if os(iOS)` blocks
- Bundle ID: nl.rrradio.app
