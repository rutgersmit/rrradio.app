import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
    static var defaults: [RadioStation] {
        [
            RadioStation(name: "NPO Radio 1", streamURL: "https://icecast.omroep.nl/radio1-bb-mp3",                                             localImageData: assetData("radio1"),   isDefault: true),
            RadioStation(name: "NPO Radio 2", streamURL: "https://icecast.omroep.nl/radio2-bb-mp3",                                             localImageData: assetData("radio2"),   isDefault: true),
            RadioStation(name: "NPO 3FM",     streamURL: "https://icecast.omroep.nl/3fm-bb-mp3",                                                localImageData: assetData("3fm"),      isDefault: true),
            RadioStation(name: "KINK",        streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/KINK.mp3",           localImageData: assetData("kink"),     isDefault: true),
            RadioStation(name: "Veronica",    streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/VERONICA.mp3",       localImageData: assetData("veronica"), isDefault: true),
        ]
    }

    static func assetData(_ name: String) -> Data? {
        #if os(macOS)
        guard let image = NSImage(named: name),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        return UIImage(named: name)?.pngData()
        #endif
    }
}
