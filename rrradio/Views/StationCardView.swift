import SwiftUI

struct StationCardView: View {
    let station: RadioStation
    let isPlaying: Bool
    let isLoading: Bool
    let hasError: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accessibilityLabel: String {
        var parts: [String] = []
        if isPlaying { parts.append("Now playing") }
        else if isLoading { parts.append("Connecting") }
        parts.append(station.name)
        if hasError { parts.append("stream error") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Artwork
            StationImageView(station: station)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Station name
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if hasError {
                    Label("Stream error", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Color(white: 0, opacity: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(6)

            // Play indicator overlay
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
            } else if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            // Hover controls
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(station.name)")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .padding(5)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(station.name)")
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isPlaying ? Color.rrAccent : Color.clear,
                    lineWidth: 2.5
                )
        )
        .shadow(
            color: isPlaying ? Color.rrGlow : Color.black.opacity(0.2),
            radius: isPlaying ? 12 : 4,
            x: 0, y: 2
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onTap)
        #if os(macOS)
        .cursor(.pointingHand)
        #endif
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Edit") { onEdit() }
        .accessibilityAction(named: "Delete") { onDelete() }
        .accessibilityAction(.default) { onTap() }
    }

}

// MARK: - Cursor helper (macOS only)

#if os(macOS)
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
#endif
