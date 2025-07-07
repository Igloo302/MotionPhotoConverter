import SwiftUI
import Photos

class HomeViewModel: ObservableObject {
    @Published var selectedImageURL: URL?
    @Published var isShowingPhotoPicker = false
    @Published var showPermissionAlert = false
    @Published var permissionAlertMessage = ""
    
    let randomEmojis: [String] = ["🌟", "🎉", "🎈", "🎊", "🎁", "🎀", "🎵", "🎶"]
    
    func selectPhoto() {
        checkPhotoLibraryPermission()
    }
    
    // MARK: - Photo Library Permission Management
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized:
            // 用户已授权完全访问，可以继续选择照片
            isShowingPhotoPicker = true
            
        case .limited:
            // 用户选择了限制访问，仍然可以使用但提醒用户
            isShowingPhotoPicker = true
            
        case .denied, .restricted:
            // 用户拒绝或受限制，引导用户到设置页面
            showPermissionDeniedAlert()
            
        case .notDetermined:
            // 首次使用，请求权限
            requestPhotoLibraryPermission()
            
        @unknown default:
            // 未知状态，请求权限
            requestPhotoLibraryPermission()
        }
    }
    
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
            DispatchQueue.main.async {
                switch newStatus {
                case .authorized, .limited:
                    // 用户授权后，打开照片选择器
                    self?.isShowingPhotoPicker = true
                    
                case .denied, .restricted:
                    // 用户拒绝权限，显示引导信息
                    self?.showPermissionDeniedAlert()
                    
                case .notDetermined:
                    // 权限状态未确定，可能需要重试
                    break
                    
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func showPermissionDeniedAlert() {
        permissionAlertMessage = L(.photoLibraryAccessPermission)
        showPermissionAlert = true
    }
    
    func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
