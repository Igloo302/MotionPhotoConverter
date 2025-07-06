# Motion2Live 贡献指南

感谢您考虑为 Motion2Live 项目做出贡献！本文档提供了参与项目贡献的指南和流程。

## 目录

- [行为准则](#行为准则)
- [如何贡献](#如何贡献)
  - [报告 Bug](#报告-bug)
  - [提出功能请求](#提出功能请求)
  - [提交代码](#提交代码)
- [开发流程](#开发流程)
  - [环境设置](#环境设置)
  - [分支策略](#分支策略)
  - [提交信息规范](#提交信息规范)
  - [代码风格](#代码风格)
- [测试](#测试)
- [文档](#文档)
- [发布流程](#发布流程)
- [社区](#社区)

## 行为准则

本项目采用贡献者公约（Contributor Covenant）作为行为准则。我们期望所有参与者遵守以下原则：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注社区最大利益
- 对其他社区成员表示同理心

## 如何贡献

### 报告 Bug

Bug 是指程序的实际行为与预期行为不符。报告 Bug 是对项目的重要贡献。

请按照以下步骤报告 Bug：

1. 在 GitHub 仓库的 Issues 页面检查是否已存在相同或类似的 Bug 报告
2. 如果没有，创建一个新的 Issue，使用 "Bug Report" 模板
3. 填写所有必要信息，包括：
   - 清晰的标题和描述
   - 重现步骤
   - 预期行为
   - 实际行为
   - 截图或视频（如果适用）
   - 设备和系统信息
   - 应用版本

### 提出功能请求

如果您有改进项目的想法，欢迎提出功能请求：

1. 在 GitHub 仓库的 Issues 页面检查是否已存在相同或类似的功能请求
2. 如果没有，创建一个新的 Issue，使用 "Feature Request" 模板
3. 填写所有必要信息，包括：
   - 清晰的标题和描述
   - 功能的使用场景
   - 预期行为
   - 可能的实现方式（如果有）
   - 相关的参考资料或示例（如果有）

### 提交代码

如果您想直接贡献代码，请按照以下步骤操作：

1. Fork 项目仓库
2. 创建您的功能分支（`git checkout -b feature/amazing-feature`）
3. 提交您的更改（`git commit -m 'Add some amazing feature'`）
4. 推送到分支（`git push origin feature/amazing-feature`）
5. 创建一个 Pull Request

## 开发流程

### 环境设置

开发 Motion2Live 需要以下环境：

- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本
- iOS 15.0 SDK 或更高版本
- Swift 5.9 或更高版本
- Git 版本控制系统

设置步骤：

1. 克隆您 fork 的仓库：

```bash
git clone https://github.com/YOUR_USERNAME/Motion2Live.git
cd Motion2Live
```

2. 添加上游仓库：

```bash
git remote add upstream https://github.com/Igloo302/Motion2Live.git
```

3. 打开项目：

```bash
open Motion2Live.xcodeproj
```

### 分支策略

我们使用 [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) 分支模型：

- `main`：主分支，包含生产就绪的代码
- `develop`：开发分支，包含最新的开发代码
- `feature/*`：功能分支，用于开发新功能
- `bugfix/*`：修复分支，用于修复 bug
- `release/*`：发布分支，用于准备新版本发布
- `hotfix/*`：热修复分支，用于修复生产环境中的紧急问题

贡献者应该从 `develop` 分支创建功能分支或修复分支，并在完成后提交 Pull Request 到 `develop` 分支。

### 提交信息规范

我们使用 [约定式提交](https://www.conventionalcommits.org/zh-hans/v1.0.0/) 规范来格式化提交信息：

```
<类型>[可选的作用域]: <描述>

[可选的正文]

[可选的脚注]
```

类型包括：

- `feat`：新功能
- `fix`：修复 bug
- `docs`：文档更改
- `style`：不影响代码含义的更改（空格、格式化、缺少分号等）
- `refactor`：既不修复 bug 也不添加功能的代码更改
- `perf`：改进性能的代码更改
- `test`：添加或修正测试
- `chore`：对构建过程或辅助工具和库的更改

示例：

```
feat(export): 添加导出为 WebP 格式的功能

实现了将 Motion Photo 导出为 WebP 动画格式的功能，支持调整质量和尺寸。

Closes #123
```

### 代码风格

我们遵循 [Swift API 设计指南](https://swift.org/documentation/api-design-guidelines/) 和以下规范：

#### 命名约定

- 使用驼峰命名法（CamelCase）
- 类型名称（类、结构体、枚举、协议）使用 UpperCamelCase（首字母大写）
- 变量、常量、函数、方法使用 lowerCamelCase（首字母小写）
- 枚举值使用 lowerCamelCase

#### 代码格式化

- 使用 4 个空格进行缩进，不使用制表符
- 大括号在同一行开始，在新行结束
- 每行代码不超过 100 个字符
- 使用空行分隔不同的代码块，提高可读性

#### 注释规范

- 使用 `//` 进行单行注释
- 使用 `/* ... */` 进行多行注释
- 为公共 API 提供文档注释，使用 `///` 或 `/** ... */`

### 用户体验功能贡献指南

#### 智能引导系统

在为应用添加新的引导功能时，请遵循以下原则：

- **状态管理**：使用 UserDefaults 持久化用户的引导状态
- **时机控制**：确保引导在合适的时机显示，不干扰用户正常操作
- **动画效果**：使用平滑的动画过渡，提升用户体验
- **可访问性**：确保引导内容支持 VoiceOver 等辅助功能

```swift
// 示例：添加新的引导功能
@State private var showNewFeatureHint = false
@State private var hasSeenNewFeature = UserDefaults.standard.bool(forKey: "hasSeenNewFeature")

// 在适当时机显示引导
.onAppear {
    if !hasSeenNewFeature {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNewFeatureHint = true
            }
        }
    }
}
```

#### 触感反馈

添加触感反馈时，请注意：

- **反馈类型**：根据交互类型选择合适的反馈强度（light、medium、heavy、soft）
- **时机准确**：确保反馈与用户操作同步
- **性能考虑**：避免频繁触发反馈，影响性能

```swift
// 示例：添加触感反馈
private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

func performActionWithFeedback() {
    impactFeedback.impactOccurred()
    // 执行实际操作
}
```

#### 多品牌支持扩展

在添加新品牌支持时，请遵循现有的架构模式：

1. **扩展 MotionPhotoBrand 枚举**
2. **创建品牌特定的处理器类**
3. **实现 MotionPhotoProcessorProtocol**
4. **在工厂类中注册新处理器**
5. **添加相应的测试用例**

```swift
// 示例：添加华为品牌支持
enum MotionPhotoBrand {
    case xiaomi, pixel, samsung, huawei // 新增华为
}

class HuaweiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    override func canProcess(_ data: Data) -> Bool {
        // 实现华为动态照片的识别逻辑
    }
    
    override func processMotionPhoto(_ data: Data) async throws -> MotionPhotoData {
        // 实现华为动态照片的处理逻辑
    }
}
```

## 测试

所有代码贡献都应包含适当的测试：

- **单元测试**：测试单个组件或函数的功能
- **集成测试**：测试多个组件之间的交互
- **UI 测试**：测试用户界面和交互
- **用户体验测试**：测试引导系统、触感反馈等用户体验功能

### 重点测试领域

#### 多品牌处理器测试
```swift
// 测试不同品牌的动态照片处理
func testXiaomiMotionPhotoProcessing() {
    let processor = XiaomiMotionPhotoProcessor()
    // 测试小米动态照片的识别和处理
}

func testPixelMotionPhotoProcessing() {
    let processor = AndroidMotionPhotoProcessor()
    // 测试 Pixel 动态照片的识别和处理
}
```

#### 用户体验功能测试
```swift
// 测试首次使用引导
func testFirstTimeUserGuidance() {
    // 验证引导在首次使用时正确显示
    // 验证用户交互后引导正确隐藏
    // 验证状态正确保存到 UserDefaults
}

// 测试触感反馈
func testHapticFeedback() {
    // 验证播放开始时的触感反馈
    // 验证播放结束时的触感反馈
}
```

运行测试：

```bash
# 在 Xcode 中使用快捷键 Cmd+U
# 或使用 xcodebuild 命令行工具
xcodebuild test -project MotionPhotoConverter.xcodeproj -scheme MotionPhotoConverter -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 文档

良好的文档对于项目的可维护性和可用性至关重要。贡献者应该：

- 为新功能添加或更新文档
- 确保代码中的注释清晰且最新
- 更新 README.md 和其他相关文档

文档应该简洁、清晰，并提供足够的信息让其他开发者理解代码的目的和使用方法。

## 发布流程

项目维护者负责发布新版本。发布流程如下：

1. 从 `develop` 分支创建发布分支（`release/x.y.z`）
2. 在发布分支上进行最终测试和修复
3. 更新版本号和更新日志
4. 合并发布分支到 `main` 和 `develop`
5. 在 `main` 分支上创建版本标签
6. 在 GitHub 上创建发布说明
7. 提交到 App Store（如果适用）

## 社区

我们鼓励贡献者积极参与项目社区：

- 回答其他用户的问题
- 参与讨论和决策
- 帮助审查其他贡献者的代码
- 分享项目和您的贡献

## 致谢

再次感谢您考虑为 Motion2Live 项目做出贡献！您的时间和专业知识对于改进这个项目非常宝贵。

如果您有任何问题或需要帮助，请随时联系项目维护者或在 GitHub 上创建 Issue。