# Motion2Live 开发指南

本指南为开发者提供参与 Motion2Live 项目开发的核心信息。

## 目录

- [开发环境设置](#开发环境设置)
- [项目结构](#项目结构)
- [编码规范](#编码规范)
- [开发工作流](#开发工作流)
- [调试和测试](#调试和测试)

## 开发环境设置

### 系统要求
- **macOS**: 13.0 (Ventura) 或更高版本
- **Xcode**: 15.0 或更高版本
- **iOS 部署目标**: 15.0 或更高版本
- **Swift**: 5.9 或更高版本

### 快速开始
1. 克隆项目：`git clone <repository-url>`
2. 打开 `MotionPhotoConverter.xcodeproj`
3. 配置开发者账户和 Bundle Identifier
4. 选择目标设备并运行

### 推荐测试设备
- iPhone 16 Pro (iOS 18.0)
- iPad Air (第5代) (iPadOS 18.0)

## 项目结构

```
Motion2Live/
├── MotionPhotoConverterApp.swift  # 应用入口和主要视图
├── HomeView.swift                 # 主界面
├── HomeViewModel.swift            # 主页视图模型
├── Models/                        # 数据模型
│   ├── MotionPhoto.swift         # 动态照片数据模型
│   └── MotionPhotoProcessor.swift # 多品牌处理器架构
├── Components/                    # UI 组件
│   ├── PlaybackHintView          # 播放引导组件
│   └── ExportOptionsView         # 导出选项组件
│   └── SupportedBrandsView       # 支持品牌展示组件
├── Utils/                         # 工具类
│   ├── XMPParser.swift           # XMP 元数据解析
│   ├── VideoExporter.swift       # 视频导出
│   └── LivePhotoCreator.swift    # Live Photo 创建
├── Resources/
│   ├── Localizable.swift         # 本地化字符串
│   └── Assets.xcassets           # 图片资源
└── Info.plist                    # 应用配置
```

### 核心组件

#### 主要视图和模型
- **MotionPhotoConverterApp.swift**: 应用入口点和主要视图逻辑
- **HomeView.swift**: 主界面，处理照片选择和预览
- **HomeViewModel.swift**: 主页业务逻辑处理
- **MotionPhoto.swift**: 动态照片数据模型

#### 多品牌处理器架构
- **MotionPhotoProcessor.swift**: 基于协议的可扩展处理器架构
- **XiaomiMotionPhotoProcessor**: 小米动态照片处理器
- **AndroidMotionPhotoProcessor**: Android (Pixel/Samsung) 处理器
- **MotionPhotoProcessorFactory**: 处理器工厂类

#### 用户体验组件
- **PlaybackHintView**: 首次使用引导组件
- **ExportOptionsView**: 导出选项面板
- **SupportedBrandsView**: 支持品牌展示

#### 核心功能模块
- **XMPParser**: XMP 元数据解析
- **VideoExporter**: 视频导出功能
- **LivePhotoCreator**: Live Photo 创建逻辑

## 编码规范

### Swift 代码风格
遵循 [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)：

- **类名**: PascalCase (`MotionPhotoProcessor`)
- **属性/方法**: camelCase (`processMotionPhoto()`)
- **常量**: camelCase (`maxVideoLength`)
- **枚举**: PascalCase，case 使用 camelCase

### 代码组织
```swift
class HomeView: View {
    // MARK: - Properties
    @State private var selectedPhoto: UIImage?
    
    // MARK: - Body
    var body: some View {
        // 视图实现
    }
    
    // MARK: - Private Methods
    private func processPhoto() {
        // 实现
    }
}
```

### SwiftUI 最佳实践
- 将复杂视图拆分为小的、可复用的组件
- 使用 `@State` 管理本地状态
- 使用 `@StateObject` 管理视图模型
- 使用 `@Binding` 在视图间传递状态

### 用户体验功能开发

#### 智能引导系统
```swift
// 状态管理
@State private var showPlaybackHint = false
@State private var hasUserPlayedVideo = UserDefaults.standard.bool(forKey: "hasUserPlayedVideo")

// 引导显示逻辑
.onAppear {
    if !hasUserPlayedVideo && selectedImageURL != nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPlaybackHint = true
            }
        }
    }
}
```

#### 触感反馈实现
```swift
// 触感反馈生成器
private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
private let softImpactFeedback = UIImpactFeedbackGenerator(style: .soft)

// 播放开始时的反馈
func startVideoPlaybackWithFeedback() {
    lightImpactFeedback.impactOccurred()
    startVideoPlayback()
    hidePlaybackHint()
}

// 播放结束时的反馈
func stopVideoPlaybackWithFeedback() {
    softImpactFeedback.impactOccurred()
    stopVideoPlayback()
}
```

#### 组件化设计原则
```swift
// 独立的引导组件
struct PlaybackHintView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        // 组件实现
    }
}

// 在主视图中使用
if showPlaybackHint {
    PlaybackHintView(onDismiss: hidePlaybackHint)
        .transition(.opacity)
}
```

## 开发工作流

### Git 工作流
使用简化的 Git Flow：

- **main**: 稳定的发布版本
- **develop**: 最新的开发代码
- **feature/***: 新功能开发分支

### 开发流程
1. 从 develop 创建功能分支：`git checkout -b feature/feature-name`
2. 开发并提交代码
3. 推送分支并创建 Pull Request
4. 代码审查后合并到 develop

### 提交信息规范
使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>: <description>
```

**类型**：
- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 文档更新
- `refactor`: 代码重构
- `test`: 测试相关

**示例**：
```bash
git commit -m "feat: add motion photo export functionality"
git commit -m "fix: resolve crash when processing large files"
```

## 调试和测试

### 测试策略

#### 单元测试
项目使用 XCTest 框架：

```swift
import XCTest
@testable import MotionPhotoConverter

class MotionPhotoProcessorTests: XCTestCase {
    func testProcessValidMotionPhoto() {
        let processor = MotionPhotoProcessor()
        // 测试逻辑
    }
}
```

重点测试模块：
- `MotionPhotoProcessor` 各品牌处理器
- `XMPParser` 元数据解析
- `VideoExporter` 和 `LivePhotoCreator`
- 用户状态管理逻辑

#### UI 测试
使用 XCUITest 测试用户界面：

```swift
class MotionPhotoConverterUITests: XCTestCase {
    func testMainFlow() {
        let app = XCUIApplication()
        app.launch()
        
        let selectButton = app.buttons["选择动态照片"]
        XCTAssertTrue(selectButton.exists)
    }
}
```

重点测试场景：
- 首次使用引导流程
- 触感反馈响应
- 动态照片选择和预览
- 导出功能完整性

#### 集成测试
```bash
# 运行所有测试
xcodebuild test -scheme MotionPhotoConverter -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# 在 Xcode 中使用 Cmd+U
```

### 调试技巧

#### 日志记录
```swift
// 使用统一的日志系统
import os.log

static let logger = Logger(subsystem: "com.motion2live", category: "MotionPhoto")

// 不同级别的日志
logger.info("Motion photo processing started")
logger.debug("Processing \(brand.rawValue) motion photo")
logger.error("Failed to extract video: \(error.localizedDescription)")
```

#### 用户体验调试
```swift
// 调试引导系统
print("[UX] Playback hint shown: \(showPlaybackHint)")
print("[UX] User has played video: \(hasUserPlayedVideo)")

// 调试触感反馈
print("[Haptic] Light impact triggered")
print("[Haptic] Soft impact triggered")
```

#### 性能分析
- 使用 Instruments 的 Time Profiler 分析 CPU 使用
- 使用 Allocations 监控内存使用，特别是大文件处理时
- 使用 Leaks 检测内存泄漏
- 测试不同尺寸动态照片的处理时间

#### 真机测试
- 连接 iOS 设备进行真实环境测试
- 测试相机和照片库集成
- 验证真实 Motion Photo 文件处理
- 验证不同品牌手机的兼容性（小米、Pixel、三星）
- 验证触感反馈在不同设备上的表现
- 测试用户引导在不同屏幕尺寸上的显示效果

---

本开发指南涵盖了 Motion2Live 项目开发的核心要素。如有疑问，请查阅项目文档或在 GitHub 上提出 Issue。