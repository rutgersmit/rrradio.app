import SwiftUI

struct StationImageView: View {
    let station: RadioStation

    /// Fraction of the tile's smaller side used as padding when a margin is enabled.
    private let marginFraction: CGFloat = 0.14

    var body: some View {
        if station.padImage {
            GeometryReader { geo in
                let inset = min(geo.size.width, geo.size.height) * marginFraction
                ZStack {
                    Color.rrImageMargin
                    artwork(contentMode: .fit)
                        .padding(inset)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        } else {
            artwork(contentMode: .fill)
        }
    }

    @ViewBuilder
    private func artwork(contentMode: ContentMode) -> some View {
        if let data = URLSecurityPolicy.boundedLocalImageData(station.localImageData),
           let img = Image(data: data) {
            img
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if let url = URLSecurityPolicy.safeImageURL(from: station.imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: contentMode)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.rrCard
            Image(systemName: "radio")
                .font(.system(size: 32))
                .foregroundColor(.rrSecondaryText)
        }
    }
}
