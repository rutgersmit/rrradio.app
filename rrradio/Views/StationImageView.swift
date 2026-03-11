import SwiftUI

struct StationImageView: View {
    let station: RadioStation

    var body: some View {
        if let data = station.localImageData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            AsyncImage(url: URL(string: station.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholder
                }
            }
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
