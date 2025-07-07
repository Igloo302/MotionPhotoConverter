# Motion2Live

Motion2Live 是一个功能强大的 iOS 应用程序，专为处理和转换动态照片而设计。支持多种品牌的动态照片格式，包括小米、Google Pixel 和三星设备。通过 Motion2Live，用户可以轻松地从动态照片中提取视频、导出为 Live Photo 或 GIF，并享受直观的用户体验和智能引导功能。

Motion2Live is a powerful iOS application designed for processing and converting Motion Photos. It supports multiple brands of Motion Photo formats, including Xiaomi, Google Pixel, and Samsung devices. With Motion2Live, users can easily extract videos from Motion Photos, export them as Live Photos or GIFs, and enjoy an intuitive user experience with smart guidance features.

## ✨ 核心功能 / Core Features

### 🎯 多品牌支持 / Multi-Brand Support
- **小米动态照片** - 完全支持新旧版本格式
- **Google Pixel Motion Photo** - 支持 GContainer 和 Directory Item 格式
- **三星动态照片** - 支持多种三星设备格式
- **华为动态照片** - 新增支持基于 File Type Box 检测的华为动态照片
- **智能识别** - 自动检测并选择合适的处理器，支持多层回退机制

Supports multiple Motion Photo formats from Xiaomi, Google Pixel, Samsung, and Huawei devices with intelligent format detection and fallback mechanisms.

### 📱 智能用户体验 / Smart User Experience
- **首次使用引导** - 半透明提示面板，动态 Live Photo 图标指引
- **直观操作** - 按住播放，松开停止的自然交互
- **状态记忆** - 智能记住用户操作习惯，引导仅在首次显示
- **简洁体验** - 专注核心功能，移除不必要的干扰

Intuitive first-time user guidance with natural gesture-based interactions and streamlined experience.

### 🎬 视频处理 / Video Processing
- **高质量提取** - 保持原始视频质量和分辨率
- **智能播放** - 流畅的视频预览和播放控制
- **元数据保留** - 保持创建时间和修改时间信息

High-quality video extraction with metadata preservation and smooth playback controls.

### 📸 Live Photo 转换 / Live Photo Conversion
- **原生兼容** - 完全兼容 iOS Live Photo 格式
- **时间同步** - 精确计算静态图片在视频中的时间点
- **质量优化** - 自动优化图片和视频质量匹配

Native iOS Live Photo compatibility with precise timing synchronization.

### 🎨 GIF 导出 / GIF Export
- **高质量转换** - 保持动画流畅度和清晰度
- **自动优化** - 智能调整帧率和文件大小
- **社交分享** - 适合各种社交媒体平台的格式

High-quality GIF conversion optimized for social media sharing.

### 🏠 现代化界面 / Modern Interface
- **SwiftUI 设计** - 现代化、响应式的用户界面
- **深色模式** - 完整支持系统深色模式
- **动画效果** - 流畅的过渡动画和视觉反馈
- **帮助系统** - 内置详细的帮助文档和故障排除指南

Modern SwiftUI interface with dark mode support and comprehensive help system.

## 🚀 快速开始 / Quick Start

### 第一步：选择动态照片
1. 点击主界面的「选择动态照片」按钮
2. 从相册中选择支持的动态照片格式
3. 应用会自动识别并显示预览

### 第二步：预览和播放
- **按住屏幕**播放视频部分（首次使用会有引导提示）
- 松开手指停止播放
- 享受流畅的视觉反馈体验

### 第三步：选择导出格式
点击「导出」按钮，选择您需要的格式：
- **📹 视频** - 提取为独立的 MP4 视频文件
- **📸 Live Photo** - 转换为 iOS 原生 Live Photo
- **🎨 GIF** - 转换为适合分享的 GIF 动图

### Step 1: Select Motion Photo
1. Tap "Select Motion Photo" on the main interface
2. Choose from supported Motion Photo formats in your library
3. The app will automatically recognize and display preview

### Step 2: Preview and Play
- **Press and hold** to play video (first-time guidance included)
- Release to stop playback
- Enjoy smooth visual feedback

### Step 3: Choose Export Format
Tap "Export" and select your desired format:
- **📹 Video** - Extract as standalone MP4 video
- **📸 Live Photo** - Convert to native iOS Live Photo
- **🎨 GIF** - Convert to shareable GIF animation

## 🛠 技术栈 / Tech Stack

### 核心框架 / Core Frameworks
- **SwiftUI** - 现代化用户界面框架
- **AVFoundation** - 视频和音频处理
- **PhotosUI** - 照片库集成
- **UniformTypeIdentifiers** - 文件类型识别
- **ImageIO** - 图像处理和元数据

### 架构模式 / Architecture
- **MVVM** - Model-View-ViewModel 架构
- **协议导向编程** - 可扩展的处理器架构
- **异步处理** - Swift Concurrency (async/await)
- **响应式设计** - SwiftUI 数据绑定
- **Swift 6 兼容** - 完全支持 Swift 6 严格并发检查
- **内存安全** - 安全的二进制数据处理和内存对齐

## 📋 系统要求 / System Requirements

- **iOS 16.0+** - 支持最新的 iOS 功能
- **iPhone/iPad** - 通用应用，适配所有设备
- **存储空间** - 建议至少 100MB 可用空间
- **权限** - 需要照片库访问权限

## 📚 文档中心 / Documentation Center

欢迎来到 Motion2Live 文档中心！本项目是一个 iOS 应用，用于处理和转换动态照片（Motion Photo）。

### 📱 用户文档 / User Documentation
- [用户指南](docs/user-guide.md) - 完整的用户操作指南 / Complete user operation guide
- [常见问题解答 (FAQ)](docs/faq.md) - 用户常见问题和解答 / Common questions and answers

### 🔧 开发文档 / Development Documentation
- [产品需求文档](docs/prd.md) - 详细的产品功能需求和规划 / Detailed product requirements and planning
- [开发任务清单](docs/todo.md) - 模块化的后续开发工作计划 / Modular development task planning
- [技术架构](docs/architecture.md) - 应用架构和设计原理 / Application architecture and design principles
- [开发指南](docs/development-guide.md) - 参与项目开发的完整指南 / Complete guide for project development
- [本地化指南](docs/localization-guide.md) - 多语言支持和本地化流程 / Multi-language support and localization process

### 📋 项目管理 / Project Management
- [更新日志](docs/changelog.md) - 版本历史和变更记录 / Version history and change records

## 📱 支持的动态照片格式 / Supported Motion Photo Formats

| 品牌 / Brand | 状态 / Status | 说明 / Description |
|------|------|------|
| 小米 / Xiaomi | ✅ 完全支持 / Fully Supported | 新旧版本动态照片均支持 / Both new and old formats supported |
| Google Pixel | ✅ 完全支持 / Fully Supported | 支持 GContainer 和 Directory Item 格式 / Supports GContainer and Directory Item formats |
| 三星 / Samsung | ✅ 完全支持 / Fully Supported | 支持 Directory Item 和 GCamera 两种格式 / Supports Directory Item and GCamera formats |
| 华为 / Huawei | ✅ 新增支持 / Newly Supported | 基于 File Type Box (ftyp) 检测的华为动态照片 / Huawei Motion Photos via File Type Box detection |
| Unknown 类型 / Unknown | ✅ 回退支持 / Fallback Support | 通过 File Type Box (ftyp) 检测 MP4 视频 / MP4 detection via File Type Box (ftyp) |

### 快速导航 / Quick Navigation

1. **用户 / Users**：查看 [用户指南](docs/user-guide.md) 了解如何使用应用 / Check [User Guide](docs/user-guide.md) to learn how to use the app
2. **开发者 / Developers**：查看 [技术架构](docs/architecture.md) 了解架构设计 / Check [Architecture](docs/architecture.md) to understand the design
3. **贡献者 / Contributors**：查看 [开发指南](docs/development-guide.md) 参与项目开发 / Check [Development Guide](docs/development-guide.md) to contribute

## 🤝 贡献 / Contributing

欢迎贡献代码、报告问题或提出建议！请查看 [贡献指南](docs/contributing.md) 了解详细信息。

Contributions are welcome! Please check the [Contributing Guide](docs/contributing.md) for details.

## 📞 支持 / Support

如需帮助或有任何问题，请通过以下方式联系：

- **📧 邮箱**: shenjy302@live.com
- **🐛 问题反馈**: [GitHub Issues](https://github.com/Igloo302/MotionPhotoConverter/issues)
- **💡 功能建议**: [GitHub Discussions](https://github.com/Igloo302/MotionPhotoConverter/discussions)

## 👨‍💻 开发者 / Developer

**Larry Shen (Igloo)**
- GitHub: [@Igloo302](https://github.com/Igloo302)
- Email: shenjy302@live.com

## 📄 许可证 / License

此项目遵循 MIT 许可证。详细信息请参阅 [LICENSE](LICENSE) 文件。

This project is licensed under the MIT License. For more details, please refer to the [LICENSE](LICENSE) file.

## 🙏 致谢 / Acknowledgments

感谢所有为这个项目做出贡献的开发者和用户。特别感谢：

- SwiftUI 社区的技术支持
- 测试用户的宝贵反馈
- 开源社区的持续支持

Thanks to all developers and users who contributed to this project. Special thanks to the SwiftUI community, beta testers, and the open-source community.

---

**Motion2Live v1.2.1** © 2024 Igloo. 用❤️制作。

**Motion2Live v1.2.1** © 2024 Igloo. Made with ❤️.
