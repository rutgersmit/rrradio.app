import Foundation

struct RadioStation: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var streamURL: String
    var imageURL: String
    var localImageData: Data?
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, streamURL: String, imageURL: String = "", localImageData: Data? = nil, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.imageURL = imageURL
        self.localImageData = localImageData
        self.isDefault = isDefault
    }
}

extension RadioStation {
    static let defaults: [RadioStation] = [
        RadioStation(name: "NPO Radio 2",    streamURL: "https://icecast.omroep.nl/radio2-bb-mp3",                                              isDefault: true),
        RadioStation(name: "KINK",           streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/KINK.mp3",           isDefault: true),
        RadioStation(name: "NPO 3FM",        streamURL: "https://icecast.omroep.nl/3fm-bb-mp3",                                                isDefault: true),
        RadioStation(name: "Radio 538",      streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO538.mp3",       isDefault: true),
        RadioStation(name: "Sky Radio",      streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/SKYRADIO.mp3",       isDefault: true),
        RadioStation(name: "NPO Radio 1",    streamURL: "https://icecast.omroep.nl/radio1-bb-mp3",                                             isDefault: true),
        RadioStation(name: "BNR Nieuwsradio",streamURL: "https://icecast-bnr-cdp.triple-it.nl/BNR_MP3_128_04",                                 isDefault: true),
        RadioStation(name: "Q-music",        streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/QMUSIC.mp3",         isDefault: true),
    ]
}
