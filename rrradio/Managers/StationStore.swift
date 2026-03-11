import Foundation
import SwiftUI

@MainActor
class StationStore: ObservableObject {
    @Published var stations: [RadioStation] = []

    private let saveKey = "savedStations"
    private let hasLaunchedKey = "hasLaunchedBefore"

    init() {
        load()
    }

    func add(_ station: RadioStation) {
        stations.append(station)
        save()
    }

    func update(_ station: RadioStation) {
        guard let idx = stations.firstIndex(where: { $0.id == station.id }) else { return }
        stations[idx] = station
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
            stations = decoded
            return
        }
        // First launch — seed defaults
        stations = RadioStation.defaults
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stations) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
}
