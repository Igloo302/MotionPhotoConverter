# Spec: macOS 适配（Mac Catalyst + Mac App Store）

- **日期**: 2026-11-26
- **状态**: Proposed (待确认)
- **目标路线**: Mac Catalyst (`SUPPORTS_MACCATALYST = YES`)，仅面向 Mac App Store 发布
- **设计门禁**: L1（复用 `ObsidianTheme.swift` 既有 Token 与 `AdaptiveLayoutMetrics` 自适应布局，补充 macOS 拖拽悬停态、文件导入/导出与菜单快捷键，免独立 Figma 稿）

---

## 1. 背景与目标

当前 `Motion2Live` 仅配置为 iOS / iPadOS 目标（`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`、`SUPPORTS_MACCATALYST = NO`），未启用 Mac Catalyst，也未配置 Mac App Store 所需的 App Sandbox 权限与 macOS 桌面交互。

本任务目标是在不破坏现有 iOS/iPadOS 体验的前提下，通过 **Mac Catalyst** 完整适配 macOS 安装与使用，面向 **Mac App Store** 发布，并支持：
1. 从 **Finder 选择文件**（单张/多张）以及将转换结果 **保存到本地目录**。
2. **拖拽（Drag & Drop）** 图片/视频到主窗口或实验室直接解析/合成，以及通过 Finder「打开方式」/ 拖入 Dock 图标打开。
3. 保留系统 **「照片」App 图库读写**（Live Photo 导入与导出）。
4. 同步适配 **macOS 系统分享扩展（`Motion2LiveShareExtension`）**。

---

## 2. 工程与 Mac App Store 合规配置

### 2.1 Xcode 工程配置 (`Motion2Live.xcodeproj/project.pbxproj`)
对 `Motion2Live`、`Motion2LiveShareExtension`、`Motion2LiveTests` 三个 Target 的 `Debug` 与 `Release` 配置进行如下调整：
- **主 App (`Motion2Live`)**：
  - `SUPPORTS_MACCATALYST = YES;`
  - `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;`
  - `TARGETED_DEVICE_FAMILY = "1,2,6";`
  - `DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = NO;`（保持统一 Bundle ID `com.igloo.MotionPhotoConverter`，支持 Mac App Store 通用购买与统一身份）
  - 保留 `MACOSX_DEPLOYMENT_TARGET = 14.4;` 与 `LD_RUNPATH_SEARCH_PATHS[sdk=macosx*] = "@executable_path/../Frameworks";`
- **分享扩展 (`Motion2LiveShareExtension`)**：
  - `SUPPORTS_MACCATALYST = YES;`
  - `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;`
  - `TARGETED_DEVICE_FAMILY = "1,2,6";`
  - `CODE_SIGN_ENTITLEMENTS = Motion2LiveShareExtension/Motion2LiveShareExtension.entitlements;`
  - `LD_RUNPATH_SEARCH_PATHS[sdk=macosx*]` 设为 `("$(inherited)", "@executable_path/../Frameworks", "@executable_path/../../../../Frameworks")`
- **单元测试 (`Motion2LiveTests`)**：
  - `SUPPORTS_MACCATALYST = YES;`、`TARGETED_DEVICE_FAMILY = "1,2,6";`（支持在 `platform=macOS,variant=Mac Catalyst` 下直接运行单元测试）

### 2.2 App Sandbox 与 Entitlements
- **修改 [Motion2Live/Motion2Live.entitlements](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/Motion2Live.entitlements)**：
  ```xml
  <dict>
      <key>com.apple.security.app-sandbox</key>
      <true/>
      <key>com.apple.security.files.user-selected.read-write</key>
      <true/>
      <key>com.apple.security.assets.pictures.read-write</key>
      <true/>
  </dict>
  ```
- **新增 `Motion2LiveShareExtension/Motion2LiveShareExtension.entitlements`**：
  ```xml
  <dict>
      <key>com.apple.security.app-sandbox</key>
      <true/>
      <key>com.apple.security.assets.pictures.read-write</key>
      <true/>
  </dict>
  ```

### 2.3 `Info.plist` 与 `AppIcon`
- **修改 [Motion2Live/Info.plist](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/Info.plist)**：
  - 新增 `ITSAppUsesNonExemptEncryption = NO`。
  - 新增 `CFBundleDocumentTypes`（声明支持 `public.jpeg`、`public.heic`、`public.avif`、`public.image` 只读打开，使 Finder「打开方式」与拖入 Dock 图标生效）。
- **补齐 [Motion2Live/Assets.xcassets/AppIcon.appiconset/Contents.json](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/Assets.xcassets/AppIcon.appiconset/Contents.json)**：
  - 从现有 `AppIcon.png`（1024×1024）使用 `sips` 生成 macOS 所需的 `16x16`、`32x32`、`128x128`、`256x256`、`512x512`（1x 与 2x）PNG 文件并填入 `Contents.json` 对应槽位，避免 Mac App Store Archive 图标校验失败。

---

## 3. Mac Catalyst 平台兼容性适配

| 模块 / 文件 | 现状问题 | 适配方案 |
| :--- | :--- | :--- |
| [ObsidianTheme.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/DesignSystem/ObsidianTheme.swift) | `AppHaptics` 直接调用 `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` | `#if targetEnvironment(macCatalyst)` 下设为 no-op |
| [BatchConvertView.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/BatchConvertView.swift) | 直接调用 `UINotificationFeedbackGenerator()` 与 `UIApplication.shared.isIdleTimerDisabled` | 触感改为统一调用 `AppHaptics.success()` / `warning()`；`isIdleTimerDisabled` 加 `#if !targetEnvironment(macCatalyst)` |
| [MotionPhotoView.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/Views/MotionPhotoView.swift) | 相册权限拒绝时「前往设置」固定使用 `UIApplication.openSettingsURLString` | `#if targetEnvironment(macCatalyst)` 下打开 `x-apple.systempreferences:com.apple.preference.security?Privacy_Photos` |
| [MotionPhotoExportComponents.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/Views/Components/MotionPhotoExportComponents.swift) | `UIActivityViewController` 在 Catalyst 下若无 popover anchor 可能出现布局异常 | 校验 `.sheet` 包裹在 Catalyst 下的表现，必要时为 `popoverPresentationController` 补充 `sourceView` 兜底 |
| [Motion2LiveApp.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-%E4%B8%AA%E4%BA%BA/Projects/Motion2Live/Motion2Live/Motion2LiveApp.swift) | 缺少 macOS 窗口默认尺寸、菜单栏命令及外部文件打开入口 | 配置 `.defaultSize(width: 960, height: 680)`、`.onOpenURL` 及菜单栏快捷键（`Cmd+O`、`Shift+Cmd+O`、`Cmd+L`） |

---

## 4. macOS 核心交互与数据流设计

### 4.1 安全域文件导入辅助（`LocalMediaImportHelper`）
遵循 `AGENTS.md` 媒体安全红线（严禁回写源资源、临时文件统一落盘 `NSTemporaryDirectory`）：
- 新增 `Motion2Live/Services/LocalMediaImportHelper.swift`（或集成至 `MediaExportService`）：
  1. 接收来自 `.fileImporter`、`.onDrop` 或 `.onOpenURL` 的外部 `URL`。
  2. 调用 `url.startAccessingSecurityScopedResource()`，并在 `defer` 中释放。
  3. 只读拷贝至 `FileManager.default.temporaryDirectory` 下的唯一文件名（保留原始扩展名），供 `MotionPhotoProcessorFactory` / `LabView` 只读解析，用完由现有 `MediaExportService.removeIfInTemporaryDirectory` 清理。
  4. 针对多文件批量导入，复用 `PhotoPicker` 的有效 Motion Photo 校验逻辑，过滤非动态照片并统计 `ignoredCount`。

### 4.2 Finder 选图、拖拽（Drag & Drop）与四态设计
- **`HomeView`**：
  - **入口**：保留主 CTA「选择动态照片」（系统照片库）；在更多菜单及主操作区旁（Mac Catalyst 下可显式展示辅助胶囊按钮或通过 `Cmd+O`）提供「从文件选择」（`.fileImporter(allowedContentTypes: [.image], allowsMultipleSelection: true)`）。
  - **拖拽（`.onDrop(of: [.fileURL, .image])`）**：
    - **拖拽悬停态**：`isDropTargeted == true` 时显示 `AppTheme.accent` 虚线圆角边框与半透明提示浮层（释放即可导入解析）。
    - **Loading 态**：复用 `analyzingOverlay` 显示解析进度。
    - **Empty / Error 态**：若拖入或选中的图片非 Motion Photo，弹出本地化 `Alert` 提示并清理临时文件。
- **`LabView`（合成实验室）**：
  - 图片槽位与视频槽位分别增加「从文件选择」（`.fileImporter`）与 `.onDrop` 拖拽支持（图片支持 `.image`，视频支持 `.movie` / `.mpeg4Movie` / `.quickTimeMovie`）。

### 4.3 本地目录导出（Finder 保存）
- **`MotionPhotoView`（单张详情页）**：
  - 在现有导出到「照片」图库（Live Photo / 视频 / GIF）之外，增加「导出到本地文件」菜单/按钮：通过 `.fileExporter` 将生成的 MP4、GIF 或封面帧 JPEG 保存到用户选定的 Finder 目录，导出后立即清理 `NSTemporaryDirectory` 中间文件。
- **`BatchConvertView`（批量转换页）**：
  - 当选择 **视频（MP4）** 或 **GIF** 格式时，增加「导出方式」切换：**保存到「照片」图库** vs **保存到本地文件夹**（使用 `.fileImporter(allowedContentTypes: [.folder])` 获取安全域目录权限，逐个写入后释放）。

### 4.4 本地化文案
- 遵循 `Motion2Live/AGENTS.md` 约束，所有新增 UI 文案键（如「从文件选择」、「拖放照片到此处」、「导出到本地」、「导出到文件夹」等）须同步补全 `Motion2Live/Localizable.swift` 全部 **7 种语言**（`en`、`zh`、`fr`、`de`、`es`、`ja`、`ko`）。

### 4.5 Share Extension (`Motion2LiveShareExtension`)
- 验证 `ShareAttachmentLoader.swift` 在 Mac Catalyst 下通过 Finder 右键「共享 → Motion2Live」接收 `public.file-url` / `public.image` 时，正确处理安全作用域并流式拷贝至扩展独立 `temporaryDirectory`，完成解析与导出到系统「照片」图库。

---

## 5. 验证计划

1. **iOS 回归编译与单元测试**：
   ```bash
   xcodebuild build -project Motion2Live.xcodeproj -scheme Motion2Live -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO
   DESTINATION=$(xcrun simctl list devices available iPhone | grep -m1 -oE '[0-9A-F-]{36}')
   xcodebuild test -project Motion2Live.xcodeproj -scheme Motion2Live -destination "platform=iOS Simulator,id=${DESTINATION}" -only-testing:Motion2LiveTests CODE_SIGNING_ALLOWED=NO
   ```
2. **Mac Catalyst 编译与单元测试**：
   ```bash
   xcodebuild build -project Motion2Live.xcodeproj -scheme Motion2Live -destination "platform=macOS,variant=Mac Catalyst" CODE_SIGNING_ALLOWED=NO
   xcodebuild test -project Motion2Live.xcodeproj -scheme Motion2Live -destination "platform=macOS,variant=Mac Catalyst" -only-testing:Motion2LiveTests CODE_SIGNING_ALLOWED=NO
   ```
3. **Mac App Store 合规与本机冒烟测试**：
   - 检查 `Motion2Live.app` 与 `Contents/PlugIns/Motion2LiveShareExtension.appex` 的 Entitlements（`codesign -d --entitlements :-`），确认 `com.apple.security.app-sandbox`、`files.user-selected.read-write`、`assets.pictures.read-write` 完整。
   - 本机启动 macOS 版应用，实测：Finder 选图（单张/批量）、窗口拖拽、Finder「打开方式」、系统「照片」图库读写、导出到本地文件夹、Lab 拖拽合成、Finder 右键 Share Extension。
