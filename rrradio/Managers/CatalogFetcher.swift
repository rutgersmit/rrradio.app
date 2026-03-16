import Foundation

enum CatalogSource {
    case remote, bundled
}

enum CatalogFetcher {
    static func loadCatalog() async -> (StationCatalog, CatalogSource) {
        if let catalog = await fetchRemoteCatalog() {
            return (catalog, .remote)
        }
        return (loadBundledCatalog(), .bundled)
    }

    static func fetchImageData(directory: String, filename: String) async -> Data? {
        guard let url = RemoteConfig.imageURL(directory: directory, filename: filename) else { return nil }
        return await URLSecurityPolicy.fetchData(
            from: url,
            timeoutInterval: 8,
            maxBytes: URLSecurityPolicy.maxImageBytes,
            acceptedMimePrefixes: ["image/"]
        )
    }

    private static func fetchRemoteCatalog() async -> StationCatalog? {
        guard let url = RemoteConfig.catalogURL,
              URLSecurityPolicy.safeCatalogURL(url),
              let data = await URLSecurityPolicy.fetchData(
                from: url,
                timeoutInterval: 8,
                maxBytes: URLSecurityPolicy.maxCatalogBytes,
                acceptedMimePrefixes: ["application/json", "text/plain"]
              ),
              let catalog = try? JSONDecoder().decode(StationCatalog.self, from: data)
        else { return nil }

        return validate(catalog: catalog)
    }

    private static func loadBundledCatalog() -> StationCatalog {
        StationCatalog(version: 0, countries: [])
    }

    private static func validate(catalog: StationCatalog) -> StationCatalog {
        let countries = catalog.countries.compactMap { country -> CountryEntry? in
            guard !country.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !country.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  URLSecurityPolicy.isSafeCatalogPathComponent(country.directory)
            else { return nil }

            let validatedStations: [StationEntry] = country.stations.compactMap { station -> StationEntry? in
                let trimmedName = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedStream = station.streamURL.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmedName.isEmpty,
                      trimmedName.count <= URLSecurityPolicy.maxStationNameLength,
                      URLSecurityPolicy.safeStreamURL(from: trimmedStream) != nil,
                      URLSecurityPolicy.isSafeCatalogPathComponent(station.image)
                else { return nil }

                return StationEntry(
                    name: trimmedName,
                    streamURL: trimmedStream,
                    image: station.image
                )
            }

            return CountryEntry(
                code: country.code,
                name: country.name,
                directory: country.directory,
                stations: validatedStations
            )
        }

        return StationCatalog(version: catalog.version, countries: countries)
    }
}
