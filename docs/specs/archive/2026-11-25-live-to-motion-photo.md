# Spec: Lab 实验性逆向编码（Live Photo & 图+视频 → 多品牌 Motion Photo）

- **日期**: 2026-11-25
- **状态**: Approved（已锁定范围与决策，待 Worktree 实施）
- **目标分支**: `feat/live-to-motion-photo`

## 1. 背景与目标

Motion2Live 当前支持将 Android / 多品牌 Motion Photo 正向解析并导出为 Apple Live Photo / Video / GIF。本需求在 **实验室（`LabView`）** 内以实验性功能形式打通两条逆向/双向导出链路，不改动首页（`HomeView`）与批量页（`BatchConvertView`）主流程：

1. **Live Photo → 多品牌 Motion Photo（新建 `LiveToMotionView`）**：读取系统 Apple Live Photo，无损封装导出为单文件混合 `.jpg`。
2. **Lab 图 + 视频双向导出打通（升级 `CustomLivePhotoView`）**：在既有「图片 + 视频 → Apple Live Photo」基础上新增「导出为多品牌 Motion Photo (.jpg)」输出目标，与路径 1 共用统一编码引擎与导出交互组件。

## 2. 已确认的产品决策

1. **功能定位**：暂归属 `LabView` 实验室功能，暂不作为首页正式主流程入口。
2. **品牌覆盖**：覆盖 `MotionPhotoBrand` 已支持的全部 7 类品牌（`.pixel`、`.xiaomi`、`samsung`、`.huawei`、`.oppo`、`.vivo`、`.universal`）。
3. **视频流策略**：默认采用 `AVAssetExportPresetPassthrough` 无损重混流，界面不提供兼容模式（H.264）开关；仅在极少数轨道不兼容 `.mp4` 容器时由底层静默回退 `AVAssetExportPresetHighestQuality`。
4. **导出介质**：通过系统分享面板（`UIActivityViewController`）与「文件」App（`.fileExporter`）导出原始 `.jpg` 字节，不默认写回 iOS 相册，并在界面提供简洁说明（避免相册转发重压缩导致 MP4 流丢失）。

## 3. 安全红线与约束（对齐 `AGENTS.md`）

- **纯离线零第三方依赖**：仅使用 Apple 原生框架（`Photos`、`PhotosUI`、`ImageIO`、`AVFoundation`、`UniformTypeIdentifiers`、`SwiftUI`）。
- **只读源资源与临时目录守卫**：严格只读系统相册资源；拆包、混流与导出文件仅落盘 `NSTemporaryDirectory`，结束后经 `MediaExportService.removeIfInTemporaryDirectory` 清理。
- **隐私清单合规**：不增加网络请求、不新增 `UserDefaults` Key 或隐私权限；改动前后核对 `Motion2Live/PrivacyInfo.xcprivacy` 与 `Info.plist`。
- **最低系统版本**：`iOS 16.0+`。

## 4. 品牌封装规范与闭环兼容性矩阵

对齐 `MotionPhotoProcessorFactory` 匹配顺序（`Xiaomi → Samsung → Pixel → Huawei → Oppo → Vivo → Universal`）：

| 品牌 | 二进制容器结构 | 注入 JPEG `APP1` XMP 核心字段 | 校验重点 |
| :--- | :--- | :--- | :--- |
| `pixel` | `[JPEG] + [MP4]` | `GCamera:MotionPhoto="1"`, `GCamera:MotionPhotoVersion="1"`, `GCamera:MotionPhotoPresentationTimestampUs`, `Container:Directory` (`Primary` + `MotionPhoto`) | `PixelMotionPhotoProcessor` 命中且 `Item:Length == mp4.count` |
| `xiaomi` | `[JPEG] + [MP4]` | `GCamera:MicroVideo="1"`, `GCamera:MicroVideoVersion="1"`, `GCamera:MicroVideoOffset`, `GCamera:MicroVideoPresentationTimestampUs`, `MiCamera:XMPMeta` | 清理三方 EXIF Make；`XiaomiMotionPhotoProcessor` 命中 |
| `samsung` | `[JPEG] + "MotionPhoto_Data" + [MP4] + [SEF Trailer]` | `GCamera:MotionPhoto="1"`, `Container:Directory` (`Item:Padding="138"`, `Item:Length=<mp4+sef>`) + `MotionPhoto_Versionmpv3` + `SEFH/SEFT` | `SamsungMotionPhotoProcessor` 剥离 SEF 后还原纯净 MP4 |
| `huawei` | `[JPEG] + [MP4]` | `HwCamera:MovingPicture="1"`, `GCamera:MotionPhotoPresentationTimestampUs` | 不混入 `GCamera:MotionPhoto` 防止工厂抢占；命中 `HuaweiMotionPhotoProcessor` |
| `oppo` | `[JPEG] + [MP4]` | `OPPO:LivePhoto="1"`, `O-Live="1"`, `GCamera:MotionPhotoPresentationTimestampUs` | 不写入 `GCamera:MicroVideoOffset` 防止被 `Pixel` 提前截获；命中 `OppoMotionPhotoProcessor` |
| `vivo` | `[JPEG] + [MP4]` | `vivo:LivePhoto="1"`, `LivePhoto="1"`, `GCamera:MotionPhotoPresentationTimestampUs` | 命中 `VivoMotionPhotoProcessor` |
| `universal` | `[JPEG] + [MP4]` | 无厂商 Motion XMP（完整保留原图 EXIF） | 纯净 `[JPEG][MP4]`；命中 `UniversalMotionPhotoProcessor` |

## 5. 架构与涉及文件清单

1. **新建 `Motion2Live/Services/LivePhotoExtractor.swift`**
   - 从 `PHPickerResult`（优先 `PHAssetResource.assetResources(for: asset)` 的 `.fullSizePhoto`/`.fullSizePairedVideo`，无读权限时回退 `PHLivePhoto` 的 `PHAssetResource`）只读抽取静态图与 `.mov` 至 `NSTemporaryDirectory`。
2. **新建 `Motion2Live/Models/MotionPhotoEncoder.swift`**
   - 同时支持从静态图 `Data`（供 `CustomLivePhotoView`）或图片 `URL`（供 `LiveToMotionView`）编码：
     - ImageIO 将非 JPEG（HEIC/PNG 等）转为 `0.95` 质量 JPEG 并保留 EXIF/Orientation/GPS/色彩配置；剥离冲突旧 XMP `APP1`。
     - `AVAssetReader` 读取 `com.apple.quicktime.still-image-time` 微秒时间戳（普通短视频缺失该轨道时自动回退视频中点）；`AVMutableComposition` 剥离 QuickTime 元轨道后默认用 `AVAssetExportPresetPassthrough` 无损混流 `.mp4`（不兼容时静默回退 `AVAssetExportPresetHighestQuality`）。
     - 生成品牌 XMP `APP1` 段并拼装容器，输出前校验 `ISOBMFFHelper.hasFtypSignature` 与 `XMPParser.extractAndParse`。
3. **修改 `Motion2Live/Services/MediaExportService.swift`**
   - 新增 `exportMotionPhoto(imageData:videoURL:targetBrand:creationDate:) async throws -> URL` 及基于 `imageURL` 的重载，输出受临时目录守卫约束的标准 `.jpg`；写入临时 `.jpg` 后，若解析到 `creationDate` 或原图 EXIF 拍摄时间（经 `resolveCreationDate`），同步设置该临时文件的 `.creationDate` 与 `.modificationDate` 属性（同时核对 `PrivacyInfo.xcprivacy` 已声明 `C617.1`）；在 `CustomLivePhotoView` 导出 `Live Photo` / `Motion Photo` 时优先提取所选静图 EXIF 拍摄时间（无 EXIF 时回退 `Date()`）。
4. **修改 `Motion2Live/Views/Components/PhotoPicker.swift`**
   - 新增 `.livePhotos` 选择器封装回调 `LivePhotoExtractor`，不影响现有正向选择器。
5. **修改 `Motion2Live/LabView.swift` & 新建 `Motion2Live/Views/LiveToMotionView.swift`**
   - 在 `LabView` 挂载「Live Photo → 动态照片」入口卡片，并在 `CustomLivePhotoView` 增加输出格式切换（`Live Photo` / `Motion Photo`），复用共用品牌选择与分享/文件导出组件。
6. **修改 `Motion2Live/Localizable.swift`**
   - 补全 7 语本地化文案；核对 `PrivacyInfo.xcprivacy`。
7. **修改 `Motion2LiveTests/Motion2LiveTests.swift`**
   - 覆盖全部 7 品牌闭环回读测试（同时覆盖带 `still-image-time` 与不带元轨道的自定义图+视频输入）、HEIC 方向/日期保留、旧 XMP 清理、三星 SEF 剥离及临时文件清理。

## 6. 验收标准

1. **单元测试**：`Motion2LiveTests` 新增全品牌逆向闭环测试与边界用例全部通过，现有测试零回归。
2. **冒烟验证**：在 `LabView` 的「图 + 视频合成」和「Live Photo → 动态照片」两条入口导出的 `.jpg`，重新导入 Motion2Live 均能准确识别目标品牌并播放动态视频。

## 7. Handoff Notes

- 规划已并入 Lab 图+视频双向导出范围并全部定稿，待创建 `feat/live-to-motion-photo` Worktree 后实施。
