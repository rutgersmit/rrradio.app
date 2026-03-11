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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Artwork
            StationImageView(station: station)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Station name
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if hasError {
                    Label("Stream error", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
            }
            .padding(10)

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

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .padding(5)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
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
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onTap)
        .cursor(.pointingHand)
    }

}

// MARK: - Cursor helper

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
