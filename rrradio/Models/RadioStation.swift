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
    /// When true, the artwork is shown scaled-to-fit with a margin on a light
    /// backdrop instead of filling the tile edge-to-edge.
    var padImage: Bool

    init(id: UUID = UUID(), name: String, streamURL: String, imageURL: String = "", localImageData: Data? = nil, isDefault: Bool = false, padImage: Bool = false) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.imageURL = imageURL
        self.localImageData = localImageData
        self.isDefault = isDefault
        self.padImage = padImage
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, streamURL, imageURL, localImageData, isDefault, padImage
    }

    // Custom decoder keeps older persisted stations (without `padImage`) loadable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        streamURL = try container.decode(String.self, forKey: .streamURL)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        localImageData = try container.decodeIfPresent(Data.self, forKey: .localImageData)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        padImage = try container.decodeIfPresent(Bool.self, forKey: .padImage) ?? false
    }
}

