import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct StationListView: View {
    @ObservedObject var store: StationStore
    @ObservedObject var player: AudioPlayerManager

    @State private var showAddSheet = false
    @State private var editingStation: RadioStation?
    @State private var deletingStation: RadioStation?
    @State private var showDeleteConfirm = false

    @State private var draggingID: UUID? = nil
    @State private var targetID: UUID? = nil

    // Responsive grid
    private let minCardWidth: CGFloat = 160
    private let spacing: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                let cols = max(2, Int(geo.size.width / (minCardWidth + spacing)))
                let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)

                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(store.stations) { station in
                        StationCardView(
                            station: station,
                            isPlaying: player.currentStation?.id == station.id && player.isPlaying,
                            isLoading: player.currentStation?.id == station.id && player.isLoading,
                            hasError: player.errorStation == station.id,
                            onTap: { handleTap(station) },
                            onEdit: { editingStation = station },
                            onDelete: {
                                deletingStation = station
                                showDeleteConfirm = true
                            }
                        )
                        .opacity(draggingID == station.id ? 0.4 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.rrAccent, lineWidth: 2.5)
                                .opacity(targetID == station.id && draggingID != station.id ? 1 : 0)
                        )
                        .onDrag {
                            draggingID = station.id
                            return NSItemProvider(object: station.id.uuidString as NSString)
                        }
                        .onDrop(of: [.plainText],
                                isTargeted: Binding(
                                    get: { targetID == station.id },
                                    set: { targetID = $0 ? station.id : nil }
                                )) { providers in
                            guard let dragged = draggingID,
                                  let from = store.stations.firstIndex(where: { $0.id == dragged }),
                                  let to = store.stations.firstIndex(where: { $0.id == station.id }),
                                  from != to else { return false }
                            store.move(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
                            draggingID = nil
                            targetID = nil
                            return true
                        }
                    }
                }
                .padding(spacing)
            }
        }
        .background(.clear)
        .background(stationShortcuts)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showAddSheet = true }) {
                    Label("Add Station", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditStationView(onSave: { store.add($0) })
        }
        .sheet(item: $editingStation) { station in
            AddEditStationView(existing: station, onSave: { store.update($0) })
        }
        .confirmationDialog(
            "Delete \"\(deletingStation?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let s = deletingStation {
                    if player.currentStation?.id == s.id { player.stop() }
                    store.delete(s)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var stationShortcuts: some View {
        #if os(macOS)
        ForEach(0..<min(9, store.stations.count), id: \.self) { index in
            Button("") {
                guard index < store.stations.count else { return }
                handleTap(store.stations[index])
            }
            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        #endif
    }

    private func handleTap(_ station: RadioStation) {
        if player.currentStation?.id == station.id {
            player.togglePlayPause()
        } else {
            player.play(station: station)
            sendNowPlayingNotification(station: station)
        }
    }

    private func sendNowPlayingNotification(station: RadioStation) {
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized else {
                // Request once
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Now Playing"
            content.body = station.name
            content.sound = nil

            let request = UNNotificationRequest(identifier: "nowPlaying", content: content, trigger: nil)
            try? await center.add(request)
        }
    }
}
