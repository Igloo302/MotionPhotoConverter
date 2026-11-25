# Motion2Live

Motion2Live is an iOS application (iOS 16.0+) designed to help users process and convert Motion Photos (Xiaomi, Google Pixel, Samsung, OPPO/OnePlus, Huawei/Universal) into native Apple Live Photos, standalone videos, or animated GIFs—100% offline on-device.

## 功能介绍 / Features

### 1. 提取视频与导出 Live Photo / GIF
- **导出为 Live Photo**：将动态照片无损封装为 iOS 原生 Live Photo（支持自定义关键帧封面），并保留拍摄时间等 EXIF 元数据。
- **提取视频 / 导出为 GIF**：一键提取内嵌 MP4 视频或转换为高质量 GIF 动图，支持保存到系统相册或通过系统分享面板导出。

### 2. 批量转换 / Batch Conversion
- 支持一次选择多张动态照片，采用可控的串行导出管线降低内存峰值，批量保存为 Live Photo 或 GIF。

### 3. 关键帧封面选择 / Keyframe Cover Picker
- 内置 `KeyframePickerSheet`，支持从内嵌视频流中浏览并选取任意时刻作为 Live Photo 静态封面帧。

### 4. 零权限首页示范与最近转换卡组
- 首次启动内置 3 张精选示范图（`HeroDemoCenter` / `HeroDemoLeft` / `HeroDemoRight`），无需申请相册权限即可完整预览。
- 转换完成后自动在本地缓存最近 1–3 张输出缩略图（不申请全相册读取权限），动态更新首页卡组；支持随时关闭或清空历史。

### 5. Obsidian 暗夜玻璃设计与多端适配
- 基于 `ObsidianTheme` 统一设计系统，针对 iPhone、iPhone Duo 与 iPad 多种尺寸进行自适应布局。

### 6. 7 种语言完整本地化与隐私合规
- 支持英语、简体中文、法语、德语、西班牙语、日语、韩语，并同步本地化 `InfoPlist.strings` 相册保存权限弹窗文案。
- 仅使用系统 `PHPickerViewController` 与 `.addOnly` 写入权限，内置 `PrivacyInfo.xcprivacy` 隐私清单。

## 使用方法 / Usage

1. 打开 `Motion2Live.xcodeproj`（iOS 16.0+），在首页点击选择动态照片，或进入「批量转换」与「实验室」。
2. 应用自动识别厂商格式（Xiaomi / Pixel / Samsung / OPPO / Huawei 等）并解析内嵌视频流。
3. 长按预览动态效果，按需通过关键帧选择器更换封面，然后导出为 Live Photo、视频或 GIF。

## 依赖库 / Dependencies

- SwiftUI
- AVFoundation / AVKit
- Photos / PhotosUI
- ImageIO / UniformTypeIdentifiers

## 开发者 / Developer

- Larry Shen

## 许可证 / License

本项目采用 Mozilla Public License 2.0（MPL-2.0）。你可以在遵守该许可证的前提下使用、修改和分发本项目，包括商业用途；对 MPL 覆盖文件的修改需以 MPL-2.0 公开。完整条款见 [LICENSE](LICENSE)。

This project is licensed under the Mozilla Public License 2.0 (MPL-2.0). You may use, modify and distribute it, including commercially, provided you comply with the license; modifications to MPL-covered files must be shared under MPL-2.0. See [LICENSE](LICENSE) for the full terms.

Copyright 2024–2026 Larry Shen (Igloo)
