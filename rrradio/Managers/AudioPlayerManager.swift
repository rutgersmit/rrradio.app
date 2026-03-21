import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject, AVPlayerItemMetadataOutputPushDelegate {
    static let shared = AudioPlayerManager()

    @Published var currentStation: RadioStation?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var isReconnecting: Bool = false
    @Published var errorStation: UUID?
    @Published var currentSongTitle: String? = nil
    @Published var currentArtist: String? = nil
    @Published var currentTrack: String? = nil
    @Published var currentArtworkData: Data? = nil
    @Published var volume: Float = 1.0 {
        didSet { player?.volume = volume }
    }
    @Published var isMuted: Bool = false {
        didSet { player?.isMuted = isMuted }
    }

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var itemObserver: NSKeyValueObservation?
    private var userExplicitlyStopped = false
    private var stallObserver: AnyCancellable?
    private var reconnectTask: Task<Void, Never>?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var artworkFetchTask: Task<Void, Never>?
    private var appNapActivity: NSObjectProtocol?
    private var lastArtworkFetchAt: Date?

    private let lastStationKey = "lastPlayingStationID"

    private override init() {
        super.init()
    }

    // MARK: - Playback

    func play(station: RadioStation) {
        stopInternal()
        errorStation = nil
        currentStation = station
        isLoading = true

        guard let url = URLSecurityPolicy.safeStreamURL(from: station.streamURL) else {
            isLoading = false
            errorStation = station.id
            return
        }

        beginAppNapProtectionIfNeeded()

        let item = AVPlayerItem(url: url)
        playerItem = item
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.isMuted = isMuted

        userExplicitlyStopped = false

        stallObserver = NotificationCenter.default
            .publisher(for: AVPlayerItem.playbackStalledNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in Task { @MainActor in self?.handleStall() } }

        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: .main)
        item.add(output)
        metadataOutput = output

        itemObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.isPlaying = true
                    self?.player?.play()
                case .failed:
                    self?.isLoading = false
                    self?.isPlaying = false
                    self?.handleStall()
                default:
                    break
                }
            }
        }

        player?.play()

        UserDefaults.standard.set(station.id.uuidString, forKey: lastStationKey)
        NowPlayingManager.shared.update(station: station, isPlaying: true)
    }

    func stop() {
        userExplicitlyStopped = true
        stopInternal()
    }

    private func stopInternal() {
        reconnectTask?.cancel(); reconnectTask = nil
        artworkFetchTask?.cancel(); artworkFetchTask = nil
        stallObserver = nil
        metadataOutput = nil
        player?.pause(); player = nil
        playerItem = nil; itemObserver = nil
        isPlaying = false; isLoading = false; isReconnecting = false
        currentSongTitle = nil
        currentArtist = nil
        currentTrack = nil
        currentArtworkData = nil
        endAppNapProtectionIfNeeded()
        if let s = currentStation { NowPlayingManager.shared.update(station: s, isPlaying: false) }
    }

    private func handleStall() {
        guard !userExplicitlyStopped, let station = currentStation else { return }
        isPlaying = false; isLoading = false; isReconnecting = true
        errorStation = station.id
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !self.userExplicitlyStopped else { return }
                self.isReconnecting = false
                self.play(station: station)
            }
        }
    }

    func togglePlayPause() {
        if isPlaying || isReconnecting {
            stop()
        } else if let station = currentStation {
            play(station: station)
        }
    }

    func lastPlayedStationID() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: lastStationKey) else { return nil }
        return UUID(uuidString: str)
    }

    // MARK: - ICY / Timed Metadata

    nonisolated func metadataOutput(_ output: AVPlayerItemMetadataOutput,
                                    didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                                    from track: AVPlayerItemTrack?) {
        let items = groups.flatMap(\.items)
        Task { @MainActor in
            var title: String? = nil
            for item in items {
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    let sanitized = URLSecurityPolicy.sanitizeMetadata(value)
                    if !sanitized.isEmpty {
                        title = sanitized
                        break
                    }
                }
            }
            self.currentSongTitle = title
            // Parse "Artist - Title"
            if let t = title {
                let parts = t.components(separatedBy: " - ")
                if parts.count >= 2 {
                    self.currentArtist = parts[0].trimmingCharacters(in: .whitespaces)
                    self.currentTrack = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                } else {
                    self.currentArtist = nil
                    self.currentTrack = t
                }
            } else {
                self.currentArtist = nil
                self.currentTrack = nil
            }

            if let t = title, let s = self.currentStation {
                self.fetchArtwork(for: t)
                NowPlayingManager.shared.updateSongTitle(t, station: s, artworkData: self.currentArtworkData)
            } else {
                self.artworkFetchTask?.cancel()
                self.currentArtworkData = nil
            }
        }
    }

    private func fetchArtwork(for title: String) {
        let now = Date()
        if let lastArtworkFetchAt,
           now.timeIntervalSince(lastArtworkFetchAt) < 2 {
            return
        }
        lastArtworkFetchAt = now

        artworkFetchTask?.cancel()
        artworkFetchTask = Task {
            var components = URLComponents(string: "https://itunes.apple.com/search")
            components?.queryItems = [
                URLQueryItem(name: "term", value: title),
                URLQueryItem(name: "entity", value: "song"),
                URLQueryItem(name: "limit", value: "5")
            ]

            guard let url = components?.url,
                  let data = await URLSecurityPolicy.fetchData(
                    from: url,
                    timeoutInterval: 8,
                    maxBytes: URLSecurityPolicy.maxCatalogBytes,
                    acceptedMimePrefixes: nil
                  ),
                  !Task.isCancelled
            else { return }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  !results.isEmpty
            else {
                self.currentArtworkData = nil
                if let s = self.currentStation, let t = self.currentSongTitle {
                    NowPlayingManager.shared.updateSongTitle(t, station: s, artworkData: nil)
                }
                return
            }

            let preferred = results.first { ($0["collectionType"] as? String) == "Single" } ?? results[0]
            guard let artworkUrl = preferred["artworkUrl100"] as? String else {
                self.currentArtworkData = nil
                if let s = self.currentStation, let t = self.currentSongTitle {
                    NowPlayingManager.shared.updateSongTitle(t, station: s, artworkData: nil)
                }
                return
            }

            let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "1200x1200")
            guard let imageUrl = URLSecurityPolicy.safeImageURL(from: highResUrl),
                let imageData = await URLSecurityPolicy.fetchData(
                  from: imageUrl,
                  timeoutInterval: 8,
                  maxBytes: URLSecurityPolicy.maxImageBytes,
                  acceptedMimePrefixes: ["image/"]
                ),
                  !Task.isCancelled
            else { return }

            self.currentArtworkData = imageData
            if let s = self.currentStation, let t = self.currentSongTitle {
                NowPlayingManager.shared.updateSongTitle(t, station: s, artworkData: imageData)
            }
        }
    }

    // MARK: - App Nap prevention

    private func beginAppNapProtectionIfNeeded() {
        #if os(macOS)
        guard appNapActivity == nil else { return }
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Radio streaming"
        )
        #endif
    }

    private func endAppNapProtectionIfNeeded() {
        #if os(macOS)
        if let appNapActivity {
            ProcessInfo.processInfo.endActivity(appNapActivity)
            self.appNapActivity = nil
        }
        #endif
    }
}
