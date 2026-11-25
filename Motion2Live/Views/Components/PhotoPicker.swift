//
//  PhotoPicker.swift
//  Motion2Live
//
//  PHPickerViewController wrapper supporting single & multi-select Motion Photo filtering.
//

import SwiftUI
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct PhotoPicker: UIViewControllerRepresentable {
    /// 批量选择上限：超过此数量会显著抬高临时磁盘占用与缩略图内存，故在 Picker 层硬性拦截。
    static let batchSelectionLimit = 50

    var onSinglePicked: ((URL) -> Void)?
    var onBatchPicked: (([URL], Int) -> Void)?
    var onNoneValidSelected: ((Int) -> Void)?
    var onAnalyzingProgress: ((Int, Int) -> Void)?

    // 兼容原有单选回调签名
    var onImagePicked: ((URL, Bool) -> Void)?
    var onNonMotionPhotoSelected: (() -> Void)?

    // Live Photo 逆向转换选择器回调
    var onLivePhotoPicked: ((ExtractedLivePhoto) -> Void)?
    var onLivePhotoPickFailed: ((String) -> Void)?

    init(onImagePicked: @escaping (URL, Bool) -> Void, onNonMotionPhotoSelected: @escaping () -> Void) {
        self.onImagePicked = onImagePicked
        self.onNonMotionPhotoSelected = onNonMotionPhotoSelected
    }

    init(
        onSinglePicked: @escaping (URL) -> Void,
        onBatchPicked: @escaping ([URL], Int) -> Void,
        onNoneValidSelected: @escaping (Int) -> Void,
        onAnalyzingProgress: ((Int, Int) -> Void)? = nil
    ) {
        self.onSinglePicked = onSinglePicked
        self.onBatchPicked = onBatchPicked
        self.onNoneValidSelected = onNoneValidSelected
        self.onAnalyzingProgress = onAnalyzingProgress
    }

    init(
        onLivePhotoPicked: @escaping (ExtractedLivePhoto) -> Void,
        onLivePhotoPickFailed: @escaping (String) -> Void,
        onAnalyzingProgress: ((Int, Int) -> Void)? = nil
    ) {
        self.onLivePhotoPicked = onLivePhotoPicked
        self.onLivePhotoPickFailed = onLivePhotoPickFailed
        self.onAnalyzingProgress = onAnalyzingProgress
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        // Attach the photo library so results carry an assetIdentifier; the original
        // asset resource is required to recover motion data that third-party apps
        // (e.g. WeChat) rewrite when saving back to the library.
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = (onLivePhotoPicked != nil) ? .livePhotos : .images
        config.selectionLimit = (onBatchPicked != nil) ? Self.batchSelectionLimit : 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else { return }

            if parent.onLivePhotoPicked != nil {
                guard let result = results.first else { return }
                Task {
                    await MainActor.run {
                        self.parent.onAnalyzingProgress?(1, 1)
                    }
                    do {
                        let extracted = try await LivePhotoExtractor.extract(from: result)
                        await MainActor.run {
                            self.parent.onAnalyzingProgress?(0, 0)
                            self.parent.onLivePhotoPicked?(extracted)
                        }
                    } catch {
                        await MainActor.run {
                            self.parent.onAnalyzingProgress?(0, 0)
                            self.parent.onLivePhotoPickFailed?(error.localizedDescription)
                        }
                    }
                }
                return
            }

            let totalCount = results.count

            Task {
                var validURLs: [URL] = []
                var ignoredCount = 0

                for (index, result) in results.enumerated() {
                    await MainActor.run {
                        self.parent.onAnalyzingProgress?(index + 1, totalCount)
                    }

                    let loadedURL = await Self.loadOriginalFile(from: result)
                    if let url = loadedURL {
                        let isMotion = await Task.detached(priority: .userInitiated) {
                            Self.isMotionPhoto(url: url)
                        }.value

                        if isMotion {
                            validURLs.append(url)
                        } else {
                            ignoredCount += 1
                            MediaExportService.removeIfInTemporaryDirectory(url)
                        }
                    } else {
                        ignoredCount += 1
                    }
                }

                await MainActor.run {
                    self.parent.onAnalyzingProgress?(0, 0)

                    if totalCount == 1 {
                        if let singleURL = validURLs.first {
                            if let onSingle = self.parent.onSinglePicked {
                                onSingle(singleURL)
                            } else if let onLegacy = self.parent.onImagePicked {
                                onLegacy(singleURL, true)
                            }
                        } else {
                            if let onNone = self.parent.onNoneValidSelected {
                                onNone(1)
                            } else if let onLegacyNonMotion = self.parent.onNonMotionPhotoSelected {
                                onLegacyNonMotion()
                            }
                        }
                        return
                    }

                    if validURLs.isEmpty {
                        if let onNone = self.parent.onNoneValidSelected {
                            onNone(totalCount)
                        } else if let onLegacyNonMotion = self.parent.onNonMotionPhotoSelected {
                            onLegacyNonMotion()
                        }
                    } else if validURLs.count == 1 && ignoredCount == 0 {
                        if let onSingle = self.parent.onSinglePicked {
                            onSingle(validURLs[0])
                        } else if let onLegacy = self.parent.onImagePicked {
                            onLegacy(validURLs[0], true)
                        }
                    } else {
                        if let onBatch = self.parent.onBatchPicked {
                            onBatch(validURLs, ignoredCount)
                        } else if let firstURL = validURLs.first, let onLegacy = self.parent.onImagePicked {
                            for extraURL in validURLs.dropFirst() {
                                MediaExportService.removeIfInTemporaryDirectory(extraURL)
                            }
                            onLegacy(firstURL, true)
                        }
                    }
                }
            }
        }

        /// Loads the untouched original asset when possible, falling back to the
        /// picker's copy for sources that are not backed by a library asset.
        private static func loadOriginalFile(from result: PHPickerResult) async -> URL? {
            if let assetIdentifier = result.assetIdentifier,
               let url = await loadAssetResource(assetIdentifier: assetIdentifier) {
                return url
            }
            return await loadFile(from: result.itemProvider)
        }

        /// Writes the original photo resource straight to a temp file. Streaming to
        /// disk avoids holding a full-resolution photo in memory.
        private static func loadAssetResource(assetIdentifier: String) async -> URL? {
            let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = fetched.firstObject else { return nil }

            let resources = PHAssetResource.assetResources(for: asset)
            // `.photo` keeps the original bytes (and the embedded video trailer);
            // `.fullSizePhoto` is the edited copy and may no longer be a Motion Photo.
            let preferredTypes: [PHAssetResourceType] = [.photo, .fullSizePhoto, .alternatePhoto]
            guard let resource = preferredTypes.compactMap({ type in
                resources.first(where: { $0.type == type })
            }).first else {
                return nil
            }

            let ext = (resource.originalFilename as NSString).pathExtension.lowercased()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).\(ext.isEmpty ? "jpg" : ext)")

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            let succeeded: Bool = await withCheckedContinuation { continuation in
                PHAssetResourceManager.default().writeData(for: resource, toFile: tempURL, options: options) { error in
                    continuation.resume(returning: error == nil)
                }
            }

            guard succeeded else {
                try? FileManager.default.removeItem(at: tempURL)
                return nil
            }
            return tempURL
        }

        private static func loadFile(from provider: NSItemProvider) async -> URL? {
            let supportedTypes = [
                UTType.jpeg.identifier,
                UTType.heic.identifier,
                "public.avif",
                UTType.image.identifier
            ]
            for type in supportedTypes where provider.hasItemConformingToTypeIdentifier(type) {
                return await withCheckedContinuation { continuation in
                    provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                        guard let url = url, error == nil else {
                            continuation.resume(returning: nil)
                            return
                        }
                        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("\(UUID().uuidString).\(ext)")
                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            continuation.resume(returning: tempURL)
                        } catch {
                            AppLogger.picker.error("Failed to copy picked file: \(error.localizedDescription, privacy: .public)")
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
            return nil
        }

        private nonisolated static func isMotionPhoto(url: URL) -> Bool {
            let supportedExtensions = ["jpg", "jpeg", "heic", "heif", "avif"]
            guard supportedExtensions.contains(url.pathExtension.lowercased()),
                  let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                return false
            }

            let xmpInfo = XMPParser.extractAndParse(from: data)
            return MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) != nil
        }
    }
}
