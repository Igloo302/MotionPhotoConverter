# Motion2Live 开发指南

本文档为开发者提供参与 Motion2Live 项目开发的指南，包括环境设置、代码规范、贡献流程等信息。

## 目录

- [开发环境设置](#开发环境设置)
- [项目结构](#项目结构)
- [编码规范](#编码规范)
- [开发工作流](#开发工作流)
- [测试指南](#测试指南)
- [调试技巧](#调试技巧)
- [贡献指南](#贡献指南)
- [版本发布流程](#版本发布流程)

## 开发环境设置

### 系统要求

- macOS 12.0 或更高版本
- Xcode 14.0 或更高版本
- iOS 15.0 SDK 或更高版本
- Git 版本控制系统

### 获取源代码

1. 克隆项目仓库：

```bash
git clone https://github.com/Igloo302/Motion2Live.git
cd Motion2Live
```

2. 打开项目：

```bash
open Motion2Live.xcodeproj
```

### 依赖管理

本项目直接使用 iOS 系统框架，不依赖第三方库，因此无需额外的依赖管理工具。

## 项目结构

```
Motion2Live/
├── Motion2Live/          # 主应用源代码
│   ├── Assets.xcassets/           # 图像资源
│   ├── HomeView.swift             # 主页视图
│   ├── HomeViewModel.swift        # 主页视图模型
│   ├── Info.plist                 # 应用配置文件
│   ├── LabView.swift              # 实验室功能视图
│   ├── Localizable.swift          # 本地化支持
│   ├── Motion2LiveApp.swift  # 应用入口
│   └── Preview Content/           # 预览资源
├── Motion2LiveTests/     # 单元测试
├── Motion2LiveUITests/   # UI 测试
├── Motion2Live.xcodeproj # Xcode 项目文件
└── README.md                      # 项目说明
```

### 主要组件说明

- **Motion2LiveApp.swift**：应用的入口点，设置应用的主窗口和初始视图。
- **HomeView.swift**：应用的主页视图，显示欢迎信息和照片选择按钮。
- **HomeViewModel.swift**：HomeView 的视图模型，处理主页相关的业务逻辑。
- **LabView.swift**：实验室功能视图，提供实验性功能如自定义 Live Photo 创建。
- **Localizable.swift**：处理应用的多语言支持。

## 编码规范

### Swift 代码规范

我们遵循 [Swift API 设计指南](https://swift.org/documentation/api-design-guidelines/) 和以下规范：

#### 命名约定

- 使用驼峰命名法（CamelCase）
- 类型名称（类、结构体、枚举、协议）使用 UpperCamelCase（首字母大写）
- 变量、常量、函数、方法使用 lowerCamelCase（首字母小写）
- 枚举值使用 lowerCamelCase

```swift
struct PhotoPicker { ... }  // 类型名称使用 UpperCamelCase
let imageData: Data  // 变量使用 lowerCamelCase
func processImage() { ... }  // 函数使用 lowerCamelCase
enum FileType { case image, video }  // 枚举值使用 lowerCamelCase
```

#### 代码格式化

- 使用 4 个空格进行缩进，不使用制表符
- 大括号在同一行开始，在新行结束
- 每行代码不超过 100 个字符
- 使用空行分隔不同的代码块，提高可读性

```swift
func example() {
    // 代码块
    let x = 10
    
    // 另一个代码块
    let y = 20
}
```

#### 注释规范

- 使用 `//` 进行单行注释
- 使用 `/* ... */` 进行多行注释
- 为公共 API 提供文档注释，使用 `///` 或 `/** ... */`

```swift
// 这是单行注释

/*
这是多行注释
可以跨越多行
*/

/// 这是文档注释，用于生成文档
/// - Parameter url: 图像的 URL
/// - Returns: 处理后的图像
func processImage(url: URL) -> UIImage { ... }
```

### SwiftUI 最佳实践

- 将复杂视图拆分为更小的子视图，提高可读性和可维护性
- 使用 `@State`、`@Binding`、`@ObservedObject`、`@StateObject` 等属性包装器管理状态
- 使用 MVVM 架构模式，将业务逻辑从视图中分离

```swift
struct ContentView: View {
    @StateObject private var viewModel = ViewModel()
    
    var body: some View {
        VStack {
            HeaderView(title: viewModel.title)
            BodyView(content: viewModel.content)
            FooterView(onAction: viewModel.performAction)
        }
    }
}
```

## 开发工作流

### 分支管理

我们使用 [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) 分支模型：

- `main`：主分支，包含生产就绪的代码
- `develop`：开发分支，包含最新的开发代码
- `feature/*`：功能分支，用于开发新功能
- `bugfix/*`：修复分支，用于修复 bug
- `release/*`：发布分支，用于准备新版本发布
- `hotfix/*`：热修复分支，用于修复生产环境中的紧急问题

### 开发流程

1. 从 `develop` 分支创建新的功能分支：

```bash
git checkout develop
git pull
git checkout -b feature/new-feature-name
```

2. 在功能分支上进行开发和提交：

```bash
# 进行代码修改
git add .
git commit -m "描述性的提交信息"
```

3. 定期将 `develop` 分支合并到功能分支，保持同步：

```bash
git checkout develop
git pull
git checkout feature/new-feature-name
git merge develop
# 解决可能的冲突
```

4. 完成功能开发后，创建 Pull Request 将功能分支合并到 `develop` 分支

5. 代码审查通过后，合并 Pull Request

## 测试指南

### 单元测试

单元测试位于 `Motion2LiveTests` 目录下，使用 XCTest 框架。

#### 编写单元测试

- 测试类名应以 `Tests` 结尾
- 测试方法名应以 `test` 开头
- 每个测试方法应该测试一个特定的功能或场景

```swift
class FileProcessorTests: XCTestCase {
    func testExtractVideoData() {
        // 准备测试数据
        let testData = createTestData()
        
        // 执行被测试的代码
        let result = FileProcessor.extractVideoData(from: testData)
        
        // 验证结果
        XCTAssertNotNil(result, "视频数据不应为 nil")
        XCTAssertEqual(result?.count, 1024, "视频数据大小应为 1024 字节")
    }
}
```

#### 运行单元测试

在 Xcode 中，使用快捷键 `Cmd+U` 运行所有测试，或者右键单击测试类或方法，选择 "Run Test" 运行特定测试。

### UI 测试

UI 测试位于 `Motion2LiveUITests` 目录下，使用 XCUITest 框架。

#### 编写 UI 测试

- 使用 XCUIApplication 启动应用
- 使用 XCUIElement 查找和交互界面元素
- 使用 XCTAssert 系列函数验证结果

```swift
class HomeViewUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }
    
    func testSelectPhotoButton() {
        // 查找并点击按钮
        let selectButton = app.buttons["选择动态照片"]
        XCTAssertTrue(selectButton.exists, "选择照片按钮应该存在")
        selectButton.tap()
        
        // 验证照片选择器是否显示
        let photoPicker = app.otherElements["PhotoPicker"]
        XCTAssertTrue(photoPicker.waitForExistence(timeout: 2), "照片选择器应该显示")
    }
}
```

## 调试技巧

### 日志记录

使用 `print` 或 `os_log` 记录调试信息：

```swift
import os.log

// 使用 print
print("处理文件: \(url.path)")

// 使用 os_log
let logger = OSLog(subsystem: "com.igloo.Motion2Live", category: "FileProcessing")
os_log("处理文件: %@", log: logger, type: .debug, url.path)
```

### 断点调试

1. 在 Xcode 中点击代码行号左侧添加断点
2. 运行应用，当执行到断点时，应用将暂停
3. 使用调试控制台检查变量值和执行命令
4. 使用 LLDB 命令进行高级调试

### 性能分析

使用 Xcode 的 Instruments 工具进行性能分析：

1. 在 Xcode 中选择 Product > Profile (或按 Cmd+I)
2. 选择适当的分析模板（如 Time Profiler、Allocations 等）
3. 运行分析并查看结果

## 贡献指南

### 提交 Bug 报告

如果您发现了 bug，请在 GitHub 上创建一个 issue，并提供以下信息：

1. Bug 的简要描述
2. 重现步骤
3. 预期行为
4. 实际行为
5. 截图或视频（如果适用）
6. 设备和系统信息

### 提出功能请求

如果您有新功能的想法，请在 GitHub 上创建一个 issue，并提供以下信息：

1. 功能的简要描述
2. 使用场景
3. 预期行为
4. 可能的实现方式（如果有）

### 提交 Pull Request

1. Fork 项目仓库
2. 创建功能分支
3. 提交更改
4. 确保测试通过
5. 创建 Pull Request，并提供详细的描述

### 代码审查

所有 Pull Request 都需要通过代码审查才能合并。代码审查的重点包括：

1. 代码质量和可读性
2. 遵循编码规范
3. 测试覆盖率
4. 性能考虑
5. 安全性考虑

## 版本发布流程

### 版本号规范

我们使用 [语义化版本控制](https://semver.org/lang/zh-CN/) (Semantic Versioning)：

- 主版本号（Major）：不兼容的 API 变更
- 次版本号（Minor）：向下兼容的功能性新增
- 修订号（Patch）：向下兼容的问题修正

例如：1.2.3 表示主版本 1，次版本 2，修订版 3。

### 发布步骤

1. 从 `develop` 分支创建发布分支：

```bash
git checkout develop
git pull
git checkout -b release/1.2.0
```

2. 更新版本号和发布说明

3. 进行最终测试和修复

4. 合并发布分支到 `main` 和 `develop`：

```bash
# 合并到 main
git checkout main
git pull
git merge --no-ff release/1.2.0
git tag -a v1.2.0 -m "版本 1.2.0"
git push origin main --tags

# 合并到 develop
git checkout develop
git pull
git merge --no-ff release/1.2.0
git push origin develop
```

5. 删除发布分支：

```bash
git branch -d release/1.2.0
```

6. 在 GitHub 上创建发布说明

7. 提交到 App Store

## 结语

感谢您对 Motion2Live 项目的贡献！如果您有任何问题或建议，请随时联系项目维护者或在 GitHub 上创建 issue。我们期待您的参与和贡献！