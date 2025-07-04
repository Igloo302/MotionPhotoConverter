# MotionPhotoConverter 技术架构

本文档详细介绍 MotionPhotoConverter 应用的技术架构、代码结构和实现细节。

## 技术栈

MotionPhotoConverter 使用以下技术和框架开发：

- **SwiftUI**：用于构建现代化、响应式的用户界面
- **AVKit**：处理视频播放和编辑
- **PhotosUI**：与设备相册交互
- **UniformTypeIdentifiers**：处理文件类型识别
- **CoreServices**：提供系统级服务支持
- **CoreLocation**：处理地理位置信息
- **ImageIO**：处理图像数据和元数据
- **MobileCoreServices**：提供移动设备特定的系统服务

## 架构设计

MotionPhotoConverter 采用 MVVM (Model-View-ViewModel) 架构模式，将用户界面、业务逻辑和数据模型分离，提高代码的可维护性和可测试性。

### 架构组件

1. **View**：使用 SwiftUI 构建的用户界面组件，负责展示数据和接收用户输入。
2. **ViewModel**：处理业务逻辑，连接 View 和 Model，提供数据绑定和命令执行。
3. **Model**：表示应用的数据模型和业务规则。
4. **Service**：提供特定功能的服务，如文件处理、照片库访问等。

### 数据流

1. 用户在 View 中进行操作（如选择照片、点击导出按钮）
2. View 将操作传递给 ViewModel
3. ViewModel 处理业务逻辑，可能会调用 Service 执行特定任务
4. Service 执行任务并返回结果给 ViewModel
5. ViewModel 更新状态
6. View 通过数据绑定自动更新界面

## 代码结构

### 主要文件和组件

#### 应用入口

- **MotionPhotoConverterApp.swift**：应用的入口点，设置应用的主窗口和初始视图。

```swift
@main
struct MotionPhotoConverterApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

#### 视图组件

- **HomeView.swift**：应用的主页视图，显示欢迎信息和照片选择按钮。

```swift
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                emojiGridView
                contentView
            }
            // 其他视图配置...
        }
    }
    
    // 子视图和辅助方法...
}
```

- **MotionPhotoView.swift**：显示选定的 Motion Photo 并提供导出选项。

```swift
struct MotionPhotoView: View {
    @Environment(\presentationMode) var presentationMode
    @State var sourceURL: URL
    
    // 状态变量...
    
    var body: some View {
        ZStack {
            // 视图内容...
        }
        // 视图修饰符和事件处理...
    }
    
    // 方法实现...
}
```

- **LabView.swift**：实验室功能视图，提供实验性功能如自定义 Live Photo 创建。

```swift
struct LabView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(Localizable.string(.labDescription))) {
                    NavigationLink(destination: CustomLivePhotoView()) {
                        // 链接内容...
                    }
                }
            }
            .navigationTitle(Localizable.string(.lab))
        }
    }
}
```

#### 视图模型

- **HomeViewModel.swift**：HomeView 的视图模型，处理主页相关的业务逻辑。

```swift
class HomeViewModel: ObservableObject {
    @Published var selectedImageURL: URL?
    @Published var isShowingPhotoPicker = false
    
    let randomEmojis: [String] = ["🌟", "🎉", "🎈", "🎊", "🎁", "🎀", "🎵", "🎶", "🌈", "🍭", "🍬", "🍫", "🍿", "🧁", "🍰", "🍩"]
    
    func selectPhoto() {
        isShowingPhotoPicker = true
    }
}
```

#### 辅助组件

- **VideoPlayerObserver.swift**：观察视频播放器状态的辅助类。

```swift
class VideoPlayerObserver: NSObject, ObservableObject {
    @Published var isVideoReady = false
    var player: AVPlayer? {
        didSet {
            if let player = player {
                player.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            }
        }
    }
    
    // 观察者方法实现...
}
```

- **PhotoPicker.swift**：照片选择器组件，允许用户从相册中选择照片。

```swift
struct PhotoPicker: UIViewControllerRepresentable {
    var onImagePicked: (URL, Bool) -> Void
    var onNonMotionPhotoSelected: () -> Void
    
    // UIViewControllerRepresentable 协议实现...
}
```

- **LivePhotoCreator.swift**：创建 Live Photo 的辅助类。

```swift
class LivePhotoCreator {
    static func create(from image: UIImage, videoURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        // Live Photo 创建逻辑...
    }
    
    // 辅助方法...
}
```

#### 本地化

- **Localizable.swift**：处理应用的多语言支持。

```swift
enum Language: String {
    case english = "en"
    case chinese = "zh"
    // 其他语言...
    
    static var current: Language {
        // 获取当前语言的逻辑...
    }
}

struct Localizable {
    static func string(_ key: LocalizableKey) -> String {
        // 根据当前语言返回对应的字符串...
    }
}

enum LocalizableKey {
    // 本地化键定义...
    
    var english: String {
        // 英文字符串...
    }
    
    var chinese: String {
        // 中文字符串...
    }
    
    // 其他语言...
}
```

## 核心功能实现

### Motion Photo 解析

Motion Photo 是一种特殊的 JPEG 文件，其中包含静态图像和视频数据。应用通过以下步骤解析 Motion Photo：

1. 读取文件数据
2. 提取 XMP 元数据
3. 解析元数据获取视频偏移量和时间戳
4. 根据偏移量提取视频数据

```swift
func extractVideoFromMotionPhoto(url: URL) async {
    guard let data = try? Data(contentsOf: url) else {
        // 错误处理...
        return
    }
    
    if let xmpData = extractXMPData(from: data),
       let xmpInfo = parseXMP(data: xmpData) {
        
        if let offset = xmpInfo["GCamera:MicroVideoOffset"] ?? xmpInfo["GContainer:ItemLength"],
           let offsetValue = Int(offset),
           let timestampString = xmpInfo["GCamera:MicroVideoPresentationTimestampUs"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"],
           let timestamp = Double(timestampString) {
            
            // 提取视频数据
            self.videoData = data.suffix(offsetValue)
            
            // 处理视频数据...
        }
    }
}
```

### Live Photo 创建

创建 Live Photo 需要以下步骤：

1. 准备静态图像（JPEG 格式）
2. 准备视频文件（MOV 格式）
3. 添加必要的元数据
4. 使用 PhotosUI 框架保存到相册

```swift
func saveLivePhoto(imageURL: URL, videoURL: URL, creationDate: Date?, modificationDate: Date?) {
    // 生成唯一标识符
    let assetIdentifier = UUID().uuidString
    
    // 添加元数据到图像和视频
    // ...
    
    // 保存到相册
    PHPhotoLibrary.shared().performChanges({
        let creationRequest = PHAssetCreationRequest.forAsset()
        creationRequest.addResource(with: .photo, fileURL: imageURL, options: nil)
        creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
        creationRequest.creationDate = creationDate
    }) { success, error in
        // 处理结果...
    }
}
```

### GIF 创建

创建 GIF 需要以下步骤：

1. 从视频中提取帧
2. 使用 ImageIO 框架创建 GIF 文件
3. 保存到相册

```swift
func exportAsGIF() {
    // 从视频中提取帧
    // ...
    
    // 创建 GIF
    let gifURL = FileManager.default.temporaryDirectory.appendingPathComponent("exported_gif.gif")
    guard let destination = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
        // 错误处理...
        return
    }
    
    // 设置 GIF 属性
    let gifProperties = [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFLoopCount as String: 0
        ]
    ]
    CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
    
    // 添加帧
    for i in 0..<frameCount {
        // 添加帧到 GIF...
    }
    
    // 完成 GIF 创建
    if CGImageDestinationFinalize(destination) {
        // 保存到相册...
    } else {
        // 错误处理...
    }
}
```

## 性能优化

### 异步处理

应用使用 Swift 的异步/等待 (async/await) 特性和 Task API 处理耗时操作，避免阻塞主线程，保持用户界面的响应性。

```swift
Task {
    await extractVideoFromMotionPhoto(url: sourceURL)
}
```

### 内存管理

应用在处理大文件时注意内存管理，使用临时文件和流式处理减少内存占用。

```swift
// 使用临时文件
let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
do {
    try videoData?.write(to: tempURL)
    // 处理文件...
} catch {
    // 错误处理...
}

// 清理临时文件
try? FileManager.default.removeItem(at: tempURL)
```

### 错误处理

应用实现了全面的错误处理机制，确保在出现问题时能够提供有用的反馈并优雅地恢复。

```swift
do {
    // 尝试执行操作...
} catch {
    print("处理视频文件时出错: \(error)")
    print("错误详情: \(error.localizedDescription)")
    if let nsError = error as NSError? {
        print("错误域: \(nsError.domain)")
        print("错误码: \(nsError.code)")
        print("错误用户信息: \(nsError.userInfo)")
    }
    await MainActor.run {
        showAlert(message: Localizable.string(.errorProcessingVideoFile))
    }
}
```

## 用户界面设计

### 响应式设计

应用使用 SwiftUI 的响应式设计原则，确保在不同设备和屏幕尺寸上提供一致的用户体验。

```swift
VStack(spacing: 30) {
    Text(Localizable.string(.homeTitle))
        .font(.system(size: 28, weight: .bold))
        .multilineTextAlignment(.center)
    
    Text(Localizable.string(.homeDescription))
        .font(.system(size: 16))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .foregroundColor(.secondary)
    
    Spacer()
    
    Button(action: viewModel.selectPhoto) {
        Text(Localizable.string(.selectMotionPhoto))
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
    }
    .padding(.horizontal, 40)
    .padding(.bottom, 40)
}
```

### 动画和过渡

应用使用动画和过渡效果增强用户体验，使界面更加流畅和直观。

```swift
PlayerView(player: player)
    .aspectRatio(contentMode: .fill)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .edgesIgnoringSafeArea(.horizontal)
    .opacity(isPlayingVideo ? 1 : 0)
    .animation(.easeInOut(duration: 0.2), value: isPlayingVideo)
    .clipped()
```

## 测试策略

### 单元测试

应用使用 XCTest 框架进行单元测试，测试关键组件和功能的正确性。

### UI 测试

应用使用 XCUITest 框架进行 UI 测试，确保用户界面和交互按预期工作。

## 安全考虑

### 数据隐私

应用尊重用户隐私，只在必要时请求照片库访问权限，并且不会将用户数据发送到外部服务器。

### 错误恢复

应用实现了错误恢复机制，确保在出现问题时能够优雅地恢复并提供有用的反馈。

## 未来架构改进

### 模块化

计划将应用拆分为更小的模块，提高代码的可维护性和可重用性。

### 依赖注入

计划引入依赖注入框架，减少组件之间的耦合，提高代码的可测试性。

### 响应式编程

计划引入更多响应式编程模式，简化状态管理和数据流。

## 总结

MotionPhotoConverter 采用现代化的架构设计和技术栈，提供高效、可靠的 Motion Photo 处理功能。通过 MVVM 架构模式、异步处理和响应式设计，应用实现了良好的用户体验和代码可维护性。未来的开发将继续优化架构，提高性能和可扩展性。