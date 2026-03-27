import SwiftUI

struct StationImageView: View {
    let station: RadioStation

    var body: some View {
        if let data = URLSecurityPolicy.boundedLocalImageData(station.localImageData),
           let img = Image(data: data) {
            img
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = URLSecurityPolicy.safeImageURL(from: station.imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
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
