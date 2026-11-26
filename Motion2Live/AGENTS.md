# Motion2Live/AGENTS.md — iOS App 主模块规范

## 1. 技术栈与职责边界
- **技术栈**：Swift 5+、SwiftUI、AVFoundation、Photos / PhotosUI、ImageIO、UniformTypeIdentifiers、OSLog（`iOS 16.0+` 部署目标，按需通过 `#available` 适配新特性）。
- **目录与职责**：
  - 入口与页面：`Motion2LiveApp.swift`、`HomeView.swift`、`HomeViewModel.swift`、`BatchConvertView.swift`、`LabView.swift`、`Views/MotionPhotoView.swift`、`Views/Components/`。
  - 设计系统：`DesignSystem/ObsidianTheme.swift`（深浅色 Token 与 `AdaptiveLayoutMetrics` 自适应断点）。
  - 核心解析管线：`Utils/XMPParser.swift`（XMP 提取解析与 `AppLogger`）、`Models/MotionPhotoProcessor.swift`（`ISOBMFFHelper` 与多品牌处理器工厂：Xiaomi / Samsung / Pixel / Huawei / OPPO / vivo / Universal）。
  - 媒体服务与缓存：`Services/MediaExportService.swift`（Live Photo / MOV / GIF / 封面帧导出与 `PHPhotoLibrary` `.addOnly` 写入）、`Services/RecentConversionStore.swift`（最近 1–3 张缩略图本地缓存）。
  - 本地化：`Localizable.swift` 与 7 语种 `*.lproj/InfoPlist.strings`。
- **职责红线**：UI 层不得直接解析二进制媒体流；导出与临时文件清理统一收口至 `MediaExportService`。

## 2. 确定性验证命令
本模块未配置 SwiftLint / SwiftFormat，以 Xcode 编译零警告与单元/UI 测试为准：
- **编译与静态类型检查**：
  ```bash
  xcodebuild build -project Motion2Live.xcodeproj -scheme Motion2Live -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO
  ```
- **运行单元测试验证核心逻辑**：
  ```bash
  DESTINATION=$(xcrun simctl list devices available iPhone | grep -m1 -oE '[0-9A-F-]{36}')
  xcodebuild test -project Motion2Live.xcodeproj -scheme Motion2Live -destination "platform=iOS Simulator,id=${DESTINATION}" -only-testing:Motion2LiveTests CODE_SIGNING_ALLOWED=NO
  ```
- **约束**：严禁通过放宽断言、屏蔽警告或删改原有测试来强行通过验证；若改动涉及本地化文案键，须同步核对 `Localizable.swift` 全部 7 种语言分支。

## 3. 资源与沙盒隔离要求
- **临时文件**：所有中间 `.mp4` / `.mov` / `.jpg` / `.gif` 必须写入 `FileManager.default.temporaryDirectory`，并在操作完成或 `defer` / `onDisappear` 中经 `MediaExportService.removeIfInTemporaryDirectory` 清理。
- **持久化状态**：仅限 `UserDefaults` 偏好开关与 `Caches/RecentConversions/`（最多 3 条缩略图）；测试或预览不得写入真实相册或覆盖用户缓存目录。
