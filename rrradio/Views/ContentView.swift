import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PlayerBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView: View {
    @StateObject private var store = StationStore()
    @StateObject private var player = AudioPlayerManager.shared
    @State private var showArtworkModal = false
    @State private var modalArtworkData: Data? = nil
    @State private var playerBarHeight: CGFloat = 0
    @State private var showAbout = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        mainContent
            .background { backgroundView }
            .konamiCode { showAbout = true }
            .overlay { aboutOverlay }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showAbout)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: player.currentArtworkData)
            .onChange(of: player.currentArtworkData) { newData in
                modalArtworkData = newData
            }
            .sheet(isPresented: $store.needsDefaultsPrompt) {
                DefaultImportView(store: store)
            }
            #if os(iOS)
            .sheet(isPresented: $showArtworkModal) {
                GeometryReader { geo in
                    ArtworkModalView(
                        artworkData: modalArtworkData,
                        station: player.currentStation,
                        songTitle: player.currentSongTitle,
                        artist: player.currentArtist,
                        track: player.currentTrack,
                        stationName: player.currentStation?.name,
                        availableSize: geo.size,
                        onDismiss: { showArtworkModal = false }
                    )
                }
                .presentationDetents([.large])
            }
            #endif
            .onAppear {
                setupRemoteCommands()
                resumeLastStation()
            }
    }

    // MARK: - Platform layouts

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            StationListView(store: store, player: player)
            PlayerControlsView(player: player)
        }
        .frame(minWidth: 500, minHeight: 400)
        .overlay(alignment: .bottomLeading) {
            if let artworkData = player.currentArtworkData,
               let artworkImage = Image(data: artworkData) {
                Button(action: { modalArtworkData = artworkData; showArtworkModal = true }) {
                    artworkImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .padding(.leading, 16)
                .padding(.bottom, 10)
                .id(artworkData)
                .transition(.opacity)
            }
        }
        .overlay {
            GeometryReader { geo in
                if showArtworkModal {
                    Color.black.opacity(0.45)
                        .onTapGesture { showArtworkModal = false }
                        .overlay {
                            ArtworkModalView(
                                artworkData: modalArtworkData,
                                station: player.currentStation,
                                songTitle: player.currentSongTitle,
                                artist: player.currentArtist,
                                track: player.currentTrack,
                                stationName: player.currentStation?.name,
                                availableSize: geo.size,
                                onDismiss: { showArtworkModal = false }
                            )
                            .background(Color.rrBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
                        }
                }
            }
        }
        #else
        NavigationStack {
            StationListView(store: store, player: player, bottomInset: playerBarHeight)
                .navigationTitle("rrradio")
                .navigationBarTitleDisplayMode(.large)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerControlsView(player: player, onArtworkTap: {
                modalArtworkData = player.currentArtworkData
                showArtworkModal = true
            })
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PlayerBarHeightKey.self, value: geo.size.height)
                }
            )
        }
        .onPreferenceChange(PlayerBarHeightKey.self) { playerBarHeight = $0 }
        #endif
    }

    @ViewBuilder
    private var aboutOverlay: some View {
        if showAbout {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showAbout = false }
                .overlay {
                    AboutModalView(onDismiss: { showAbout = false })
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
                }
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        #if os(macOS)
        if let bg = NSImage(named: "bg") {
            Image(nsImage: bg)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(Color.white.opacity(0.85))
        }
        #else
        Image("bg")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(Color.white.opacity(0.85))
        #endif
    }

    // MARK: - Helpers

    private func setupRemoteCommands() {
        NowPlayingManager.shared.configure(
            onPlay: { Task { @MainActor in player.resume() } },
            onPause: { Task { @MainActor in player.pause() } },
            onPlayPause: { Task { @MainActor in player.togglePlayPause() } },
            onNext: { Task { @MainActor in cycleStation(forward: true) } },
            onPrevious: { Task { @MainActor in cycleStation(forward: false) } }
        )
    }

    private func resumeLastStation() {
        guard let lastID = player.lastPlayedStationID(),
              let station = store.stations.first(where: { $0.id == lastID }) else { return }
        player.currentStation = station
    }

    private func cycleStation(forward: Bool) {
        guard !store.stations.isEmpty else { return }
        let current = store.stations.firstIndex(where: { $0.id == player.currentStation?.id })
        let count = store.stations.count
        let next: Int
        if let idx = current {
            next = forward ? (idx + 1) % count : (idx - 1 + count) % count
        } else {
            next = forward ? 0 : count - 1
        }
        player.play(station: store.stations[next])
    }
}

// MARK: - Konami code easter egg

#if os(macOS)
/// Listens for the Konami code (↑ ↑ ↓ ↓ ← → ← → B A) on the hardware keyboard.
private struct KonamiCodeModifier: ViewModifier {
    let onActivate: () -> Void
    @State private var monitor: Any?
    @State private var index = 0

    // keyCodes: Up Up Down Down Left Right Left Right B A
    private static let sequence: [UInt16] = [126, 126, 125, 125, 123, 124, 123, 124, 11, 0]

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    advance(with: event.keyCode)
                    return event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }

    private func advance(with key: UInt16) {
        if key == Self.sequence[index] {
            index += 1
            if index == Self.sequence.count {
                index = 0
                onActivate()
            }
        } else {
            // Reset, but allow this key to start a fresh sequence.
            index = (key == Self.sequence[0]) ? 1 : 0
        }
    }
}

extension View {
    func konamiCode(perform action: @escaping () -> Void) -> some View {
        modifier(KonamiCodeModifier(onActivate: action))
    }
}
#else
extension View {
    /// No hardware keyboard on iOS — the easter egg is macOS-only.
    func konamiCode(perform action: @escaping () -> Void) -> some View { self }
}
#endif

// MARK: - About modal

struct AboutModalView: View {
    let onDismiss: () -> Void

    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "radio")
                .font(.system(size: 44))
                .foregroundColor(.rrAccent)
                .padding(.top, 32)

            VStack(spacing: 4) {
                Text("rrradio")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.rrPrimaryText)
                Text(versionText)
                    .font(.system(size: 12))
                    .foregroundColor(.rrSecondaryText)
            }

            Text("Written by Rutger Smit")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.rrPrimaryText)

            Text("The name is a tip of the hat to Van Morrison, who belts out \u{201C}radio\u{201D} during \u{201C}Caravan\u{201D} with The Band at The Last Waltz \u{2014} their 1976 farewell concert. Listen for it right around 2:55.")
                .font(.system(size: 13))
                .foregroundColor(.rrSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            if let url = URL(string: "https://www.youtube.com/watch?v=4q9GDvXI0rk&t=178s") {
                Link(destination: url) {
                    Label("Watch on YouTube", systemImage: "play.rectangle")
                        .font(.system(size: 13))
                }
            }

            Text("\u{2191} \u{2191} \u{2193} \u{2193} \u{2190} \u{2192} \u{2190} \u{2192} B A")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.rrSecondaryText.opacity(0.5))
                .padding(.top, 2)

            Button("Close") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
                .padding(.top, 4)
                .padding(.bottom, 28)
        }
        .frame(width: 360)
        .background(Color.rrBackground)
    }
}
