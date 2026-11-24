//
//  PhotoPicker.swift
//  Motion2Live
//
//  PHPickerViewController wrapper supporting single & multi-select Motion Photo filtering.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PhotoPicker: UIViewControllerRepresentable {
    var onSinglePicked: ((URL) -> Void)?
    var onBatchPicked: (([URL], Int) -> Void)?
    var onNoneValidSelected: ((Int) -> Void)?
    var onAnalyzingProgress: ((Int, Int) -> Void)?

    // 兼容原有单选回调签名
    var onImagePicked: ((URL, Bool) -> Void)?
    var onNonMotionPhotoSelected: (() -> Void)?

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

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = (onBatchPicked != nil) ? 0 : 1

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

            let totalCount = results.count
            let providers = results.map(\.itemProvider)

            Task {
                var validURLs: [URL] = []
                var ignoredCount = 0

                for (index, provider) in providers.enumerated() {
                    await MainActor.run {
                        self.parent.onAnalyzingProgress?(index + 1, totalCount)
                    }

                    let loadedURL = await Self.loadFile(from: provider)
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
            let supportedExtensions = ["jpg", "jpeg", "heic", "avif"]
            guard supportedExtensions.contains(url.pathExtension.lowercased()),
                  let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                return false
            }

            let xmpInfo = XMPParser.extractAndParse(from: data)
            return MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) != nil
        }
    }
}
