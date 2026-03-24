import Foundation
import SwiftUI

@MainActor
class StationStore: ObservableObject {
    @Published var stations: [RadioStation] = []
    @Published var needsDefaultsPrompt = false

    private let saveKey = "savedStations"
    private let hasLaunchedKey = "hasLaunchedBefore"

    init() {
        load()
    }

    func importFromCatalog(_ countries: [CountryEntry]) async {
        let items: [(index: Int, directory: String, entry: StationEntry)] = countries.enumerated().flatMap { (ci, country) in
            country.stations.enumerated().map { (si, entry) in
                (index: ci * 10000 + si, directory: country.directory, entry: entry)
            }
        }

        var indexed: [(Int, RadioStation)] = []
        await withTaskGroup(of: (Int, RadioStation)?.self) { group in
            for item in items {
                group.addTask {
                    guard let safeStreamURL = URLSecurityPolicy.safeStreamURL(from: item.entry.streamURL)?.absoluteString else {
                        return nil
                    }

                    let imageData = await CatalogFetcher.fetchImageData(directory: item.directory, filename: item.entry.image)

                    let station = RadioStation(
                        name: item.entry.name,
                        streamURL: safeStreamURL,
                        localImageData: URLSecurityPolicy.boundedLocalImageData(imageData),
                        isDefault: true
                    )
                    return (item.index, station)
                }
            }
            for await pair in group {
                if let pair {
                    indexed.append(pair)
                }
            }
        }

        stations = indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        needsDefaultsPrompt = false
        save()
    }

    func add(_ station: RadioStation) {
        guard let normalized = normalized(station: station) else { return }
        stations.append(normalized)
        save()
    }

    func update(_ station: RadioStation) {
        guard let normalized = normalized(station: station) else { return }
        guard let idx = stations.firstIndex(where: { $0.id == station.id }) else { return }
        stations[idx] = normalized
        save()
    }

    func delete(_ station: RadioStation) {
        stations.removeAll { $0.id == station.id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        stations.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Persistence

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            stations = decoded.compactMap(normalized(station:))
        }
        if stations.isEmpty {
            needsDefaultsPrompt = true
        }
    }

    private func save() {
        let safeStations = stations.compactMap(normalized(station:))
        if let data = try? JSONEncoder().encode(safeStations) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func normalized(station: RadioStation) -> RadioStation? {
        guard let streamURL = URLSecurityPolicy.safeStreamURL(from: station.streamURL)?.absoluteString else { return nil }

        let trimmedName = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              trimmedName.count <= URLSecurityPolicy.maxStationNameLength
        else { return nil }

        let imageURL: String
        if station.imageURL.isEmpty {
            imageURL = ""
        } else if let safeImageURL = URLSecurityPolicy.safeImageURL(from: station.imageURL)?.absoluteString {
            imageURL = safeImageURL
        } else {
            imageURL = ""
        }

        return RadioStation(
            id: station.id,
            name: trimmedName,
            streamURL: streamURL,
            imageURL: imageURL,
            localImageData: URLSecurityPolicy.boundedLocalImageData(station.localImageData),
            isDefault: station.isDefault
        )
    }
}
