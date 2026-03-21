import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var player: AudioPlayerManager

    private var statusText: String {
        if player.isLoading { return "Connecting…" }
        if player.isReconnecting { return "Reconnecting…" }
        if player.isPlaying { return "Live" }
        return "Stopped"
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                // Placeholder for artwork / station logo
                if player.currentArtworkData != nil {
                    Color.clear.frame(width: 100, height: 42)
                } else if let station = player.currentStation {
                    StationImageView(station: station)
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.rrCard)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "radio")
                                .foregroundColor(.rrSecondaryText)
                        )
                }

                // Station info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentStation?.name ?? "No station selected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.rrPrimaryText)
                        .lineLimit(1)
                    if let song = player.currentSongTitle {
                        Text(song)
                            .font(.system(size: 11))
                            .foregroundColor(.rrSecondaryText)
                            .lineLimit(1)
                    } else {
                        Text(statusText)
                            .font(.system(size: 11))
                            .foregroundColor(player.isReconnecting ? .orange : .rrSecondaryText)
                    }
                }

                Spacer()

                // Play/Pause
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.rrAccent)
                            .frame(width: 36, height: 36)

                        if player.isLoading || player.isReconnecting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(player.currentStation == nil)
                .accessibilityLabel(player.isLoading ? "Connecting" : player.isReconnecting ? "Reconnecting" : player.isPlaying ? "Stop" : "Play")

                // Volume
                HStack(spacing: 4) {
                    Button(action: { player.isMuted.toggle() }) {
                        Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .font(.system(size: 10))
                            .foregroundColor(player.isMuted ? .rrAccent : .rrSecondaryText)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help(player.isMuted ? "Unmute" : "Mute")
                    .accessibilityLabel(player.isMuted ? "Unmute" : "Mute")

                    Slider(value: $player.volume, in: 0...1)
                        .frame(width: 80)
                        .tint(.rrAccent)
                        .focusable(false)
                        .accessibilityLabel("Volume")

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.rrSecondaryText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}

struct ArtworkModalView: View {
    let artworkData: Data?
    let station: RadioStation?
    let songTitle: String?
    let artist: String?
    let track: String?
    let stationName: String?
    let availableSize: CGSize
    let onDismiss: () -> Void

    @State private var displayedImage: NSImage?
    @State private var imageOpacity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(artworkData: Data?, station: RadioStation?, songTitle: String?, artist: String?, track: String?, stationName: String?, availableSize: CGSize, onDismiss: @escaping () -> Void) {
        self.artworkData = artworkData
        self.station = station
        self.songTitle = songTitle
        self.artist = artist
        self.track = track
        self.stationName = stationName
        self.availableSize = availableSize
        self.onDismiss = onDismiss
        self._displayedImage = State(initialValue: artworkData.flatMap { NSImage(data: $0) })
    }

    private var artworkDimension: CGFloat {
        let fromWidth = availableSize.width * 0.75
        let fromHeight = availableSize.height * 0.60
        return min(min(fromWidth, fromHeight), 800).rounded()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let img = displayedImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let station = station {
                    StationImageView(station: station)
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.rrCard)
                        .overlay(
                            Image(systemName: "radio")
                                .font(.system(size: 48))
                                .foregroundColor(.rrSecondaryText)
                        )
                }
            }
            .frame(width: artworkDimension, height: artworkDimension)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(imageOpacity)
            .padding(.top, 32)
            .padding(.horizontal, 32)
            .onTapGesture { onDismiss() }
            .onChange(of: artworkData) { newData in
                if reduceMotion {
                    displayedImage = URLSecurityPolicy.boundedLocalImageData(newData).flatMap { NSImage(data: $0) }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { imageOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        displayedImage = URLSecurityPolicy.boundedLocalImageData(newData).flatMap { NSImage(data: $0) }
                        withAnimation(.easeIn(duration: 0.25)) { imageOpacity = 1 }
                    }
                }
            }

            VStack(spacing: 4) {
                Text(track ?? "\u{00A0}")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.rrPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(artist ?? songTitle ?? "\u{00A0}")
                    .font(.system(size: 13))
                    .foregroundColor(.rrSecondaryText)
                    .lineLimit(1)

                Text(stationName ?? "\u{00A0}")
                    .font(.system(size: 11))
                    .foregroundColor(.rrSecondaryText.opacity(0.6))
                    .padding(.top, 2)
            }
            .padding(.top, 20)
            .padding(.horizontal, 32)

            if let spotifyDestination = spotifyURL ?? defaultSpotifyURL,
               let youtubeDestination = youtubeURL ?? defaultYouTubeURL {
                HStack(spacing: 16) {
                    Link(destination: spotifyDestination) {
                        Label("Spotify", systemImage: "music.note")
                            .font(.system(size: 13))
                    }
                    Link(destination: youtubeDestination) {
                        Label("YouTube", systemImage: "play.rectangle")
                            .font(.system(size: 13))
                    }
                }
                .opacity(spotifyURL != nil || youtubeURL != nil ? 1 : 0)
                .allowsHitTesting(spotifyURL != nil || youtubeURL != nil)
                .padding(.top, 12)
            }

            Button("") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .frame(height: 28)
        }
        .frame(width: artworkDimension + 64)
        .background(Color.rrBackground)
    }

    private var searchQuery: String? {
        let query = [artist, track].compactMap { $0 }.joined(separator: " ")
        return query.isEmpty ? nil : query
    }

    private var spotifyURL: URL? {
        guard let q = searchQuery,
              let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://open.spotify.com/search/\(encoded)")
    }

    private var youtubeURL: URL? {
        guard let q = searchQuery,
              let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")
    }

    private var defaultSpotifyURL: URL? {
        URL(string: "https://open.spotify.com")
    }

    private var defaultYouTubeURL: URL? {
        URL(string: "https://www.youtube.com")
    }
}
