import SwiftUI
import Combine
import Photos

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedImageURL: URL?
    @Published var isShowingPhotoPicker = false
    
    // 批量处理相关状态
    @Published var batchURLs: [URL] = []
    @Published var ignoredCount: Int = 0
    @Published var isShowingBatchView = false
    @Published var isAnalyzingPhotos = false
    @Published var analyzingCurrent: Int = 0
    @Published var analyzingTotal: Int = 0
    
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
        batchURLs = []
        ignoredCount = 0
    }
}
