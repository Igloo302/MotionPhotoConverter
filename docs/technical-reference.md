# MotionPhotoConverter 技术参考

本文档提供 MotionPhotoConverter 应用中使用的关键技术、API 和实现细节的参考信息。

## 目录

- [核心技术](#核心技术)
- [Motion Photo 格式](#motion-photo-格式)
- [Live Photo 格式](#live-photo-格式)
- [关键 API 参考](#关键-api-参考)
- [文件处理](#文件处理)
- [性能优化](#性能优化)
- [错误处理](#错误处理)

## 核心技术

### SwiftUI

MotionPhotoConverter 使用 SwiftUI 构建用户界面，这是 Apple 的声明式 UI 框架。SwiftUI 提供了以下优势：

- 声明式语法，使 UI 代码更简洁、可读性更高
- 自动适应不同设备和屏幕尺寸
- 内置动画和过渡效果
- 与 Swift 语言紧密集成

主要使用的 SwiftUI 组件包括：

- `View` 协议：所有视图的基础
- `VStack`、`HStack`、`ZStack`：用于布局
- `Button`、`Text`、`Image`：基本 UI 元素
- `@State`、`@Binding`、`@ObservedObject`：状态管理

### AVFoundation

AVFoundation 是用于处理音频和视频的框架，在 MotionPhotoConverter 中主要用于：

- 从 Motion Photo 中提取视频数据
- 创建和处理视频文件
- 视频播放和控制

主要使用的 AVFoundation 类包括：

- `AVAsset`：表示音频或视频资源
- `AVPlayer`：播放音频和视频
- `AVPlayerItem`：管理播放状态和时间
- `AVAssetExportSession`：导出音频和视频资源

### PhotosUI

PhotosUI 框架用于访问用户的照片库，在应用中主要用于：

- 显示照片选择器
- 加载和处理用户选择的照片
- 将创建的 Live Photo 或 GIF 保存到照片库

主要使用的 PhotosUI 类包括：

- `PHPickerViewController`：照片选择器界面
- `PHPickerConfiguration`：配置照片选择器
- `PHAsset`：表示照片库中的资源
- `PHAssetCreationRequest`：创建新的照片库资源

### CoreImage

CoreImage 框架用于图像处理，在应用中主要用于：

- 图像滤镜和效果
- 创建 GIF 动画

主要使用的 CoreImage 类包括：

- `CIImage`：表示图像数据
- `CIFilter`：应用图像滤镜
- `CIContext`：渲染处理后的图像

## Motion Photo 格式

### 格式概述

Motion Photo（动态照片）是一种特殊的图像格式，它将静态图像和短视频片段组合在一个文件中。不同设备厂商实现的 Motion Photo 格式略有不同：

- **Google (Pixel)**：使用 JPEG 格式存储图像，并在文件末尾附加 MP4 视频数据
- **Samsung**：使用类似的方法，但有不同的元数据标记
- **其他厂商**：可能有其他变体

### 文件结构

Motion Photo 文件通常具有以下结构：

1. **JPEG 图像数据**：文件的主要部分，包含静态图像
2. **元数据标记**：指示视频数据的位置和大小
3. **MP4 视频数据**：附加在文件末尾的视频片段

### 解析方法

MotionPhotoConverter 使用以下步骤解析 Motion Photo 文件：

1. 读取文件数据
2. 查找特定的元数据标记，确定视频数据的位置
3. 提取视频数据部分
4. 将视频数据保存为临时 MP4 文件或直接处理

```swift
// 示例代码：解析 Motion Photo 文件
func extractVideoFromMotionPhoto(url: URL) -> URL? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    
    // 查找视频数据的偏移量和大小
    guard let (offset, size) = findVideoDataInfo(in: data) else { return nil }
    
    // 提取视频数据
    let videoData = data.subdata(in: offset..<(offset + size))
    
    // 创建临时文件并保存视频数据
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
    try? videoData.write(to: tempURL)
    
    return tempURL
}
```

## Live Photo 格式

### 格式概述

Live Photo 是 Apple 设备上的一种特殊媒体格式，它将静态图像和短视频片段组合在一起。与 Motion Photo 不同，Live Photo 不是单个文件，而是由两个文件组成：

1. **静态图像文件**：通常是 HEIC 或 JPEG 格式
2. **视频文件**：通常是 MOV 格式

这两个文件通过元数据相互关联，形成一个 Live Photo 资源。

### 创建 Live Photo

MotionPhotoConverter 使用以下步骤创建 Live Photo：

1. 准备静态图像（从 Motion Photo 中提取或用户选择）
2. 准备视频片段（从 Motion Photo 中提取或用户选择）
3. 创建临时文件并写入相应数据
4. 使用 `PHAssetCreationRequest` 将这些文件作为 Live Photo 资源保存到照片库

```swift
// 示例代码：创建 Live Photo
func createLivePhoto(imageURL: URL, videoURL: URL, completion: @escaping (Bool) -> Void) {
    PHPhotoLibrary.shared().performChanges {
        let creationRequest = PHAssetCreationRequest.forAsset()
        
        // 添加图像资源
        let imageOptions = PHAssetResourceCreationOptions()
        creationRequest.addResource(.photo, fileURL: imageURL, options: imageOptions)
        
        // 添加视频资源，并标记为 Live Photo 视频
        let videoOptions = PHAssetResourceCreationOptions()
        videoOptions.shouldMoveFile = true
        creationRequest.addResource(.pairedVideo, fileURL: videoURL, options: videoOptions)
    } completionHandler: { success, error in
        if let error = error {
            print("创建 Live Photo 失败: \(error.localizedDescription)")
        }
        completion(success)
    }
}
```

## 关键 API 参考

### 照片选择器

```swift
// 配置照片选择器
var configuration = PHPickerConfiguration()
configuration.filter = .images  // 仅显示图像
configuration.selectionLimit = 1  // 限制选择一张照片

// 创建并显示照片选择器
let picker = PHPickerViewController(configuration: configuration)
picker.delegate = self
present(picker, animated: true)

// 处理选择结果
func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    
    guard let result = results.first else { return }
    
    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
        if let image = object as? UIImage {
            DispatchQueue.main.async {
                self?.selectedImage = image
            }
        }
    }
}
```

### 视频播放

```swift
// 创建视频播放器
let player = AVPlayer(url: videoURL)
let playerLayer = AVPlayerLayer(player: player)
playerLayer.frame = view.bounds
view.layer.addSublayer(playerLayer)

// 播放控制
player.play()  // 开始播放
player.pause()  // 暂停播放
player.seek(to: CMTime(seconds: 1.5, preferredTimescale: 600))  // 跳转到指定时间

// 监听播放状态
let timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
    let seconds = CMTimeGetSeconds(time)
    self?.updateProgressUI(seconds: seconds)
}
```

### GIF 创建

```swift
// 从视频创建 GIF
func createGIFFromVideo(videoURL: URL, frameCount: Int, loopCount: Int, completion: @escaping (URL?) -> Void) {
    let asset = AVAsset(url: videoURL)
    let duration = asset.duration.seconds
    let frameInterval = duration / Double(frameCount)
    
    // 提取视频帧
    var images: [CGImage] = []
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    
    for i in 0..<frameCount {
        let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            images.append(cgImage)
        }
    }
    
    // 创建 GIF 文件
    let fileProperties: [String: Any] = [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFLoopCount as String: loopCount
        ]
    ]
    
    let frameProperties: [String: Any] = [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFDelayTime as String: frameInterval
        ]
    ]
    
    // 创建临时文件 URL
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("gif")
    
    // 写入 GIF 数据
    if let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, kUTTypeGIF, images.count, nil) {
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        for image in images {
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        }
        
        if CGImageDestinationFinalize(destination) {
            completion(tempURL)
        } else {
            completion(nil)
        }
    } else {
        completion(nil)
    }
}
```

## 文件处理

### 临时文件管理

MotionPhotoConverter 在处理过程中创建多个临时文件，包括：

- 提取的视频文件
- 处理后的图像文件
- 创建的 GIF 文件

这些临时文件需要妥善管理，以避免占用过多存储空间：

```swift
// 创建临时文件 URL
func createTempFileURL(extension: String) -> URL {
    return FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(`extension`)
}

// 删除临时文件
func cleanupTempFiles(urls: [URL]) {
    for url in urls {
        try? FileManager.default.removeItem(at: url)
    }
}
```

### 文件类型检测

检测文件是否为 Motion Photo：

```swift
func isMotionPhoto(url: URL) -> Bool {
    guard let data = try? Data(contentsOf: url) else { return false }
    
    // 检查文件是否包含特定的元数据标记
    // 这里的实现取决于具体的 Motion Photo 格式
    let motionPhotoMarker = Data([0x4D, 0x6F, 0x74, 0x69, 0x6F, 0x6E, 0x50, 0x68, 0x6F, 0x74, 0x6F, 0x5F, 0x44, 0x61, 0x74, 0x61])  // "MotionPhoto_Data"
    
    return data.range(of: motionPhotoMarker) != nil
}
```

## 性能优化

### 异步处理

MotionPhotoConverter 使用异步处理来避免阻塞主线程，提高用户界面响应性：

```swift
// 使用 GCD 进行异步处理
func processMotionPhoto(url: URL, completion: @escaping (Result<ProcessedData, Error>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        // 在后台线程执行耗时操作
        let result = self.extractAndProcessData(url: url)
        
        // 在主线程返回结果
        DispatchQueue.main.async {
            completion(result)
        }
    }
}

// 使用 Swift 并发（iOS 15+）
@available(iOS 15.0, *)
func processMotionPhotoAsync(url: URL) async throws -> ProcessedData {
    // 在异步上下文中执行耗时操作
    return try await withCheckedThrowingContinuation { continuation in
        extractAndProcessData(url: url) { result in
            continuation.resume(with: result)
        }
    }
}
```

### 内存管理

处理大型媒体文件时的内存管理策略：

1. **流式处理**：避免一次性加载整个文件到内存
2. **分块处理**：对大型数据进行分块处理
3. **资源释放**：及时释放不再需要的资源

```swift
// 流式处理大型文件
func processLargeFile(url: URL) {
    guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return }
    defer { try? fileHandle.close() }  // 确保文件句柄被关闭
    
    let chunkSize = 1024 * 1024  // 1MB 块大小
    var offset: UInt64 = 0
    
    while true {
        fileHandle.seek(toFileOffset: offset)
        let data = fileHandle.readData(ofLength: chunkSize)
        
        if data.isEmpty { break }  // 文件结束
        
        // 处理当前数据块
        processDataChunk(data)
        
        offset += UInt64(data.count)
    }
}
```

## 错误处理

### 错误类型

MotionPhotoConverter 定义了以下错误类型：

```swift
enum MotionPhotoError: Error {
    case fileNotFound
    case invalidFileFormat
    case videoExtractionFailed
    case processingFailed(String)
    case exportFailed(String)
    case saveFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound:
            return "找不到文件"
        case .invalidFileFormat:
            return "无效的文件格式，请确保选择了 Motion Photo"
        case .videoExtractionFailed:
            return "无法从 Motion Photo 中提取视频"
        case .processingFailed(let reason):
            return "处理失败: \(reason)"
        case .exportFailed(let reason):
            return "导出失败: \(reason)"
        case .saveFailed(let reason):
            return "保存失败: \(reason)"
        }
    }
}
```

### 错误处理策略

应用使用以下策略处理错误：

1. **预防性检查**：在操作前验证输入和条件
2. **优雅失败**：当错误发生时提供有意义的反馈
3. **恢复机制**：尽可能从错误中恢复
4. **用户反馈**：向用户显示友好的错误消息

```swift
// 使用 Result 类型处理错误
func processFile(url: URL, completion: @escaping (Result<ProcessedData, MotionPhotoError>) -> Void) {
    // 预防性检查
    guard FileManager.default.fileExists(atPath: url.path) else {
        completion(.failure(.fileNotFound))
        return
    }
    
    guard isMotionPhoto(url: url) else {
        completion(.failure(.invalidFileFormat))
        return
    }
    
    // 处理逻辑
    do {
        let processedData = try extractAndProcess(url: url)
        completion(.success(processedData))
    } catch let error as MotionPhotoError {
        completion(.failure(error))
    } catch {
        completion(.failure(.processingFailed(error.localizedDescription)))
    }
}

// 向用户显示错误
func showError(_ error: MotionPhotoError) {
    let alertController = UIAlertController(
        title: "处理错误",
        message: error.localizedDescription,
        preferredStyle: .alert
    )
    
    alertController.addAction(UIAlertAction(title: "确定", style: .default))
    
    // 根据错误类型添加额外操作
    switch error {
    case .invalidFileFormat:
        alertController.addAction(UIAlertAction(title: "选择其他照片", style: .default) { [weak self] _ in
            self?.showPhotoPicker()
        })
    default:
        break
    }
    
    present(alertController, animated: true)
}
```

## 结语

本技术参考文档提供了 MotionPhotoConverter 应用中使用的关键技术和实现细节。开发者可以参考这些信息来理解应用的工作原理，或者在自己的项目中实现类似功能。

如需更多信息，请参考 Apple 官方文档：

- [SwiftUI 文档](https://developer.apple.com/documentation/swiftui)
- [AVFoundation 文档](https://developer.apple.com/documentation/avfoundation)
- [PhotosUI 文档](https://developer.apple.com/documentation/photokit)
- [CoreImage 文档](https://developer.apple.com/documentation/coreimage)