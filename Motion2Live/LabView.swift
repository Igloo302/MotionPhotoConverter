import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

struct LabView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(Localizable.string(.labDescription))) {
                    NavigationLink(destination: CustomLivePhotoView()) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text(Localizable.string(.customLivePhoto))
                                    .font(.headline)
                            }
                            Text(Localizable.string(.customLivePhotoDescription))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(Localizable.string(.lab))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

struct CustomLivePhotoView: View {
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedVideo: URL?
    @State private var isShowingImagePicker = false
    @State private var isShowingVideoPicker = false
    @State private var isProcessing = false
    @State private var hasDisappeared = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertIsSuccess = false

    var body: some View {
        VStack(spacing: 20) {
            Text(Localizable.string(.customLivePhotoDescription))
                .padding()
                .multilineTextAlignment(.center)

            Button(action: {
                isShowingImagePicker = true
            }) {
                Text(selectedImage == nil ? Localizable.string(.selectImage) : Localizable.string(.changeImage))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.bordered)

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
            }

            Button(action: {
                isShowingVideoPicker = true
            }) {
                Text(selectedVideo == nil ? Localizable.string(.selectVideo) : Localizable.string(.changeVideo))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.bordered)

            if selectedVideo != nil {
                Text(Localizable.string(.videoSelected))
                    .foregroundColor(.green)
            }

            Button(action: createLivePhoto) {
                Text(Localizable.string(.createLivePhoto))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .disabled((selectedImageData == nil && selectedImage == nil) || selectedVideo == nil || isProcessing)

            if isProcessing {
                ProgressView()
            }

            Spacer()
        }
        .navigationTitle(Localizable.string(.customLivePhoto))
        .padding()
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(
                image: $selectedImage,
                imageData: $selectedImageData,
                onError: { message in
                    alertIsSuccess = false
                    alertMessage = message
                    showAlert = true
                }
            )
        }
        .sheet(isPresented: $isShowingVideoPicker) {
            VideoPicker(
                videoURL: $selectedVideo,
                onError: { message in
                    alertIsSuccess = false
                    alertMessage = message
                    showAlert = true
                }
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertIsSuccess ? Localizable.string(.success) : Localizable.string(.error)),
                message: Text(alertMessage),
                dismissButton: .default(Text(Localizable.string(.ok)))
            )
        }
        .onDisappear {
            hasDisappeared = true
            if !isProcessing {
                MediaExportService.removeIfInTemporaryDirectory(selectedVideo)
            }
        }
    }

    private func createLivePhoto() {
        guard let videoURL = selectedVideo else { return }
        let rawData = selectedImageData ?? selectedImage?.jpegData(compressionQuality: 1.0)
        guard let imageData = rawData else { return }

        isProcessing = true
        Task {
            defer {
                isProcessing = false
                if hasDisappeared {
                    MediaExportService.removeIfInTemporaryDirectory(videoURL)
                }
            }
            do {
                try await MediaExportService.exportCustomLivePhoto(imageData: imageData, videoURL: videoURL)
                alertIsSuccess = true
                alertMessage = Localizable.string(.livePhotoSaved)
                showAlert = true
            } catch {
                alertIsSuccess = false
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var imageData: Data?
    var onError: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider else { return }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    guard let data = data, error == nil else {
                        AppLogger.picker.error("Failed to load lab image: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                        Task { @MainActor in
                            self.parent.onError?(Localizable.string(.imageLoadFailed))
                        }
                        return
                    }
                    let previewImage = Self.makePreviewThumbnail(from: data) ?? UIImage(data: data)
                    Task { @MainActor in
                        self.parent.imageData = data
                        self.parent.image = previewImage
                    }
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    guard let loaded = image as? UIImage, error == nil else {
                        AppLogger.picker.error("Failed to load lab UIImage: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                        Task { @MainActor in
                            self.parent.onError?(Localizable.string(.imageLoadFailed))
                        }
                        return
                    }
                    let jpegData = loaded.jpegData(compressionQuality: 1.0)
                    Task { @MainActor in
                        self.parent.image = loaded
                        self.parent.imageData = jpegData
                    }
                }
            }
        }

        private static func makePreviewThumbnail(from data: Data) -> UIImage? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 600
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    var onError: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    AppLogger.picker.error("Failed to load lab video: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                    Task { @MainActor in
                        self.parent.onError?(Localizable.string(.videoLoadFailed))
                    }
                    return
                }
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("lab_video_\(UUID().uuidString).\(ext)")
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    Task { @MainActor in
                        let oldURL = self.parent.videoURL
                        self.parent.videoURL = tempURL
                        MediaExportService.removeIfInTemporaryDirectory(oldURL)
                    }
                } catch {
                    AppLogger.picker.error("Failed to copy lab video: \(error.localizedDescription, privacy: .public)")
                    Task { @MainActor in
                        self.parent.onError?(Localizable.string(.videoLoadFailed))
                    }
                }
            }
        }
    }
}

#Preview {
    LabView()
}
