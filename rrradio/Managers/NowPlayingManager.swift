import Foundation
import MediaPlayer
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
class NowPlayingManager {
    static let shared = NowPlayingManager()

    private var onPlayPause: (() -> Void)?
    private var onNext: (() -> Void)?
    private var onPrevious: (() -> Void)?

    private init() {
        setupRemoteCommands()
    }

    func configure(
        onPlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) {
        self.onPlayPause = onPlayPause
        self.onNext = onNext
        self.onPrevious = onPrevious
    }

    func update(station: RadioStation, isPlaying: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: station.name,
            MPMediaItemPropertyArtist: "rrradio",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPMediaItemPropertyPlaybackDuration: 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Use local image data if available, otherwise download from URL
        #if os(macOS)
        if let data = URLSecurityPolicy.boundedLocalImageData(station.localImageData),
           let image = NSImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        } else if let url = URLSecurityPolicy.safeImageURL(from: station.imageURL) {
            Task {
                if let data = await URLSecurityPolicy.fetchData(
                    from: url,
                    timeoutInterval: 8,
                    maxBytes: URLSecurityPolicy.maxImageBytes,
                    acceptedMimePrefixes: ["image/"]
                ),
                   let image = NSImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
        #elseif os(iOS)
        if let data = URLSecurityPolicy.boundedLocalImageData(station.localImageData),
           let image = UIImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        } else if let url = URLSecurityPolicy.safeImageURL(from: station.imageURL) {
            Task {
                if let data = await URLSecurityPolicy.fetchData(
                    from: url,
                    timeoutInterval: 8,
                    maxBytes: URLSecurityPolicy.maxImageBytes,
                    acceptedMimePrefixes: ["image/"]
                ),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
        #endif
    }

    func updateSongTitle(_ title: String, station: RadioStation, artworkData: Data? = nil) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = station.name
        #if os(macOS)
        if let data = URLSecurityPolicy.boundedLocalImageData(artworkData),
           let image = NSImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        #elseif os(iOS)
        if let data = URLSecurityPolicy.boundedLocalImageData(artworkData),
           let image = UIImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        #endif
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.onPlayPause?()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onPlayPause?()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onPlayPause?()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNext?()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPrevious?()
            return .success
        }

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
    }
}
