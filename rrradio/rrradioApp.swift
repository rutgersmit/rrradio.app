import SwiftUI
import UserNotifications

@main
struct rrradioApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

// MARK: - Menu Bar Icon

#if os(macOS)
struct MenuBarIconView: View {
    @ObservedObject var player = AudioPlayerManager.shared

    var body: some View {
        if let data = player.currentArtworkData,
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage.resized(to: NSSize(width: 18, height: 18)))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Image(systemName: "radio")
        }
    }
}

private extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage {
        let result = NSImage(size: targetSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: targetSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy, fraction: 1)
        result.unlockFocus()
        return result
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var player = AudioPlayerManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let data = player.currentArtworkData,
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage.resized(to: NSSize(width: 204, height: 204)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 2) {
                    if let track = player.currentTrack {
                        Text(track)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(2)
                    }
                    if let artist = player.currentArtist {
                        Text(artist)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Text(player.currentStation?.name ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.bottom, 8)

                Divider().padding(.bottom, 4)
            } else {
                Text(player.currentStation?.name ?? "No station")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.bottom, 2)

                Text(player.isPlaying ? "Playing" : (player.isReconnecting ? "Reconnecting…" : "Stopped"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                Divider().padding(.bottom, 4)
            }

            MenuBarButton(title: player.isPlaying || player.isReconnecting ? "Stop" : "Play") {
                player.togglePlayPause()
            }
            .disabled(player.currentStation == nil)

            Divider().padding(.vertical, 4)

            MenuBarButton(title: "Quit rrradio") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
        .frame(width: 224)
        .background(MenuMaterial())
    }
}

struct MenuBarButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isHovered ? Color.accentColor : Color.clear)
                .foregroundColor(isHovered ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MenuMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep running when window is closed
    }
}
#endif
