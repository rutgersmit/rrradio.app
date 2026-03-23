import SwiftUI

struct ImageCropView: View {
    let image: CGImage
    var onCrop: (Data) -> Void
    var onCancel: () -> Void

    private static let cropSize: CGFloat = 260

    @State private var offset: CGSize = .zero
    @State private var dragBase: CGSize = .zero

    private var aspect: CGFloat {
        let h = CGFloat(image.height)
        guard h > 0 else { return 1 }
        return CGFloat(image.width) / h
    }

    // Scale to fill the crop square
    private var scaledSize: CGSize {
        let s = Self.cropSize
        if aspect >= 1 {
            return CGSize(width: s * aspect, height: s)
        } else {
            return CGSize(width: s, height: s / aspect)
        }
    }

    // Maximum drag distance before image edge enters view
    private var maxOffset: CGSize {
        CGSize(
            width: max(0, (scaledSize.width - Self.cropSize) / 2),
            height: max(0, (scaledSize.height - Self.cropSize) / 2)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Crop Image")
                .font(.headline)
                .padding(.top, 4)

            Text("Drag to reposition")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ZStack {
                Color.black

                Image(image, scale: 1.0, label: Text(""))
                    .resizable()
                    .frame(width: scaledSize.width, height: scaledSize.height)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let mo = maxOffset
                                let newX = dragBase.width + value.translation.width
                                let newY = dragBase.height + value.translation.height
                                offset = CGSize(
                                    width: max(-mo.width, min(mo.width, newX)),
                                    height: max(-mo.height, min(mo.height, newY))
                                )
                            }
                            .onEnded { _ in dragBase = offset }
                    )
            }
            .frame(width: Self.cropSize, height: Self.cropSize)
            .clipped()
            .overlay(Rectangle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 12) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Button("Crop") {
                    if let data = renderCrop() {
                        onCrop(data)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 4)
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 340)
        #endif
    }

    // Render the visible crop area to PNG data at 2x resolution
    private func renderCrop() -> Data? {
        let s = Self.cropSize
        let scale: CGFloat = 2
        let px = Int(s * scale)

        guard let context = CGContext(
            data: nil, width: px, height: px,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // CGContext has origin at bottom-left with y going up.
        // SwiftUI: positive offset moves image down (y increases downward).
        // Mapping to CGContext:
        //   x = (center of image in crop) * scale
        //   y = flip the y offset
        let sw = scaledSize.width
        let sh = scaledSize.height
        let rx = ((s - sw) / 2 + offset.width) * scale
        let ry = ((s - sh) / 2 - offset.height) * scale
        let rect = CGRect(x: rx, y: ry, width: sw * scale, height: sh * scale)

        context.draw(image, in: rect)

        guard let result = context.makeImage() else { return nil }

        #if os(macOS)
        let rep = NSBitmapImageRep(cgImage: result)
        return rep.representation(using: .png, properties: [:])
        #else
        return UIImage(cgImage: result).pngData()
        #endif
    }
}
