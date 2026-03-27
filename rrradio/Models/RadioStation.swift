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

