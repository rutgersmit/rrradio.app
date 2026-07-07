import SwiftUI

struct StationImageView: View {
    let station: RadioStation

    /// Padding, in points, applied around the artwork when a margin is enabled.
    var margin: CGFloat = 40

    var body: some View {
        if station.padImage {
            ZStack {
                Color.rrImageMargin
                artwork(contentMode: .fit)
                    .padding(margin)
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
