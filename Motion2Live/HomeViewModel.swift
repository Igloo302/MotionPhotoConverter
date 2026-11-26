import SwiftUI
import Combine
import Photos
import UniformTypeIdentifiers

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedImageURL: URL?
    @Published var isShowingPhotoPicker = false
    @Published var isShowingFileImporter = false
    @Published var isShowingLabView = false
    @Published var pendingAlertMessage: String?

    // 批量处理相关状态
    @Published var batchURLs: [URL] = []
    @Published var ignoredCount: Int = 0
    @Published var isShowingBatchView = false
    @Published var isAnalyzingPhotos = false
    @Published var analyzingCurrent: Int = 0
    @Published var analyzingTotal: Int = 0

    private var importTask: Task<Void, Never>?

    let randomEmojis: [String] = ["🌟", "🎉", "🎈", "🎊", "🎁", "🎀", "🎵", "🎶", "🌈", "🍭", "🍬", "🍫", "🍿", "🧁", "🍰", "🍩"]

    func selectPhoto() {
        // Library authorization is what lets PHPicker return an assetIdentifier so we
        // can read the original resource. The picker still opens without it, in which
        // case PhotoPicker falls back to the picker-provided copy.
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else {
            isShowingPhotoPicker = true
            return
        }

        Task { @MainActor in
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            self.isShowingPhotoPicker = true
        }
    }

    func resetBatchState() {
        isShowingBatchView = false
        for url in batchURLs {
            MediaExportService.removeIfInTemporaryDirectory(url)
        }
        batchURLs = []
        ignoredCount = 0
    }

    func handleIncomingURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        importTask?.cancel()
        importTask = Task {
            isAnalyzingPhotos = true
            let result = await LocalMediaImportHelper.importMotionPhotos(from: urls) { current, total in
                self.analyzingCurrent = current
                self.analyzingTotal = total
                self.isAnalyzingPhotos = (total > 0)
            }

            if Task.isCancelled {
                for url in result.validURLs {
                    MediaExportService.removeIfInTemporaryDirectory(url)
                }
                isAnalyzingPhotos = false
                analyzingCurrent = 0
                analyzingTotal = 0
                return
            }

            isAnalyzingPhotos = false
            routeImportedResults(
                validURLs: result.validURLs,
                ignoredCount: result.ignoredCount,
                totalCount: urls.count
            )
        }
    }

    func handleDroppedProviders(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }

        importTask?.cancel()
        importTask = Task {
            analyzingCurrent = 1
            analyzingTotal = providers.count
            isAnalyzingPhotos = true

            var acceptedTypes: [UTType] = [.jpeg, .heic]
            if let avif = UTType("public.avif") {
                acceptedTypes.append(avif)
            }
            acceptedTypes.append(.image)

            let copiedTempURLs = await LocalMediaImportHelper.copyDroppedProvidersToTemp(
                providers,
                acceptedTypes: acceptedTypes
            )

            if Task.isCancelled {
                for url in copiedTempURLs {
                    MediaExportService.removeIfInTemporaryDirectory(url)
                }
                isAnalyzingPhotos = false
                analyzingCurrent = 0
                analyzingTotal = 0
                return
            }

            var validURLs: [URL] = []
            var ignoredCount = 0

            for (index, tempURL) in copiedTempURLs.enumerated() {
                if Task.isCancelled {
                    MediaExportService.removeIfInTemporaryDirectory(tempURL)
                    continue
                }

                analyzingCurrent = index + 1
                analyzingTotal = copiedTempURLs.count

                let isMotion = await Task.detached(priority: .userInitiated) {
                    LocalMediaImportHelper.isSupportedMotionPhoto(at: tempURL)
                }.value

                if isMotion {
                    validURLs.append(tempURL)
                } else {
                    ignoredCount += 1
                    MediaExportService.removeIfInTemporaryDirectory(tempURL)
                }
            }

            if Task.isCancelled {
                for url in validURLs {
                    MediaExportService.removeIfInTemporaryDirectory(url)
                }
                isAnalyzingPhotos = false
                analyzingCurrent = 0
                analyzingTotal = 0
                return
            }

            let failedDrops = max(0, providers.count - copiedTempURLs.count)
            ignoredCount += failedDrops

            isAnalyzingPhotos = false
            analyzingCurrent = 0
            analyzingTotal = 0

            routeImportedResults(
                validURLs: validURLs,
                ignoredCount: ignoredCount,
                totalCount: providers.count
            )
        }
    }

    private func routeImportedResults(validURLs: [URL], ignoredCount: Int, totalCount: Int) {
        if totalCount <= 1 {
            if let singleURL = validURLs.first {
                let previousURL = selectedImageURL
                selectedImageURL = singleURL
                if previousURL != singleURL {
                    MediaExportService.removeIfInTemporaryDirectory(previousURL)
                }
            } else {
                pendingAlertMessage = Localizable.string(.selectedPhotoIsNotMotionPhoto)
            }
            return
        }

        if validURLs.isEmpty {
            pendingAlertMessage = Localizable.string(.noValidMotionPhotosInBatch, totalCount)
        } else if validURLs.count == 1 && ignoredCount == 0 {
            let singleURL = validURLs[0]
            let previousURL = selectedImageURL
            selectedImageURL = singleURL
            if previousURL != singleURL {
                MediaExportService.removeIfInTemporaryDirectory(previousURL)
            }
        } else {
            for oldURL in batchURLs where !validURLs.contains(oldURL) {
                MediaExportService.removeIfInTemporaryDirectory(oldURL)
            }
            batchURLs = validURLs
            self.ignoredCount = ignoredCount
            isShowingBatchView = true
        }
    }
}
