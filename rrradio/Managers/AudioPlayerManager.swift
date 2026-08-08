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
    #if os(macOS)
    private var appNapActivity: NSObjectProtocol?
    #endif
    private var lastArtworkFetchAt: Date?
    private var lastArtworkTitle: String?

    private let lastStationKey = "lastPlayingStationID"

    private override init() {
        super.init()
        observeAudioRouteChanges()
    }

    private func observeAudioRouteChanges() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }

    #if os(iOS)
    @objc nonisolated private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }
        // The previous output device (e.g. AirPods) went away — placed in the
        // case, unplugged, etc. Stop playback; never resume automatically.
        Task { @MainActor in self.stop() }
    }
    #endif

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
        activateAudioSessionIfNeeded()

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
        lastArtworkTitle = nil
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

    /// Explicit play command (e.g. from MPRemoteCommandCenter.playCommand).
    /// Only starts playback — never stops it.
    func resume() {
        guard !isPlaying, !isReconnecting, let station = currentStation else { return }
        play(station: station)
    }

    /// Explicit pause command (e.g. from MPRemoteCommandCenter.pauseCommand or
    /// an audio-route change such as AirPods being placed in their case).
    /// Only stops playback — never starts it.
    func pause() {
        guard isPlaying || isReconnecting else { return }
        stop()
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
                self.fetchArtwork(artist: self.currentArtist, track: self.currentTrack, rawTitle: t)
                NowPlayingManager.shared.updateSongTitle(t, station: s, artworkData: self.currentArtworkData)
            } else {
                self.artworkFetchTask?.cancel()
                self.lastArtworkTitle = nil
                self.currentArtworkData = nil
            }
        }
    }

    private func fetchArtwork(artist: String?, track: String?, rawTitle: String) {
        // Skip if the song hasn't changed since the last fetch.
        if rawTitle == lastArtworkTitle { return }

        let now = Date()
        if let lastArtworkFetchAt,
           now.timeIntervalSince(lastArtworkFetchAt) < 2 {
            return
        }
        lastArtworkFetchAt = now
        lastArtworkTitle = rawTitle

        // Search on the parsed "artist track" when available (no dash — it only
        // dilutes iTunes' matching); fall back to the raw title otherwise.
        let term: String
        if let artist, !artist.isEmpty, let track, !track.isEmpty {
            term = "\(artist) \(track)"
        } else {
            term = rawTitle
        }

        artworkFetchTask?.cancel()
        artworkFetchTask = Task {
            var components = URLComponents(string: "https://itunes.apple.com/search")
            components?.queryItems = [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "entity", value: "song"),
                URLQueryItem(name: "limit", value: "25")
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
                self.clearArtwork()
                return
            }

            // iTunes fuzzy-matches loosely, so verify each result against the
            // parsed artist/track and reject mismatches — better no artwork than
            // the wrong cover. Among the matches, the "- Single" collection carries
            // the single's own cover, preferred over an album/compilation version.
            let candidates = results.map { result -> ArtworkMatcher.Candidate in
                let collection = (result["collectionName"] as? String)?.lowercased() ?? ""
                return ArtworkMatcher.Candidate(
                    artist: result["artistName"] as? String ?? "",
                    track: result["trackName"] as? String ?? "",
                    isSingle: collection.hasSuffix("- single")
                )
            }
            guard let index = ArtworkMatcher.bestMatchIndex(
                    artist: artist, track: track, rawTitle: rawTitle, candidates: candidates),
                  let artworkUrl = results[index]["artworkUrl100"] as? String
            else {
                self.clearArtwork()
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

    /// Drop the song artwork so the station's own image is shown instead.
    private func clearArtwork() {
        currentArtworkData = nil
        if let s = currentStation, let t = currentSongTitle {
            NowPlayingManager.shared.updateSongTitle(t, station: s, artworkData: nil)
        }
    }

    // MARK: - Audio session / App Nap

    private func activateAudioSessionIfNeeded() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // Non-fatal: AVPlayer will still attempt playback
        }
        #endif
    }

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

// MARK: - Artwork matching

/// Verifies iTunes search results against the parsed artist/track of the playing
/// song so the wrong cover (a loose fuzzy hit) is rejected rather than displayed.
enum ArtworkMatcher {
    /// An iTunes result reduced to the fields used for matching.
    struct Candidate {
        let artist: String
        let track: String
        /// Whether the result lives in a "<Title> - Single" collection, whose
        /// artwork is the single's own cover.
        let isSingle: Bool
    }

    /// Minimum token-overlap score (0...1) an artist and a track must each reach
    /// when the metadata was split into artist + track.
    static let fieldThreshold = 0.5
    /// Minimum score when only a single unsplit string is available and it must
    /// be matched against the combined "artist track" of a candidate.
    static let combinedThreshold = 0.6

    /// Index of the best-matching candidate, or nil if none clear the threshold.
    static func bestMatchIndex(artist: String?, track: String?, rawTitle: String,
                               candidates: [Candidate]) -> Int? {
        let haveParsed = (artist?.isEmpty == false) && (track?.isEmpty == false)
        var best: (index: Int, score: Double)?

        for (i, c) in candidates.enumerated() {
            let score: Double
            if haveParsed {
                let artistScore = similarity(artist!, c.artist)
                let trackScore = similarity(track!, c.track)
                guard artistScore >= fieldThreshold, trackScore >= fieldThreshold else { continue }
                score = artistScore + trackScore
            } else {
                let combinedScore = similarity(rawTitle, "\(c.artist) \(c.track)")
                guard combinedScore >= combinedThreshold else { continue }
                score = combinedScore
            }
            // A single's cover breaks ties but never outranks a better match.
            let ranked = score + (c.isSingle ? 0.01 : 0)
            if best == nil || ranked > best!.score {
                best = (i, ranked)
            }
        }
        return best?.index
    }

    /// F1 of the token overlap between two strings (0 = disjoint, 1 = identical).
    static func similarity(_ a: String, _ b: String) -> Double {
        let ta = tokens(a), tb = tokens(b)
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        let intersection = Double(ta.intersection(tb).count)
        guard intersection > 0 else { return 0 }
        let precision = intersection / Double(tb.count)
        let recall = intersection / Double(ta.count)
        return 2 * precision * recall / (precision + recall)
    }

    private static let noise: Set<String> = ["feat", "ft", "featuring", "with"]

    /// Normalized, de-noised set of word tokens.
    static func tokens(_ s: String) -> Set<String> {
        Set(normalize(s).split(separator: " ").map(String.init)).subtracting(noise)
    }

    /// Lowercase, drop bracketed segments and diacritics, strip punctuation.
    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\[[^\\]]*\\]", with: " ", options: .regularExpression)
        t = t.folding(options: .diacriticInsensitive, locale: nil)
        t = t.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }
}
