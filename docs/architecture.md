# Motion2Live 技术架构

本文档介绍 Motion2Live 应用的技术架构和实现细节。

## 技术栈

Motion2Live 使用以下技术和框架开发：

- **SwiftUI**：用于构建现代化、响应式的用户界面
- **AVFoundation**：处理视频和音频媒体
- **PhotosUI**：与设备相册交互，包括 PHPickerViewController 照片选择
- **Photos**：访问照片库资源，使用 PHAssetResourceManager 获取完整原始数据
- **UniformTypeIdentifiers**：处理文件类型识别
- **ImageIO**：处理图像数据和元数据
- **Swift 6**：完全支持 Swift 6 严格并发检查，确保线程安全
- **内存安全**：安全的二进制数据处理和内存对齐机制

## 架构设计

Motion2Live 采用 MVVM (Model-View-ViewModel) 架构模式，结合基于协议的可扩展动态照片处理架构，将用户界面、业务逻辑和数据模型分离，提高代码的可维护性和可测试性。

### 整体架构组件

1. **View**：使用 SwiftUI 构建的用户界面组件，负责展示数据和接收用户输入
2. **ViewModel**：处理业务逻辑，连接 View 和 Model，提供数据绑定和命令执行
3. **Model**：表示应用的数据模型和业务规则
4. **Service**：提供特定功能的服务，如文件处理、照片库访问等

### 动态照片处理架构

为了更好地支持不同品牌的动态照片格式，我们采用了基于协议的可扩展架构。

#### 核心组件

##### 1. MotionPhotoProcessorProtocol
定义了处理动态照片的标准接口：
- `canProcess(xmpInfo:)` - 检测是否能处理特定格式
- `processMotionPhoto(data:xmpInfo:)` - 处理动态照片数据
- `calculateStillImageTime(...)` - 计算静态图片时间

##### 2. BaseMotionPhotoProcessor
提供基础实现和通用逻辑的抽象基类。

##### 3. 品牌特定处理器
- **XiaomiMotionPhotoProcessor** - 处理小米动态照片（已完全实现）
- **PixelMotionPhotoProcessor** - 处理Pixel动态照片（已完全实现）
- **SamsungMotionPhotoProcessor** - 处理三星动态照片（已完全实现）
- **HuaweiMotionPhotoProcessor** - 处理华为动态照片（新增支持）
  - 基于 File Type Box (ftyp) 检测的华为动态照片
  - 支持华为特有的动态照片格式
  - 提供完整的华为动态照片处理流程
- **UnknownMotionPhotoProcessor** - 处理未知类型动态照片（已完全实现）
  - 通过 File Type Box (ftyp) 检测 MP4 视频
  - 支持无 XMP 元数据的动态照片
  - 作为其他处理器的回退方案

##### 4. MotionPhotoProcessorFactory
工厂类，负责根据XMP数据自动选择合适的处理器。支持多层检测机制：
- 首先尝试基于 XMP 元数据的标准处理器
- 如果标准处理器无法处理，则回退到 File Type Box 检测
- 提供 Unknown 类型处理器作为最后的回退方案

#### 数据结构

##### MotionPhotoBrand
```swift
enum MotionPhotoBrand: String, CaseIterable {
    case xiaomi = "Xiaomi"
    case pixel = "Pixel"
    case samsung = "Samsung"
    case huawei = "Huawei"
    case unknown = "Unknown"
}
```

##### MotionPhotoData
```swift
struct MotionPhotoData {
    let imageData: Data
    let videoData: Data
    let stillImageTime: Int
    let brand: MotionPhotoBrand
    let videoOffset: Int?
    let presentationTimestamp: Double?
}
```

## 核心功能实现

### 照片获取与数据完整性保障

为了确保动态照片数据的完整性和准确性，Motion2Live 采用了基于 PHAssetResourceManager 的照片获取方案。

#### 技术方案演进

**传统方案问题**：
- 使用 `PHPickerResult.itemProvider.loadFileRepresentation` 可能导致数据不完整
- 系统可能对文件进行压缩或格式转换
- 无法保证获取到原始的完整文件数据

**新方案优势**：
- 通过 `assetIdentifier` 直接访问照片库中的原始资源
- 使用 `PHAssetResourceManager` 获取完整的原始数据
- 支持 iCloud 照片的网络访问
- 确保 XMP 元数据和视频数据的完整性

#### 实现流程

```swift
func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    guard let result = results.first,
          let assetIdentifier = result.assetIdentifier else { return }
    
    // 1. 通过 assetIdentifier 获取 PHAsset
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = fetchResult.firstObject else { return }
    
    // 2. 获取原始照片资源
    let resources = PHAssetResource.assetResources(for: asset)
    guard let originalResource = resources.first(where: { $0.type == .photo }) else { return }
    
    // 3. 使用 PHAssetResourceManager 获取完整数据
    let manager = PHAssetResourceManager.default()
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true  // 支持 iCloud 照片
    
    var imageData = Data()
    manager.requestData(for: originalResource, options: options,
                       dataReceivedHandler: { data in
                           imageData.append(data)
                       },
                       completionHandler: { error in
                           // 处理完整的原始数据
                           self.processMotionPhoto(data: imageData)
                       })
}
```

#### 关键技术特性

1. **数据完整性保障**：直接从照片库获取原始文件数据，避免系统压缩
2. **iCloud 支持**：通过 `isNetworkAccessAllowed` 支持云端照片下载
3. **流式数据处理**：使用 `dataReceivedHandler` 处理大文件，避免内存溢出
4. **向后兼容性**：保留原有的 `isMotionPhoto(url:)` 方法，确保代码兼容性
5. **错误处理**：完善的错误处理机制，包括网络错误和权限错误

### Motion Photo 解析

Motion Photo 是一种特殊的 JPEG 文件，其中包含静态图像和视频数据。应用通过以下步骤解析 Motion Photo：

1. 读取文件数据
2. 提取 XMP 元数据
3. 使用工厂模式选择合适的处理器
4. 根据品牌特定逻辑提取视频数据

```swift
func extractVideoFromMotionPhoto(url: URL) async {
    guard let data = try? Data(contentsOf: url) else {
        // 错误处理...
        return
    }
    
    if let xmpData = extractXMPData(from: data),
       let xmpInfo = parseXMP(data: xmpData) {
        
        // 使用工厂模式选择处理器
        let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo)
        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        
        // 处理结果...
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

## 扩展新品牌支持

要添加对新品牌动态照片的支持，只需要：

1. 在 `MotionPhotoBrand` 枚举中添加新品牌
2. 创建继承自 `BaseMotionPhotoProcessor` 的新处理器类
3. 实现 `canProcess` 和 `processMotionPhoto` 方法
4. 在 `MotionPhotoProcessorFactory` 中注册新处理器

### 华为动态照片支持实现

华为动态照片支持已完全实现，采用基于 File Type Box 检测的方案：

```swift
// 华为动态照片处理器实现
class HuaweiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() {
        super.init(brand: .huawei)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        // 华为动态照片通过 File Type Box 检测
        return false // 不依赖 XMP 数据
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // 实现华为动态照片的处理逻辑
        // 基于 File Type Box 检测和数据提取
        return extractHuaweiMotionPhoto(from: data)
    }
}

// 回退检测机制
func extractVideoFromMotionPhoto(url: URL) async {
    // 首先尝试 XMP 检测
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
    // ...
}
```

## 当前支持状态

| 品牌 | 状态 | 说明 |
|------|------|------|
| 小米 | ✅ 完全支持 | 新旧版本动态照片均支持 |
| Pixel | ✅ 完全支持 | 支持GContainer:ItemLength格式 |
| 三星 | ✅ 完全支持 | 支持Directory Item和GCamera两种格式 |
| 华为 | ✅ 新增支持 | 基于File Type Box (ftyp)检测的华为动态照片，支持华为特有格式 |
| Unknown | ✅ 回退支持 | 通过File Type Box (ftyp)检测MP4视频，支持无XMP元数据的动态照片 |

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

## 用户体验改进

### 智能引导系统
- **首次使用引导** - 半透明模糊背景的引导面板
- **动态图标** - 呼吸动画的 Live Photo 图标
- **智能状态管理** - 使用 UserDefaults 记住用户操作状态
- **平滑过渡** - 引导提示的淡入淡出动画

### 触感反馈系统
- **播放开始反馈** - 轻度触感反馈 (lightImpactFeedback)
- **播放结束反馈** - 柔和触感反馈 (softImpactFeedback)
- **即时响应** - 与用户操作同步的触感体验

### 交互优化
- **自然手势** - 按住播放，松开停止的直观操作
- **状态记忆** - 首次播放后永久隐藏引导提示
- **动画效果** - 流畅的视觉过渡和状态变化

### 组件化设计
- **PlaybackHintView** - 独立的引导提示组件
- **状态分离** - 清晰的状态变量管理
- **函数职责明确** - 专门的触感反馈和引导管理函数

## 代码质量提升

1. **单一职责原则** - 每个处理器只负责一个品牌
2. **开放封闭原则** - 对扩展开放，对修改封闭
3. **依赖倒置原则** - 依赖抽象而非具体实现
4. **可测试性** - 每个处理器可以独立测试
5. **可维护性** - 代码结构清晰，易于理解和修改

## 测试策略

### 单元测试

应用使用 XCTest 框架进行单元测试，测试关键组件和功能的正确性，特别是各品牌处理器的独立测试。

### UI 测试

应用使用 XCUITest 框架进行 UI 测试，确保用户界面和交互按预期工作。

## 安全考虑

### 数据隐私

应用尊重用户隐私，只在必要时请求照片库访问权限，并且不会将用户数据发送到外部服务器。

### 错误恢复

应用实现了错误恢复机制，确保在出现问题时能够优雅地恢复并提供有用的反馈。

## 最新技术改进 (v1.2.1)

### Swift 6 兼容性
- **严格并发检查**：完全支持 Swift 6 的严格并发检查
- **线程安全**：所有 UI 更新确保在主线程执行
- **异步处理优化**：使用 `MainActor.run` 确保线程安全

### 内存安全改进
- **内存对齐修复**：修复了二进制数据处理中的内存对齐问题
- **安全数据处理**：改进了大文件处理的内存管理
- **崩溃修复**：解决了特定情况下的内存访问崩溃

### 华为动态照片支持
- **File Type Box 检测**：实现基于 ftyp 的华为动态照片检测
- **回退机制**：在 XMP 检测失败时自动回退到华为检测
- **完整处理流程**：支持华为动态照片的预览和导出

### 用户体验优化
- **PHAsset 预取优化**：添加 `fetchPropertySets` 预取原始元数据
- **错误处理改进**：更好的错误提示和恢复机制
- **性能优化**：减少不必要的数据拷贝和内存使用

## 下一步计划

1. 添加单元测试覆盖所有品牌处理器（包括华为）
2. 进一步性能优化和内存使用优化
3. 错误处理和用户体验持续改进
4. 支持更多设备厂商的动态照片格式
5. 批量处理功能
6. 模块化架构进一步优化
7. 依赖注入框架引入
8. 响应式编程模式扩展

## 总结

Motion2Live 采用现代化的架构设计和技术栈，通过基于协议的可扩展架构实现了高效、可靠的多品牌动态照片处理功能。结合 MVVM 架构模式、异步处理和响应式设计，应用实现了良好的用户体验和代码可维护性。新的架构设计使得添加新品牌支持变得简单，同时保持了代码的清晰性和可测试性。
