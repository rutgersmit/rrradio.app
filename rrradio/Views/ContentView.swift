import SwiftUI

struct ContentView: View {
    @StateObject private var store = StationStore()
    @StateObject private var player = AudioPlayerManager.shared
    @State private var showArtworkModal = false

    var body: some View {
        VStack(spacing: 0) {
            StationListView(store: store, player: player)
            PlayerControlsView(player: player)
        }
        .frame(minWidth: 500, minHeight: 400)
        .overlay(alignment: .bottomLeading) {
            if let artworkData = player.currentArtworkData,
               let nsImage = NSImage(data: artworkData) {
                Button(action: { showArtworkModal = true }) {
                    Image(nsImage: nsImage)
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
            }
        }
        .overlay {
            GeometryReader { geo in
                if showArtworkModal,
                   let artworkData = player.currentArtworkData,
                   let nsImage = NSImage(data: artworkData) {
                    Color.black.opacity(0.45)
                        .onTapGesture { showArtworkModal = false }
                        .overlay {
                            ArtworkModalView(
                                nsImage: nsImage,
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
        .onAppear {
            setupRemoteCommands()
            resumeLastStation()
        }
    }

    private func setupRemoteCommands() {
        NowPlayingManager.shared.configure(
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
