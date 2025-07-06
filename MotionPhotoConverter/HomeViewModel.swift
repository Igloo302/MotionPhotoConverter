import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var selectedImageURL: URL?
    @Published var isShowingPhotoPicker = false
    
    let randomEmojis: [String] = ["🌟", "🎉", "🎈", "🎊", "🎁", "🎀", "🎵", "🎶"]
    
    func selectPhoto() {
        isShowingPhotoPicker = true
    }
}
