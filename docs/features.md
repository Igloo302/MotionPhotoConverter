# Motion2Live 功能说明

本文档详细介绍 Motion2Live 应用的各项功能及其使用方法。

## 核心功能

### 1. 提取视频

#### 功能描述

用户可以从 Motion Photo 中提取视频，并将其保存为独立的视频文件。应用会自动识别 Motion Photo 并提取其中的视频数据。

#### 使用方法

1. 在主界面点击"选择动态照片"按钮
2. 从相册中选择一张 Motion Photo
3. 在照片预览界面点击"导出"按钮
4. 从弹出的菜单中选择"视频"
5. 等待处理完成后，视频将自动保存到相册中

#### 技术实现

应用通过解析 Motion Photo 的 XMP 元数据，获取视频数据的偏移量和时间戳信息，然后从文件中提取视频数据并保存为独立的 MP4 文件。

```swift
func extractVideoFromMotionPhoto(url: URL) async {
    // 读取文件数据
    guard let data = try? Data(contentsOf: url) else { return }
    
    // 提取和解析 XMP 数据
    if let xmpData = extractXMPData(from: data),
       let xmpInfo = parseXMP(data: xmpData),
       let offset = xmpInfo["GCamera:MicroVideoOffset"],
       let offsetValue = Int(offset) {
        
        // 提取视频数据
        self.videoData = data.suffix(offsetValue)
        
        // 处理视频数据...
    }
}
```

### 2. 导出为 Live Photo

#### 功能描述

用户可以将 Motion Photo 转换为 iOS 设备原生支持的 Live Photo 格式，并将其保存到相册中。Live Photo 是一种包含短视频的照片格式，常见于 iOS 设备。

#### 使用方法

1. 在主界面点击"选择动态照片"按钮
2. 从相册中选择一张 Motion Photo
3. 在照片预览界面点击"导出"按钮
4. 从弹出的菜单中选择"实况照片"
5. 等待处理完成后，Live Photo 将自动保存到相册中

#### 技术实现

应用将 Motion Photo 中的静态图像部分保存为 JPEG 文件，将视频部分转换为 MOV 格式，并添加必要的元数据，然后使用 PhotosUI 框架将它们作为 Live Photo 保存到相册中。

```swift
func exportAsLivePhoto() {
    // 从原始数据中剔除视频数据，获取纯图像数据
    let pureImageData = imageData.prefix(imageData.count - videoData.count)
    
    // 将纯图像数据写入 JPEG 文件
    try pureImageData.write(to: jpegURL)
    
    // 将视频数据写入 MP4 文件，然后转换为 MOV 格式
    try videoData.write(to: mp4URL)
    let asset = AVAsset(url: mp4URL)
    let exportResult = try await convertVideoToMOV(asset: asset, outputURL: movURL)
    
    // 保存为 Live Photo
    saveLivePhoto(imageURL: jpegURL, videoURL: exportResult.outputURL)
}
```

### 3. 导出为 GIF

#### 功能描述

用户可以将 Motion Photo 中的视频部分导出为 GIF 动图，并将其保存到相册中。GIF 动图是一种广泛使用的动画图片格式，适用于社交媒体分享。

#### 使用方法

1. 在主界面点击"选择动态照片"按钮
2. 从相册中选择一张 Motion Photo
3. 在照片预览界面点击"导出"按钮
4. 从弹出的菜单中选择"GIF"
5. 等待处理完成后，GIF 将自动保存到相册中

#### 技术实现

应用使用 AVFoundation 框架从视频中提取帧，然后使用 ImageIO 框架将这些帧组合成 GIF 动图。

### 4. 照片选择器

#### 功能描述

应用内置了照片选择器，用户可以从相册中选择 Motion Photo 进行处理。照片选择器会自动过滤非 Motion Photo，并提示用户选择有效的 Motion Photo。

#### 使用方法

1. 在主界面点击"选择动态照片"按钮
2. 从相册中选择照片
3. 如果选择的不是 Motion Photo，应用会显示提示信息

#### 技术实现

应用使用 PhotosUI 框架实现照片选择功能，并通过检查照片的元数据判断是否为 Motion Photo。

```swift
struct PhotoPicker: UIViewControllerRepresentable {
    var onImagePicked: (URL, Bool) -> Void
    var onNonMotionPhotoSelected: () -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    // 实现委托方法，检查选择的照片是否为 Motion Photo
}
```

### 5. 视频播放

#### 功能描述

用户可以在应用中播放 Motion Photo 中的视频部分。应用提供了视频播放控件，用户可以通过手势控制视频的播放和暂停。

#### 使用方法

1. 在照片预览界面，按住屏幕开始播放视频
2. 松开手指停止播放

#### 技术实现

应用使用 AVKit 框架实现视频播放功能，并通过 SwiftUI 的手势识别控制播放状态。

```swift
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in startVideoPlayback() }
        .onEnded { _ in stopVideoPlayback() }
)
```

### 6. 导出菜单

#### 功能描述

应用提供了导出菜单，用户可以选择将 Motion Photo 导出为视频、Live Photo 或 GIF。导出过程简单直观，用户可以轻松完成转换和保存操作。

#### 使用方法

1. 在照片预览界面点击"导出"按钮
2. 从弹出的菜单中选择所需的导出格式
3. 等待处理完成后，文件将自动保存到相册中

#### 技术实现

应用使用 SwiftUI 的 ActionSheet 组件实现导出菜单。

```swift
.actionSheet(isPresented: $isExportMenuPresented) {
    ActionSheet(title: Text(Localizable.string(.export)), buttons: [
        .default(Text(Localizable.string(.livePhoto))) { exportAsLivePhoto() },
        .default(Text(Localizable.string(.gif))) { exportAsGIF() },
        .default(Text(Localizable.string(.video))) { exportVideo() },
        .cancel(Text(Localizable.string(.cancel)))
    ])
}
```

## 实验室功能

### 1. 自定义 Live Photo

#### 功能描述

用户可以选择任意静态图像和视频，将它们组合成自定义的 Live Photo。这一功能允许用户创建更加个性化的 Live Photo，不受原始 Motion Photo 的限制。

#### 使用方法

1. 在主界面点击右上角的菜单按钮
2. 选择"实验室"
3. 点击"自定义实况照片"
4. 选择一张静态图像和一段视频
5. 点击"创建实况照片"按钮
6. 等待处理完成后，自定义 Live Photo 将自动保存到相册中

#### 技术实现

应用使用与导出 Live Photo 类似的技术，但允许用户自由选择图像和视频源。

```swift
func createLivePhoto() {
    guard let image = selectedImage, let videoURL = selectedVideo else { return }
    
    isProcessing = true
    
    LivePhotoCreator.create(from: image, videoURL: videoURL) { result in
        DispatchQueue.main.async {
            isProcessing = false
            switch result {
            case .success:
                alertMessage = Localizable.string(.livePhotoSaved)
                showAlert = true
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
```

## 多语言支持

### 功能描述

Motion2Live 支持多种语言，包括英语、中文、法语、德语、西班牙语、日语和韩语。应用会自动根据设备的语言设置选择相应的语言。

### 技术实现

应用使用自定义的本地化系统，通过 `Localizable` 枚举和 `Language` 枚举实现多语言支持。

```swift
enum Language: String {
    case english = "en"
    case chinese = "zh"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case japanese = "ja"
    case korean = "ko"
    
    static var current: Language {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))
        return Language(rawValue: languageCode) ?? .english
    }
}

struct Localizable {
    static func string(_ key: LocalizableKey) -> String {
        switch Language.current {
        case .english:
            return key.english
        case .chinese:
            return key.chinese
        // 其他语言...
        }
    }
}
```

## 总结

Motion2Live 提供了一系列功能，使用户能够轻松地处理和转换 Motion Photo。通过直观的用户界面和高效的处理算法，应用为用户提供了良好的使用体验。未来版本将继续优化现有功能，并添加更多创新功能，以满足用户不断变化的需求。