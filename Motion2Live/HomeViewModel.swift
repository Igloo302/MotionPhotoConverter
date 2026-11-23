import SwiftUI

class HomeViewModel: ObservableObject {
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
        isShowingPhotoPicker = true
    }
}
