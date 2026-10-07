import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var player: AudioPlayerManager
    var onArtworkTap: (() -> Void)? = nil

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
                // Leading slot: artwork or station logo
                if let artworkData = player.currentArtworkData {
                    #if os(macOS)
                    // Space reserved for the floating thumbnail overlay in ContentView
                    Color.clear.frame(width: 100, height: 42)
                    #else
                    // Show tappable artwork thumbnail in the bar itself
                    Button(action: { onArtworkTap?() }) {
                        if let img = Image(data: artworkData) {
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View artwork")
                    #endif
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
                .focusable(false)
                .disabled(player.currentStation == nil)
                .accessibilityLabel(player.isLoading ? "Connecting" : player.isReconnecting ? "Reconnecting" : player.isPlaying ? "Stop" : "Play")

                // Volume (macOS only — iOS users use hardware volume buttons)
                #if os(macOS)
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
                #endif
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

    @State private var displayedImage: Image?
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
        self._displayedImage = State(initialValue: artworkData.flatMap { Image(data: $0) })
    }

    private var artworkDimension: CGFloat {
        #if os(iOS)
        let fromWidth = availableSize.width - 48
        let fromHeight = availableSize.height * 0.55
        #else
        let fromWidth = availableSize.width * 0.75
        let fromHeight = availableSize.height * 0.60
        #endif
        return max(min(min(fromWidth, fromHeight), 800), 0).rounded()
    }

    #if os(iOS)
    private let titleSize: CGFloat = 22
    private let artistSize: CGFloat = 17
    private let stationSize: CGFloat = 13
    private let linkSize: CGFloat = 15
    #else
    private let titleSize: CGFloat = 16
    private let artistSize: CGFloat = 13
    private let stationSize: CGFloat = 11
    private let linkSize: CGFloat = 13
    #endif

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            Spacer(minLength: 24)
            #endif

            artwork

            VStack(spacing: 4) {
                Text(track ?? "\u{00A0}")
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundColor(.rrPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(artist ?? songTitle ?? "\u{00A0}")
                    .font(.system(size: artistSize))
                    .foregroundColor(.rrSecondaryText)
                    .lineLimit(1)

                Text(stationName ?? "\u{00A0}")
                    .font(.system(size: stationSize, weight: .medium))
                    .foregroundColor(.rrSecondaryText.opacity(0.7))
                    .textCase(.uppercase)
                    .padding(.top, 2)
            }
            .padding(.top, 24)
            .padding(.horizontal, 32)

            if let spotifyDestination = spotifyURL ?? defaultSpotifyURL,
               let youtubeDestination = youtubeURL ?? defaultYouTubeURL {
                HStack(spacing: 12) {
                    Link(destination: spotifyDestination) {
                        Label("Spotify", systemImage: "music.note")
                            .font(.system(size: linkSize, weight: .medium))
                            .modifier(LinkPillStyle())
                    }
                    Link(destination: youtubeDestination) {
                        Label("YouTube", systemImage: "play.rectangle")
                            .font(.system(size: linkSize, weight: .medium))
                            .modifier(LinkPillStyle())
                    }
                }
                .opacity(spotifyURL != nil || youtubeURL != nil ? 1 : 0)
                .allowsHitTesting(spotifyURL != nil || youtubeURL != nil)
                .padding(.top, 20)
            }

            #if os(iOS)
            Spacer(minLength: 24)
            Spacer(minLength: 0)
            #else
            Color.clear.frame(height: 28)
            #endif
        }
        .background {
            Button("") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        }
        #if os(macOS)
        .frame(width: artworkDimension + 64)
        .background(Color.rrBackground)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { backdrop }
        .presentationDragIndicator(.visible)
        #endif
    }

    private var artwork: some View {
        ZStack {
            if let img = displayedImage {
                img
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .opacity(imageOpacity)
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .onTapGesture { onDismiss() }
        .onAppear {
            if displayedImage == nil {
                displayedImage = URLSecurityPolicy.boundedLocalImageData(artworkData).flatMap { Image(data: $0) }
            }
        }
        .onChange(of: artworkData) { newData in
            if reduceMotion {
                displayedImage = URLSecurityPolicy.boundedLocalImageData(newData).flatMap { Image(data: $0) }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { imageOpacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    displayedImage = URLSecurityPolicy.boundedLocalImageData(newData).flatMap { Image(data: $0) }
                    withAnimation(.easeIn(duration: 0.25)) { imageOpacity = 1 }
                }
            }
        }
    }

    #if os(iOS)
    /// Full-bleed backdrop: the app background tinted by a heavily blurred
    /// copy of the artwork, so the sheet has no bare white area below the
    /// content.
    private var backdrop: some View {
        ZStack {
            Color.rrBackground
            if let img = displayedImage {
                Color.clear
                    .overlay {
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
                    }
                    .clipped()
                    .opacity(0.35 * imageOpacity)
            }
        }
        .ignoresSafeArea()
    }
    #endif

    private var searchQuery: String? {
        let query = [artist, track].compactMap { $0 }.joined(separator: " ")
        return query.isEmpty ? nil : query
    }

    // `.urlQueryAllowed` leaves reserved sub-delimiters like `&`, `+`, `=`, `/`,
    // `?` and `#` untouched, so an artist such as "Placebo & David Bowie" would
    // break the query string (the `&` starts a new parameter). Encode those too.
    private static let searchQueryAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?/#")
        return allowed
    }()

    private var encodedSearchQuery: String? {
        searchQuery?.addingPercentEncoding(withAllowedCharacters: Self.searchQueryAllowed)
    }

    private var spotifyURL: URL? {
        guard let encoded = encodedSearchQuery else { return nil }
        return URL(string: "https://open.spotify.com/search/\(encoded)")
    }

    private var youtubeURL: URL? {
        guard let encoded = encodedSearchQuery else { return nil }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")
    }

    private var defaultSpotifyURL: URL? {
        URL(string: "https://open.spotify.com")
    }

    private var defaultYouTubeURL: URL? {
        URL(string: "https://www.youtube.com")
    }
}

private struct LinkPillStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.rrCard.opacity(0.7)))
    }
}
