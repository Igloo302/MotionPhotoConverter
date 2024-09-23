# MotionPhotoConverter

MotionPhotoConverter 是一个 iOS 应用程序，旨在帮助用户处理和转换 Motion Photo。Motion Photo 是一种包含静态图像和短视频的照片格式，常见于 Google 相册和某些 Android 设备。通过 MotionPhotoConverter，用户可以轻松地从 Motion Photo 中提取视频、导出为 Live Photo 或 GIF，并将其保存到相册中。

MotionPhotoConverter is an iOS application designed to help users process and convert Motion Photos. Motion Photos are a type of photo format that includes a static image and a short video, commonly found in Google Photos and some Android devices. With MotionPhotoConverter, users can easily extract videos from Motion Photos, export them as Live Photos or GIFs, and save them to their photo library.

## 功能介绍 / Features

### 1. 提取视频 / Extract Video
用户可以从 Motion Photo 中提取视频，并将其保存为独立的视频文件。应用会自动识别 Motion Photo 并提取其中的视频数据。

Users can extract videos from Motion Photos and save them as standalone video files. The app automatically recognizes Motion Photos and extracts the video data.

### 2. 导出为 Live Photo / Export as Live Photo
用户可以将 Motion Photo 转换为 Live Photo，并将其保存到相册中。Live Photo 是一种包含短视频的照片格式，常见于 iOS 设备。

Users can convert Motion Photos to Live Photos and save them to their photo library. Live Photos are a type of photo format that includes a short video, commonly found on iOS devices.

### 3. 导出为 GIF / Export as GIF
用户可以将 Motion Photo 中的视频部分导出为 GIF 动图，并将其保存到相册中。GIF 动图是一种广泛使用的动画图片格式，适用于社交媒体分享。

Users can export the video part of a Motion Photo as a GIF animation and save it to their photo library. GIF animations are a widely used format for animated images, suitable for sharing on social media.

### 4. 照片选择器 / Photo Picker
应用内置了照片选择器，用户可以从相册中选择 Motion Photo 进行处理。照片选择器会自动过滤非 Motion Photo，并提示用户选择有效的 Motion Photo。

The app includes a photo picker that allows users to select Motion Photos from their photo library for processing. The photo picker automatically filters out non-Motion Photos and prompts users to select valid Motion Photos.

### 5. 视频播放 / Video Playback
用户可以在应用中播放 Motion Photo 中的视频部分。应用提供了视频播放控件，用户可以通过手势控制视频的播放和暂停。

Users can play the video part of a Motion Photo within the app. The app provides video playback controls, allowing users to control video playback and pause with gestures.

### 6. 导出菜单 / Export Menu
应用提供了导出菜单，用户可以选择将 Motion Photo 导出为视频、Live Photo 或 GIF。导出过程简单直观，用户可以轻松完成转换和保存操作。

The app provides an export menu, allowing users to choose to export Motion Photos as videos, Live Photos, or GIFs. The export process is simple and intuitive, enabling users to easily complete the conversion and save operations.

## 使用方法 / Usage
[Motion Photo Sample](https://github.com/Igloo302/MotionPhotoConverter/blob/main/MotionPhotoSample.jpg)

1. 打开应用并选择一个 Motion Photo。
2. 应用会自动提取 Motion Photo 中的视频数据，并显示静态图像和视频预览。
3. 用户可以通过导出菜单选择导出为视频、Live Photo 或 GIF。
4. 导出完成后，用户可以将转换后的文件保存到相册中。

1. Open the app and select a Motion Photo.
2. The app will automatically extract the video data from the Motion Photo and display the static image and video preview.
3. Users can choose to export as a video, Live Photo, or GIF through the export menu.
4. After the export is complete, users can save the converted file to their photo library.

## 依赖库 / Dependencies

- SwiftUI
- AVKit
- PhotosUI
- UniformTypeIdentifiers

## 开发者 / Developer

- Larry Shen

## 许可证 / License

此项目遵循 MIT 许可证。详细信息请参阅 LICENSE 文件。

This project is licensed under the MIT License. For more details, please refer to the LICENSE file.
