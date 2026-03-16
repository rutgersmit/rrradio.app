# rrradio

A native macOS radio streaming app. No Electron, no web view, no banners, no fluff — just a clean, fast app that plays internet radio and stays out of your way. Free.

Port of [rrradio.nl](https://rrradio.nl) for the desktop.

---

## Features

- Stream any internet radio station — MP3, AAC, ICY streams
- Album art fetched automatically for the current song
- Media keys, Control Center, and Touch Bar all work
- Menu Bar Extra — play/pause and station info without opening the window
- Add, edit, and delete your own stations
- Recovers automatically after a network blip
- Keeps playing when the window is closed
- Light and dark mode

## Default Stations

On first launch, rrradio offers a curated list of stations to import. You can pick the countries and stations you want — nothing is added without your choice. Afterwards you can add, edit, or remove any station at any time.

## Finding Stream URLs

To add a station, you need its direct stream URL. Good places to find one:

- [radio-browser.info](https://www.radio-browser.info/) — community-maintained directory of stations worldwide
- [streamurl.link](https://streamurl.link/) — find stream URLs for well-known stations

## Installation

Download the latest `.app` from [Releases](../../releases) and drag it to your Applications folder.

**First launch:** macOS may block the app because it's not from the App Store. To open it anyway:

1. Right-click `rrradio.app` → **Open**
2. Click **Open** in the dialog that appears

Or go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## Technical

### Requirements

- macOS 13 Ventura or later
- Xcode 15+ (to build from source)

### How It Works

Built with SwiftUI and AVFoundation. Song metadata arrives as ICY timed metadata via `AVPlayerItemMetadataOutput`. When a new title comes in, the app queries the iTunes Search API to find album art, fetches it at 1200×1200, and shows it in both the player bar thumbnail and the full-screen artwork modal.

The modal stays open across song changes — the artwork fades out, updates, and fades back in. If no artwork is available, the station's own image is shown as a placeholder.

Now Playing info is handled via `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`, which powers Control Center, Touch Bar, and media key support.

### Build & Run

```bash
# Quick build and launch
./build.sh

# Or manually
xcodebuild \
  -project rrradio.xcodeproj \
  -scheme rrradio \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

No signing required for local builds.

### Project Structure

```text
rrradio/
├── rrradioApp.swift              # App entry, MenuBarExtra, AppDelegate
├── AppColors.swift               # All colours for light/dark mode
├── Models/
│   └── RadioStation.swift        # Data model + built-in default stations
├── Managers/
│   ├── AudioPlayerManager.swift  # AVPlayer singleton, ICY metadata, artwork fetch
│   ├── NowPlayingManager.swift   # MPNowPlayingInfoCenter + remote command centre
│   └── StationStore.swift        # UserDefaults persistence
└── Views/
    ├── ContentView.swift          # Root layout, artwork modal
    ├── StationListView.swift      # Responsive station grid
    ├── StationCardView.swift      # Individual station card
    ├── PlayerControlsView.swift   # Bottom player bar + artwork modal view
    ├── StationImageView.swift     # Async image with local fallback
    ├── AddEditStationView.swift   # Add/edit sheet with image crop
    └── ImageCropView.swift        # Square crop picker
```

### Dependencies

Zero third-party dependencies.

---

## Credits

- App icon generated with [Icon Kitchen](https://icon.kitchen/i/H4sIAAAAAAAAA0WPwQ6CMAyG36VePUgIRrhy8AH0ZjyUrRuLg-FgGkN4d7uBcYdu_dp8-TfDC22gEaoZlK6ddR4q2Kl0YA_Nnx0xl3RipvT1MxAjYc2Afkqo3t7sGYkvkKQw2Dg0wvUMiMftM-CDYIniTaI9SkN9XGz0-ddEzeSGlOuwJirLPCbKYncoKON87MFeW9bkWZGklxbXaMYL5sw6J4ONH7zxrvTOyBjJjVzf1HDtUHB3X76dWEtuCwEAAA)

*Not affiliated with any of the listed stations.*

## License

MIT License. See LICENSE.
