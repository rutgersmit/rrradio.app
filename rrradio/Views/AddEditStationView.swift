import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

struct AddEditStationView: View {
    @Environment(\.dismiss) private var dismiss

    var existing: RadioStation?
    var onSave: (RadioStation) -> Void

    @State private var name: String = ""
    @State private var streamURL: String = ""
    @State private var localImageData: Data? = nil

    @State private var pickedImage: CGImage? = nil
    @State private var showCrop = false

    #if os(iOS)
    @State private var photosPickerItem: PhotosPickerItem? = nil
    #endif

    #if os(macOS)
    private func pickImage() {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.image]
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.message = "Choose an image for the station"
            if panel.runModal() == .OK,
               let url = panel.url,
               let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = values.fileSize,
               fileSize <= URLSecurityPolicy.maxLocalImageBytes,
               let data = try? Data(contentsOf: url),
               data.count <= URLSecurityPolicy.maxLocalImageBytes,
               let nsImage = NSImage(data: data),
               let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                pickedImage = cgImage
                showCrop = true
            }
        }
    #endif

    enum Field { case name }
    @FocusState private var focusedField: Field?

    var isEditing: Bool { existing != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedStreamURL: String? {
        URLSecurityPolicy.safeStreamURL(from: streamURL)?.absoluteString
    }
    private var canSave: Bool {
        !trimmedName.isEmpty && normalizedStreamURL != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Station" : "Add Station")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.rrSecondaryText)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($focusedField, equals: .name)
                    TextField("Stream URL", text: $streamURL)
                    if !streamURL.isEmpty && normalizedStreamURL == nil {
                        Text("Only HTTPS stream URLs are supported.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("Image") {
                    if let data = localImageData, let img = Image(data: data) {
                        HStack(spacing: 10) {
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .clipped()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Custom image")
                                    .font(.system(size: 13))
                                    .foregroundColor(.rrPrimaryText)
                                Button("Remove") { localImageData = nil }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }

                            Spacer()

                            changeImageButton
                        }
                    } else {
                        chooseImageButton
                    }
                }

                // Preview
                if let data = localImageData, let img = Image(data: data) {
                    Section("Preview") {
                        HStack {
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .clipped()

                            Text(name.isEmpty ? "Station name" : name)
                                .font(.headline)
                                .foregroundColor(name.isEmpty ? .rrSecondaryText : .rrPrimaryText)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save" : "Add") {
                    guard let safeStreamURL = normalizedStreamURL else { return }

                    let station = RadioStation(
                        id: existing?.id ?? UUID(),
                        name: trimmedName,
                        streamURL: safeStreamURL,
                        imageURL: existing?.imageURL ?? "",
                        localImageData: URLSecurityPolicy.boundedLocalImageData(localImageData),
                        isDefault: existing?.isDefault ?? false
                    )
                    onSave(station)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 420)
        #endif
        .sheet(isPresented: $showCrop) {
            if let img = pickedImage {
                ImageCropView(
                    image: img,
                    onCrop: { data in
                        localImageData = data
                        showCrop = false
                    },
                    onCancel: {
                        showCrop = false
                    }
                )
            }
        }
        #if os(iOS)
        .onChange(of: photosPickerItem) { item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      data.count <= URLSecurityPolicy.maxLocalImageBytes,
                      let uiImage = UIImage(data: data),
                      let cgImage = uiImage.cgImage else { return }
                pickedImage = cgImage
                showCrop = true
                photosPickerItem = nil
            }
        }
        #endif
        .onAppear {
            if let station = existing {
                name = station.name
                streamURL = station.streamURL
                localImageData = station.localImageData
            }
            focusedField = .name
        }
    }

    @ViewBuilder
    private var chooseImageButton: some View {
        #if os(macOS)
        Button("Choose image…") { pickImage() }
        #else
        PhotosPicker(selection: $photosPickerItem, matching: .images) {
            Text("Choose image…")
        }
        #endif
    }

    @ViewBuilder
    private var changeImageButton: some View {
        #if os(macOS)
        Button("Change") { pickImage() }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.rrAccent)
        #else
        PhotosPicker(selection: $photosPickerItem, matching: .images) {
            Text("Change")
                .font(.system(size: 12))
                .foregroundColor(.rrAccent)
        }
        #endif
    }

}
