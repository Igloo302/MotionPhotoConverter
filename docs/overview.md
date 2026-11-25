# Motion2Live 项目概述

## 项目简介

Motion2Live 是一个运行在 iOS 16.0+ 的原生应用，旨在帮助用户离线处理和转换来自 Android（小米、Google Pixel、三星、OPPO/一加、华为等）的 Motion Photo（动态照片）。用户可以轻松提取内嵌视频、选择自定义关键帧封面、批量或单张导出为 Apple 原生 Live Photo（实况照片）或 GIF，并保存到系统相册。

## 项目背景

各大手机厂商推出了不同的动态照片格式，如 Google Motion Photo、三星 MotionPhoto_Data、小米 MicroVideo/MotionPhoto 等。由于跨平台格式不兼容，Android 拍摄的动态照片在 iOS 相册中通常只显示静态图片。Motion2Live 通过本地二进制解析与标准 AVFoundation/PhotosUI 封装，打通跨平台实况照片体验。

## 主要特点（v1.3.0）

- **Obsidian 暗夜玻璃界面**：基于 `ObsidianTheme` 统一设计系统，自适应 iPhone、iPhone Duo 与 iPad 屏幕尺寸。
- **多品牌智能识别**：支持小米（新/旧格式）、Google Pixel、三星（含 SEF Trailer 剥离）、OPPO/一加及通用 MP4 拼接格式。
- **批量转换与内存安全**：支持批量选择与串行安全导出，避免高分辨率图片同时解码导致的内存峰值。
- **关键帧封面选择**：支持在导出 Live Photo 前从视频流中挑选最佳静态封面帧并保留 EXIF 元数据。
- **零权限首页示范与最近转换卡组**：首次启动内置 3 张精选示范图；使用后自动缓存最近 1–3 张输出缩略图（不申请全相册读取权限）。
- **7 种语言完整本地化**：覆盖英语、简体中文、法语、德语、西班牙语、日语和韩语（含 `InfoPlist.strings` 系统权限文案）。
- **实验室功能**：支持将任意静态图片与视频合成为自定义 Live Photo。

## 技术栈

- **SwiftUI**：构建现代化、多端自适应的用户界面
- **AVFoundation / AVKit**：处理视频解析、关键帧提取、MOV 转码与播放
- **Photos / PhotosUI**：通过 `PHPickerViewController` 选图及 `.addOnly` 权限写入系统相册
- **ImageIO / UniformTypeIdentifiers**：图像元数据（EXIF / Apple Maker Dictionary）、缩略图下采样与 GIF 编码