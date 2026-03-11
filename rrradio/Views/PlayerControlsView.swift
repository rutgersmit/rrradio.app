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

                // Volume
                HStack(spacing: 4) {
                    Button(action: { player.isMuted.toggle() }) {
                        Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .font(.system(size: 10))
                            .foregroundColor(player.isMuted ? .rrAccent : .rrSecondaryText)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help(player.isMuted ? "Dempen opheffen" : "Dempen")

                    Slider(value: $player.volume, in: 0...1)
                        .frame(width: 80)
                        .tint(.rrAccent)
                        .focusable(false)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.rrSecondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.rrPlayer)
    }
}

struct ArtworkModalView: View {
    let nsImage: NSImage
    let songTitle: String?
    let artist: String?
    let track: String?
    let stationName: String?
    let availableSize: CGSize
    let onDismiss: () -> Void

    private var artworkDimension: CGFloat {
        let fromWidth = availableSize.width * 0.75
        let fromHeight = availableSize.height * 0.60
        return min(min(fromWidth, fromHeight), 800).rounded()
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: artworkDimension, height: artworkDimension)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, 32)
                .padding(.horizontal, 32)
                .onTapGesture { onDismiss() }

            VStack(spacing: 4) {
                if let track = track {
                    Text(track)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.rrPrimaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                if let artist = artist {
                    Text(artist)
                        .font(.system(size: 13))
                        .foregroundColor(.rrSecondaryText)
                        .lineLimit(1)
                } else if let song = songTitle, track == nil {
                    Text(song)
                        .font(.system(size: 13))
                        .foregroundColor(.rrSecondaryText)
                        .lineLimit(1)
                }
                if let station = stationName {
                    Text(station)
                        .font(.system(size: 11))
                        .foregroundColor(.rrSecondaryText.opacity(0.6))
                        .padding(.top, 2)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 32)

            Button("") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .frame(height: 28)
        }
        .frame(width: artworkDimension + 64)
        .background(Color.rrBackground)
    }
}
