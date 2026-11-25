# Motion2Live 技术架构（真相源）

## 1. 核心目标
Motion2Live 是一款纯离线原生 iOS / iPadOS（`iOS 16.0+`）应用，用于解析 Android / 第三方厂商动态照片（Motion Photo）中的静态图像与内嵌视频流，并导出为系统 **Live Photo**、独立视频（MP4/MOV）或 **GIF**，同时支持批量转换、实验室（`LabView`）“图+视频”双向自定义合成（Live Photo / Motion Photo `.jpg`）以及 **Apple Live Photo → 7 品牌 Motion Photo（`.jpg`）逆向转换**。

## 2. 目录与模块划分
- **`Motion2Live/`**（主 App Target）
  - **界面与状态（MVVM）**：`Motion2LiveApp.swift`、`HomeView.swift`、`HomeViewModel.swift`、`BatchConvertView.swift`、`LabView.swift`、`Views/MotionPhotoView.swift`、`Views/LiveToMotionView.swift`、`Views/Components/`（`PhotoPicker`、`PlayerView`、`KeyframePickerSheet`、`SupportedBrandsView`、`MotionPhotoExportComponents`）。
  - **设计系统**：`DesignSystem/ObsidianTheme.swift`（自适应深浅色 Token、`AppHaptics`、iPhone Duo 铰链抽象 `DuoHingeStatus` / `HingeStateSnapshot` / `observeDeviceHinge(_:)` 与多设备断点 `AdaptiveLayoutMetrics` / `DuoLayoutMode`）。
  - **解析与编码引擎**：`Utils/XMPParser.swift`（XMP 提取解析与 `AppLogger`）、`Models/MotionPhotoProcessor.swift`（`ISOBMFFHelper`、`MotionPhotoProbeContext` 与 7 类处理器：Xiaomi / Samsung / Pixel / Huawei / OPPO / vivo / Universal）、`Models/MotionPhotoEncoder.swift`（7 品牌逆向封装、HEIC→JPEG 元数据保留、Passthrough MP4 混流与输出自校验）。
  - **媒体服务与缓存**：`Services/LivePhotoExtractor.swift`（`PHAssetResource` 与无读权限 `PHLivePhoto` 双路径只读抽取）、`Services/MediaExportService.swift`（Live Photo / MOV / GIF / 封面帧 / 逆向 Motion Photo `.jpg` 导出、文件时间戳同步与 `NSTemporaryDirectory` 守卫）、`Services/RecentConversionStore.swift`（最近 1–3 张缩略图本地缓存）。
  - **本地化与隐私**：`Localizable.swift`（7 语言映射）、`*.lproj/InfoPlist.strings`、`Info.plist`、`PrivacyInfo.xcprivacy`。
- **`Motion2LiveTests/`**：基于 Bundle 样图及可选 `samples/local/manifest.json` 的解析与导出单元测试。
- **`Motion2LiveUITests/`**：冷启动、首屏控件可用性与启动性能 UI 测试。

## 3. 端到端核心数据流
1. **单张 / 批量选图**：`HomeView` / `HomeViewModel` 通过 `PHPickerViewController`（`PhotoPicker`）获取本地临时文件 URL，不上传云端。
2. **元数据与视频流切分**：`XMPParser.extractAndParse(from:)` 提取头/尾部 XMP；`MotionPhotoProcessorFactory.getProcessor(for:data:)` 基于共享 `MotionPhotoProbeContext`（EXIF Make/Model、MP4 `ftyp` 偏移、Samsung SEF 标记）匹配品牌处理器或回退至 `UniversalMotionPhotoProcessor`，输出 `MotionPhotoData`。
3. **预览与关键帧调整**：`MotionPhotoView` 将视频写入临时文件交由 `AVPlayer` 预览；通过 `AnyLayout` 单一视图树在全屏叠层、横屏左右分栏及半开桌面姿态间切换，保证开合屏不重建 `PlayerView`、不误触发 `.onDisappear` 清理临时文件；`KeyframePickerSheet` 通过 `MediaExportService.extractCoverFrameData` 抽取保留原图 EXIF/TIFF/GPS 的封面帧。
4. **封装与导出**：
   - **Live Photo**：`MediaExportService.prepareLivePhotoFiles` 生成统一 `assetIdentifier`，写入静态图 Apple Maker `"17"` 及 MOV QuickTime `content.identifier` / `still-image-time`，再通过 `PHPhotoLibrary` `.addOnly` 写入系统相册。
   - **Video / GIF**：`exportVideo` 直接保存视频；`createGIFFile` / `exportGIF` 按 `frameCount` 与 `maxDimension` 采样生成 GIF 并写入相册。
   - **逆向与双向 Motion Photo（Lab）**：`LivePhotoExtractor` 只读抽取 Live Photo 静态图与配对 `.mov` 至 `NSTemporaryDirectory`，`LabView`（`CustomLivePhotoView`）同步支持“图+视频”切换导出 `Live Photo` 或 `Motion Photo` 并优先继承静图 EXIF 拍摄时间；`MotionPhotoEncoder` 保留 EXIF/Orientation 将非 JPEG 转为 `0.95` JPEG 并剥离冲突旧 XMP，提取 `still-image-time`（普通视频回退中点）后以 `AVAssetExportPresetPassthrough` 无损混流为 `.mp4`（不兼容时静默回退重编码），按目标品牌（Pixel / Xiaomi / Samsung SEF / Huawei / OPPO / vivo / Universal）拼装容器并自校验；`MediaExportService.exportMotionPhoto` 写出 `.jpg` 后同步文件创建与修改时间戳，并经 `MotionPhotoExportCoordinator` 通过系统分享面板或「文件」App 导出原始字节。
5. **收尾与缓存**：`defer` 及 `removeIfInTemporaryDirectory` 清理临时媒体；`RecentConversionStore` 将降采样缩略图写入 `Caches/RecentConversions/index.json`（上限 3 条）。

## 4. 关键数据模型与 Schema

```swift
// Motion2Live/Models/MotionPhotoProcessor.swift
enum MotionPhotoBrand: String, CaseIterable, Sendable {
    case xiaomi, pixel, samsung, huawei, oppo, vivo, universal, unknown
}

struct MotionPhotoData: Sendable {
    let imageData: Data
    let videoData: Data
    let stillImageTime: Int
    let brand: MotionPhotoBrand
    let videoOffset: Int?
    let presentationTimestamp: Double?
}

// Motion2Live/Services/LivePhotoExtractor.swift
struct ExtractedLivePhoto: Sendable {
    let imageURL: URL
    let videoURL: URL
    let creationDate: Date?
}

// Motion2Live/Services/MediaExportService.swift
struct PreparedLivePhoto {
    let assetIdentifier: String
    let imageURL: URL
    let videoURL: URL
}

// Motion2Live/Services/RecentConversionStore.swift
struct RecentConversionEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let durationSeconds: Double?
    let createdAt: Date
}

// Motion2Live/DesignSystem/ObsidianTheme.swift
enum DuoHingeStatus: Equatable, Sendable {
    case unavailable, closed, partiallyOpen, fullyOpen
}

enum DuoLayoutMode: Equatable, Sendable {
    case compactVertical, compactShortLandscape, unfoldedWideSplit, hingeFlexSplit
}

struct HingeStateSnapshot: Equatable, Sendable {
    let status: DuoHingeStatus
    let angleDegrees: Double
}
```

## 5. 外部依赖与端口约定
- **外部依赖**：零第三方库与远程 API，仅依赖 Apple 原生框架（`SwiftUI`、`AVFoundation`、`AVKit`、`Photos`、`PhotosUI`、`ImageIO`、`UniformTypeIdentifiers`、`OSLog`）。
- **网络与端口**：纯离线应用，**无后端服务、无监听端口、无网络请求**。
- **系统边界与隐私清单**：
  - 临时媒体目录：`NSTemporaryDirectory`（用完即删）。
  - 本地缓存：`Caches/RecentConversions/` 与 `UserDefaults`（`homeShowRecentConversions`）。
  - Apple 隐私声明（`PrivacyInfo.xcprivacy`）：`NSPrivacyTracking = false`，仅声明 `CA92.1`（UserDefaults）与 `C617.1`（文件时间戳）。
