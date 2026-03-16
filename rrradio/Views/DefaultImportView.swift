import SwiftUI

struct StationCatalog: Decodable {
    let version: Int
    let countries: [CountryEntry]
}

struct CountryEntry: Decodable, Identifiable {
    let code: String
    let name: String
    let directory: String
    let stations: [StationEntry]
    var id: String { code }
}

struct StationEntry: Decodable {
    let name: String
    let streamURL: String
    let image: String
}

struct DefaultImportView: View {
    @ObservedObject var store: StationStore

    @State private var countries: [CountryEntry] = []
    @State private var selectedCodes: Set<String> = []
    @State private var isLoading = true
    @State private var catalogSource: CatalogSource = .bundled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Import default stations")
                .font(.title2).bold()
                .padding()

            Divider()

            Text("Select the countries whose stations you'd like to import:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

            ZStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    List(countries) { country in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedCodes.contains(country.code) },
                                set: { if $0 { selectedCodes.insert(country.code) } else { selectedCodes.remove(country.code) } }
                            )) {
                                Text(country.name)
                            }
                            .disabled(country.stations.isEmpty)

                            Spacer()

                            if country.stations.isEmpty {
                                Text("Coming soon")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(country.stations.count) stations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(minHeight: 160)
                }
            }

            if !isLoading && catalogSource == .bundled {
                Text("Using bundled station list (offline)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            Divider()

            HStack {
                Button("Skip") {
                    store.needsDefaultsPrompt = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .focusable(false)

                Spacer()

                Button("Import selected") {
                    let selected = countries.filter { selectedCodes.contains($0.code) }
                    Task { await store.importFromCatalog(selected) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCodes.isEmpty || isLoading)
            }
            .padding()
        }
        .frame(width: 380)
        .onAppear {
            Task {
                let (catalog, source) = await CatalogFetcher.loadCatalog()
                var seen = Set<String>()
                countries = catalog.countries.filter { seen.insert($0.code).inserted }
                selectedCodes = Set(countries.filter { !$0.stations.isEmpty }.map { $0.code })
                catalogSource = source
                isLoading = false
            }
        }
    }
}
