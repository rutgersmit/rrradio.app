import Foundation

enum RemoteConfig {
    static let githubBaseURL = "https://raw.githubusercontent.com/rutgersmit/rrradio.app/main/assets/default-stations"

    static var catalogURL: URL? {
        baseURL?.appendingPathComponent("stations.json")
    }

    static func imageURL(directory: String, filename: String) -> URL? {
        guard URLSecurityPolicy.isSafeCatalogPathComponent(directory),
              URLSecurityPolicy.isSafeCatalogPathComponent(filename),
              let baseURL
        else { return nil }

        return baseURL
            .appendingPathComponent(directory)
            .appendingPathComponent(filename)
    }

    private static var baseURL: URL? {
        URL(string: githubBaseURL)
    }
}

enum URLSecurityPolicy {
    static let maxImageBytes = 10_000_000
    static let maxCatalogBytes = 1_000_000
    static let maxLocalImageBytes = 10_000_000
    static let maxMetadataLength = 512
    static let maxStationNameLength = 120
    static let trustedRemoteConfigHost = "raw.githubusercontent.com"

    static func safeStreamURL(from raw: String) -> URL? {
        safeHTTPSURL(from: raw)
    }

    static func safeImageURL(from raw: String) -> URL? {
        safeHTTPSURL(from: raw)
    }

    static func safeCatalogURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == trustedRemoteConfigHost
        else { return false }
        return true
    }

    static func sanitizeMetadata(_ raw: String) -> String {
        let filteredScalars = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let filtered = String(String.UnicodeScalarView(filteredScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(filtered.prefix(maxMetadataLength))
    }

    static func boundedLocalImageData(_ data: Data?) -> Data? {
        guard let data, data.count <= maxLocalImageBytes else { return nil }
        return data
    }

    static func isSafeCatalogPathComponent(_ value: String) -> Bool {
        guard !value.isEmpty,
              !value.contains(".."),
              !value.contains("/"),
              !value.contains("\\")
        else { return false }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    static func fetchData(
        from url: URL,
        timeoutInterval: TimeInterval = 8,
        maxBytes: Int,
        acceptedMimePrefixes: [String]? = nil
    ) async -> Data? {
        guard url.scheme?.lowercased() == "https" else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { return nil }

        if let contentLength = http.value(forHTTPHeaderField: "Content-Length"),
           let bytes = Int(contentLength),
           bytes > maxBytes {
            return nil
        }

        guard data.count <= maxBytes else { return nil }

        if let acceptedMimePrefixes {
            guard let mimeType = http.mimeType?.lowercased(),
                  acceptedMimePrefixes.contains(where: { mimeType.hasPrefix($0) })
            else { return nil }
        }

        return data
    }

    private static func safeHTTPSURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              let url = components.url
        else { return nil }

        return url
    }
}
