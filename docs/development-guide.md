# Motion2Live 开发指南

本指南为开发者提供参与 Motion2Live 项目开发的核心信息。

## 目录

- [开发环境设置](#开发环境设置)
- [项目结构](#项目结构)
- [编码规范](#编码规范)
- [开发工作流](#开发工作流)
- [调试和测试](#调试和测试)

## 开发环境设置

### 系统要求
- **macOS**: 13.0 (Ventura) 或更高版本
- **Xcode**: 15.0 或更高版本
- **iOS 部署目标**: 15.0 或更高版本
- **Swift**: 5.9 或更高版本（完全支持 Swift 6 严格并发检查）

### 快速开始
1. 克隆项目：`git clone <repository-url>`
2. 打开 `MotionPhotoConverter.xcodeproj`
3. 配置开发者账户和 Bundle Identifier
4. 选择目标设备并运行

### 推荐测试设备
- iPhone 16 Pro (iOS 18.0)
- iPad Air (第5代) (iPadOS 18.0)

## 项目结构

```
Motion2Live/
├── MotionPhotoConverterApp.swift  # 应用入口和主要视图
├── HomeView.swift                 # 主界面
├── HomeViewModel.swift            # 主页视图模型
├── Models/                        # 数据模型
│   ├── MotionPhoto.swift         # 动态照片数据模型
│   └── MotionPhotoProcessor.swift # 多品牌处理器架构
├── Components/                    # UI 组件
│   ├── PlaybackHintView          # 播放引导组件
│   └── ExportOptionsView         # 导出选项组件
│   └── SupportedBrandsView       # 支持品牌展示组件
├── Utils/                         # 工具类
│   ├── XMPParser.swift           # XMP 元数据解析
│   ├── VideoExporter.swift       # 视频导出
│   └── LivePhotoCreator.swift    # Live Photo 创建
├── Resources/
│   ├── Localizable.swift         # 本地化字符串
│   └── Assets.xcassets           # 图片资源
└── Info.plist                    # 应用配置
```

### 核心组件

#### 主要视图和模型
- **MotionPhotoConverterApp.swift**: 应用入口点和主要视图逻辑
- **HomeView.swift**: 主界面，处理照片选择和预览
- **HomeViewModel.swift**: 主页业务逻辑处理
- **MotionPhoto.swift**: 动态照片数据模型

#### 多品牌处理器架构
- **MotionPhotoProcessor.swift**: 基于协议的可扩展处理器架构
- **XiaomiMotionPhotoProcessor**: 小米动态照片处理器
- **AndroidMotionPhotoProcessor**: Android (Pixel/Samsung) 处理器
- **HuaweiMotionPhotoProcessor**: 华为动态照片处理器（新增）
- **MotionPhotoProcessorFactory**: 处理器工厂类，支持多层回退检测

#### 用户体验组件
- **PlaybackHintView**: 首次使用引导组件
- **ExportOptionsView**: 导出选项面板
- **SupportedBrandsView**: 支持品牌展示

#### 核心功能模块
- **XMPParser**: XMP 元数据解析
- **VideoExporter**: 视频导出功能
- **LivePhotoCreator**: Live Photo 创建逻辑

## 编码规范

### Swift 代码风格
遵循 [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)：

- **类名**: PascalCase (`MotionPhotoProcessor`)
- **属性/方法**: camelCase (`processMotionPhoto()`)
- **常量**: camelCase (`maxVideoLength`)
- **枚举**: PascalCase，case 使用 camelCase

### 代码组织
```swift
class HomeView: View {
    // MARK: - Properties
    @State private var selectedPhoto: UIImage?
    
    // MARK: - Body
    var body: some View {
        // 视图实现
    }
    
    // MARK: - Private Methods
    private func processPhoto() {
        // 实现
    }
}
```

### SwiftUI 最佳实践
- 将复杂视图拆分为小的、可复用的组件
- 使用 `@State` 管理本地状态
- 使用 `@StateObject` 管理视图模型
- 使用 `@Binding` 在视图间传递状态
- 使用 `MainActor.run` 确保 UI 更新在主线程执行（Swift 6 兼容）
- 遵循严格并发检查规范，避免数据竞争

### 用户体验功能开发

#### 智能引导系统
```swift
// 状态管理
@State private var showPlaybackHint = false
@State private var hasUserPlayedVideo = UserDefaults.standard.bool(forKey: "hasUserPlayedVideo")

// 引导显示逻辑
.onAppear {
    if !hasUserPlayedVideo && selectedImageURL != nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPlaybackHint = true
            }
        }
    }
}
```

#### 触感反馈实现
```swift
// 触感反馈生成器
private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
private let softImpactFeedback = UIImpactFeedbackGenerator(style: .soft)

// 播放开始时的反馈
func startVideoPlaybackWithFeedback() {
    lightImpactFeedback.impactOccurred()
    startVideoPlayback()
    hidePlaybackHint()
}

// 播放结束时的反馈
func stopVideoPlaybackWithFeedback() {
    softImpactFeedback.impactOccurred()
    stopVideoPlayback()
}
```

#### 组件化设计原则
```swift
// 独立的引导组件
struct PlaybackHintView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        // 组件实现
    }
}

// 在主视图中使用
if showPlaybackHint {
    PlaybackHintView(onDismiss: hidePlaybackHint)
        .transition(.opacity)
}
```

### 照片获取与数据完整性开发

#### PHAssetResourceManager 最佳实践

为确保动态照片数据的完整性，推荐使用基于 `PHAssetResourceManager` 的照片获取方案：

```swift
// 照片选择器实现
func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    guard let result = results.first,
          let assetIdentifier = result.assetIdentifier else {
        // 处理无效选择
        return
    }
    
    // 1. 通过 assetIdentifier 获取 PHAsset
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = fetchResult.firstObject else {
        print("[Error] Failed to fetch asset with identifier: \(assetIdentifier)")
        return
    }
    
    // 2. 获取原始照片资源
    let resources = PHAssetResource.assetResources(for: asset)
    guard let originalResource = resources.first(where: { $0.type == .photo }) else {
        print("[Error] No photo resource found for asset")
        return
    }
    
    // 3. 配置请求选项
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true  // 支持 iCloud 照片
    options.progressHandler = { progress in
        DispatchQueue.main.async {
            // 更新进度 UI
            print("[Progress] Download progress: \(progress)")
        }
    }
    
    // 4. 请求完整数据
    let manager = PHAssetResourceManager.default()
    var imageData = Data()
    
    manager.requestData(for: originalResource, options: options,
                       dataReceivedHandler: { data in
                           imageData.append(data)
                       },
                       completionHandler: { error in
                           DispatchQueue.main.async {
                               if let error = error {
                                   print("[Error] Failed to load image data: \(error.localizedDescription)")
                                   return
                               }
                               
                               // 保存到临时文件
                               let tempURL = self.saveToTemporaryFile(data: imageData, 
                                                                     originalFilename: originalResource.originalFilename)
                               
                               // 检测并处理动态照片
                               if self.isMotionPhoto(data: imageData) {
                                   self.onImagePicked(tempURL)
                               } else {
                                   self.showNotMotionPhotoAlert = true
                               }
                           }
                       })
}

// 临时文件保存
private func saveToTemporaryFile(data: Data, originalFilename: String) -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let tempURL = tempDir.appendingPathComponent(originalFilename)
    
    do {
        try data.write(to: tempURL)
        return tempURL
    } catch {
        print("[Error] Failed to save temporary file: \(error.localizedDescription)")
        // 使用备用文件名
        let fallbackURL = tempDir.appendingPathComponent("motion_photo_\(UUID().uuidString).jpg")
        try? data.write(to: fallbackURL)
        return fallbackURL
    }
}
```

# Motion2Live 开发指南
## 编码规范
### 照片获取与数据完整性开发
#### 华为动态照片处理开发

华为动态照片采用基于 File Type Box 检测的处理方案：

```swift
// 华为动态照片检测
func hasFileTypeBox(data: Data) -> Bool {
    guard data.count >= 12 else { return false }
    
    // 检查 File Type Box (ftyp)
    let ftypSignature = Data([0x66, 0x74, 0x79, 0x70]) // "ftyp"
    let range = 4..<min(data.count - 4, 100)
    
    return data.range(of: ftypSignature, in: range) != nil
}

// 华为动态照片处理器
class HuaweiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        // 华为动态照片不依赖 XMP 数据
        return false
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // 基于 File Type Box 的处理逻辑
        return extractHuaweiMotionPhoto(from: data)
    }
}

// 回退检测机制
func extractVideoFromMotionPhoto(url: URL) async {
    // 首先尝试 XMP 检测
    var processor: MotionPhotoProcessorProtocol?
    
    if let xmpData = extractXMPData(from: data),
       let xmpInfo = parseXMP(data: xmpData) {
        processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo)
    }
    
    // 如果 XMP 检测失败，尝试华为动态照片回退检测
    if processor == nil {
        if hasFileTypeBox(data: data) {
            processor = HuaweiMotionPhotoProcessor()
        }
    }
    
    // 使用最终确定的处理器
    let finalProcessor = processor ?? UnknownMotionPhotoProcessor()
    // 继续处理...
}
```

#### 照片库权限管理最佳实践

应用需要访问用户的照片库来选择和处理动态照片，因此需要实现完善的权限管理机制：

```swift
// 权限检查和请求的完整实现
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
    permissionAlertMessage = "Motion2Live 需要访问您的照片库来选择动态照片。请前往设置 > Motion2Live > 照片，选择"所有照片"以获得最佳体验。"
    showPermissionAlert = true
}

func openAppSettings() {
    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsURL)
    }
}
```

#### 权限状态说明

- **`.authorized`**: 用户授权完全访问，应用可以访问所有照片
- **`.limited`**: 用户选择限制访问，应用只能访问用户选择的照片
- **`.denied`**: 用户明确拒绝访问权限
- **`.restricted`**: 由于家长控制等原因限制访问
- **`.notDetermined`**: 首次使用，权限状态未确定

#### 用户体验最佳实践

1. **权限请求时机**: 在用户主动选择照片时请求权限，而不是应用启动时
2. **清晰的权限说明**: 向用户解释为什么需要照片库访问权限
3. **优雅的降级处理**: 在权限被拒绝时，提供明确的引导信息
4. **设置页面引导**: 提供便捷的跳转到系统设置的方式

### 边界场景处理最佳实践

#### 限制访问模式下的照片选择

当用户选择了「限制访问」权限，但尝试访问未授权的照片时，需要准确识别并处理这种边界场景：

```swift
// 在 PhotoPicker 中区分权限问题和照片格式问题
struct PhotoPicker: UIViewControllerRepresentable {
    let onImagePicked: (URL, Bool) -> Void
    let onNonMotionPhotoSelected: () -> Void
    let onPhotoAccessDenied: () -> Void  // 专门处理权限问题
    let onCancelled: (() -> Void)?
}

// 在错误处理中检查权限状态
private func processWithAssetIdentifier(_ assetIdentifier: String) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = fetchResult.firstObject else {
        // 检查是否是权限问题
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        DispatchQueue.main.async {
            if authStatus == .limited {
                self.parent.onPhotoAccessDenied()  // 权限问题
            } else {
                self.parent.onNonMotionPhotoSelected()  // 其他问题
            }
        }
        return
    }
}
```

#### 错误信息本地化

为不同的错误场景提供准确的本地化信息：

```swift
// 在 Localizable.swift 中定义专门的错误信息
case photoAccessDenied
case photoNotAccessibleInLimitedMode
case selectedPhotoIsNotMotionPhoto

// 中文版本
case .photoNotAccessibleInLimitedMode: 
    return "在限制访问模式下无法访问此照片。请授予完整的照片库访问权限或选择其他照片。"
case .selectedPhotoIsNotMotionPhoto: 
    return "所选照片不是动态照片"
```

#### 核心原则

1. **准确的错误识别**: 区分权限问题、网络问题、格式问题等不同类型的错误
2. **用户友好的提示**: 提供具体的解决方案而不是技术性错误信息
3. **一致的用户体验**: 在不同权限状态下保持一致的交互逻辑
4. **渐进式权限请求**: 根据用户的使用情况适时引导权限升级

#### 错误处理和用户体验

```swift
// 网络权限检查（已更新为完整的权限管理）
private func checkPhotoLibraryPermission() -> Bool {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    switch status {
    case .authorized, .limited:
        return true
    case .denied, .restricted:
        // 引导用户到设置页面
        showPermissionAlert = true
        return false
    case .notDetermined:
        // 请求权限
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async {
                self.checkPhotoLibraryPermission()
            }
        }
        return false
    @unknown default:
        return false
    }
}

// iCloud 下载进度显示
@State private var downloadProgress: Double = 0.0
@State private var isDownloading: Bool = false

// 在 UI 中显示进度
if isDownloading {
    ProgressView("正在下载照片...", value: downloadProgress, total: 1.0)
        .progressViewStyle(LinearProgressViewStyle())
}
```

#### Swift 6 兼容性开发

项目完全支持 Swift 6 严格并发检查，需要遵循以下最佳实践：

```swift
// 确保 UI 更新在主线程执行
func showAlert(message: String) {
    Task { @MainActor in
        // UI 更新代码
        self.alertMessage = message
        self.showAlert = true
    }
}

// 或使用 MainActor.run
func updateUI() async {
    await MainActor.run {
        // UI 更新代码
    }
}

// 异步处理中的线程安全
func extractVideoFromMotionPhoto(url: URL) async {
    // 后台处理
    let result = await processInBackground()
    
    // 确保 UI 更新在主线程
    await MainActor.run {
        self.updateUIWithResult(result)
    }
}
```

#### 内存安全改进

项目修复了内存对齐和数据处理中的安全问题：

```swift
// 安全的二进制数据处理
func safeDataAccess(data: Data, offset: Int, length: Int) -> Data? {
    guard offset >= 0,
          length > 0,
          offset + length <= data.count else {
        return nil
    }
    
    return data.subdata(in: offset..<(offset + length))
}

// 内存对齐检查
func alignedMemoryAccess<T>(data: Data, offset: Int, type: T.Type) -> T? {
    let size = MemoryLayout<T>.size
    let alignment = MemoryLayout<T>.alignment
    
    guard offset % alignment == 0,
          offset + size <= data.count else {
        return nil
    }
    
    return data.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: offset, as: T.self)
    }
}
```

#### 性能优化建议

1. **内存管理**：
   ```swift
   // 使用流式处理避免大文件内存溢出
   var imageData = Data()
   imageData.reserveCapacity(10 * 1024 * 1024) // 预分配 10MB
   ```

2. **并发处理**：
   ```swift
   // 在后台队列处理数据（Swift 6 兼容）
   Task {
       let isMotion = await self.isMotionPhoto(data: imageData)
       await MainActor.run {
           // 更新 UI
       }
   }
   ```

3. **缓存策略**：
   ```swift
   // 缓存已处理的动态照片信息
   private var motionPhotoCache: [String: Bool] = [:]
   
   func isMotionPhoto(assetIdentifier: String, data: Data) -> Bool {
       if let cached = motionPhotoCache[assetIdentifier] {
           return cached
       }
       let result = isMotionPhoto(data: data)
       motionPhotoCache[assetIdentifier] = result
       return result
   }
   ```

#### 调试和测试

```swift
// 调试日志
static let photoLogger = Logger(subsystem: "com.motion2live", category: "PhotoPicker")

// 在关键步骤添加日志
photoLogger.info("Starting photo selection with assetIdentifier: \(assetIdentifier)")
photoLogger.debug("Image data size: \(imageData.count) bytes")
photoLogger.error("Photo processing failed: \(error.localizedDescription)")

// 性能测试
let startTime = CFAbsoluteTimeGetCurrent()
// ... 处理逻辑
let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
photoLogger.info("Photo processing completed in \(timeElapsed) seconds")
```

## 开发工作流

### Git 工作流
使用简化的 Git Flow：

- **main**: 稳定的发布版本
- **develop**: 最新的开发代码
- **feature/***: 新功能开发分支

### 开发流程
1. 从 develop 创建功能分支：`git checkout -b feature/feature-name`
2. 开发并提交代码
3. 推送分支并创建 Pull Request
4. 代码审查后合并到 develop

### 提交信息规范
使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>: <description>
```

**类型**：
- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 文档更新
- `refactor`: 代码重构
- `test`: 测试相关

**示例**：
```bash
git commit -m "feat: add motion photo export functionality"
git commit -m "fix: resolve crash when processing large files"
```

## 调试和测试

### 测试策略

#### 单元测试
项目使用 XCTest 框架：

```swift
import XCTest
@testable import MotionPhotoConverter

class MotionPhotoProcessorTests: XCTestCase {
    func testProcessValidMotionPhoto() {
        let processor = MotionPhotoProcessor()
        // 测试逻辑
    }
}
```

重点测试模块：
- `MotionPhotoProcessor` 各品牌处理器（包括华为）
- `XMPParser` 元数据解析
- `VideoExporter` 和 `LivePhotoCreator`
- 用户状态管理逻辑
- 华为动态照片 File Type Box 检测
- Swift 6 并发安全性
- 内存对齐和安全访问

#### UI 测试
使用 XCUITest 测试用户界面：

```swift
class MotionPhotoConverterUITests: XCTestCase {
    func testMainFlow() {
        let app = XCUIApplication()
        app.launch()
        
        let selectButton = app.buttons["选择动态照片"]
        XCTAssertTrue(selectButton.exists)
    }
}
```

重点测试场景：
- 首次使用引导流程
- 触感反馈响应
- 动态照片选择和预览
- 导出功能完整性

#### 集成测试
```bash
# 运行所有测试
xcodebuild test -scheme MotionPhotoConverter -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# 在 Xcode 中使用 Cmd+U
```

### 调试技巧

#### 日志记录
```swift
// 使用统一的日志系统
import os.log

static let logger = Logger(subsystem: "com.motion2live", category: "MotionPhoto")

// 不同级别的日志
logger.info("Motion photo processing started")
logger.debug("Processing \(brand.rawValue) motion photo")
logger.error("Failed to extract video: \(error.localizedDescription)")
```

#### 用户体验调试
```swift
// 调试引导系统
print("[UX] Playback hint shown: \(showPlaybackHint)")
print("[UX] User has played video: \(hasUserPlayedVideo)")

// 调试触感反馈
print("[Haptic] Light impact triggered")
print("[Haptic] Soft impact triggered")
```

#### 性能分析
- 使用 Instruments 的 Time Profiler 分析 CPU 使用
- 使用 Allocations 监控内存使用，特别是大文件处理时
- 使用 Leaks 检测内存泄漏
- 测试不同尺寸动态照片的处理时间

#### 真机测试
- 连接 iOS 设备进行真实环境测试
- 测试相机和照片库集成
- 验证真实 Motion Photo 文件处理
- 验证不同品牌手机的兼容性（小米、Pixel、三星、华为）
- 验证触感反馈在不同设备上的表现
- 测试用户引导在不同屏幕尺寸上的显示效果

### 最新开发特性 (v1.2.1)

#### 华为动态照片支持
- 实现基于 File Type Box 检测的华为动态照片处理
- 添加回退检测机制，在 XMP 检测失败时自动尝试华为检测
- 完整的华为动态照片预览和导出功能

#### Swift 6 兼容性
- 完全支持 Swift 6 严格并发检查
- 所有 UI 更新确保在主线程执行
- 使用 `MainActor.run` 和 `@MainActor` 确保线程安全

#### 内存安全改进
- 修复二进制数据处理中的内存对齐问题
- 改进大文件处理的内存管理
- 添加安全的数据访问检查

#### 用户体验优化
- 添加 `fetchPropertySets` 预取原始元数据，解决 PHAsset 警告
- 改进错误处理和用户反馈
- 优化性能，减少不必要的数据拷贝

---

本开发指南涵盖了 Motion2Live 项目开发的核心要素。如有疑问，请查阅项目文档或在 GitHub 上提出 Issue。