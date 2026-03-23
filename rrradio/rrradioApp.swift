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
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.menu)
        #endif
    }
}

// MARK: - Menu Bar Icon

#if os(macOS)
struct MenuBarIconView: View {
    @ObservedObject var player = AudioPlayerManager.shared

    var body: some View {
        if let data = URLSecurityPolicy.boundedLocalImageData(player.currentArtworkData),
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
        VStack(alignment: .leading, spacing: 4) {
            Text(player.currentStation?.name ?? "No station")
                .font(.headline)
                .padding(.bottom, 2)

            Text(player.isPlaying ? "Playing" : (player.isReconnecting ? "Reconnecting…" : "Stopped"))
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Button(player.isPlaying || player.isReconnecting ? "Stop" : "Play") {
                player.togglePlayPause()
            }
            .disabled(player.currentStation == nil)

            Divider()

            Button("Quit rrradio") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 200)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep running when window is closed
    }
}
#endif
