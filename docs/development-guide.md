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
├── Motion2LiveApp.swift           # 应用入口
├── Views/                         # 视图组件
│   ├── HomeView.swift            # 主界面
│   └── LabView.swift             # 实验室功能
├── ViewModels/
│   └── HomeViewModel.swift       # 主页视图模型
├── Utils/                         # 核心工具类
│   ├── MotionPhotoProcessor.swift # 动态照片处理
│   ├── VideoExporter.swift       # 视频导出
│   └── LivePhotoCreator.swift    # Live Photo 创建
├── Resources/
│   ├── Localizable.swift         # 本地化字符串
│   └── Assets.xcassets           # 图片资源
└── Info.plist                    # 应用配置
```

### 核心组件

- **Motion2LiveApp.swift**: 应用入口点
- **HomeView.swift**: 主界面，处理照片选择和预览
- **LabView.swift**: 实验室功能界面
- **HomeViewModel.swift**: 主页业务逻辑处理
- **MotionPhotoProcessor.swift**: 动态照片解析和提取核心逻辑
- **VideoExporter.swift**: 视频导出功能
- **LivePhotoCreator.swift**: Live Photo 创建逻辑

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

### 单元测试
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

### UI 测试
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

### 运行测试
```bash
# 运行所有测试
xcodebuild test -scheme MotionPhotoConverter -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# 在 Xcode 中使用 Cmd+U
```

### 调试技巧

**日志记录**：
```swift
import os.log

static let logger = Logger(subsystem: "com.app.motionphoto", category: "processing")
logger.info("Processing motion photo")
```

**性能分析**：
- 使用 Instruments 的 Time Profiler 分析 CPU 使用
- 使用 Allocations 监控内存使用
- 使用 Leaks 检测内存泄漏

**真机测试**：
- 连接 iOS 设备进行真实环境测试
- 测试相机和照片库集成
- 验证真实 Motion Photo 文件处理

---

本开发指南涵盖了 Motion2Live 项目开发的核心要素。如有疑问，请查阅项目文档或在 GitHub 上提出 Issue。