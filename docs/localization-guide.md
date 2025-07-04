# MotionPhotoConverter 本地化指南

本文档提供 MotionPhotoConverter 应用的本地化（多语言支持）相关信息，包括当前支持的语言、本地化架构、添加新语言的流程以及本地化最佳实践。

## 目录

- [当前支持的语言](#当前支持的语言)
- [本地化架构](#本地化架构)
- [本地化工作流程](#本地化工作流程)
- [添加新语言](#添加新语言)
- [本地化测试](#本地化测试)
- [本地化最佳实践](#本地化最佳实践)
- [常见问题](#常见问题)

## 当前支持的语言

MotionPhotoConverter 目前支持以下语言：

1. 英语 (en) - 默认语言
2. 简体中文 (zh-Hans)
3. 法语 (fr)
4. 德语 (de)
5. 西班牙语 (es)
6. 日语 (ja)
7. 韩语 (ko)

## 本地化架构

MotionPhotoConverter 使用自定义的本地化架构，通过 `Localizable.swift` 文件集中管理所有本地化字符串。这种方法提供了类型安全和编译时检查，避免了使用硬编码字符串可能导致的错误。

### 核心组件

#### Localizable 结构体

`Localizable` 结构体是本地化系统的核心，它包含：

- 获取当前设备语言的方法
- 根据语言代码获取本地化字符串的方法
- 支持的语言列表

#### LocalizableKey 枚举

`LocalizableKey` 枚举定义了应用中所有需要本地化的字符串键：

```swift
enum LocalizableKey: String {
    case welcomeMessage
    case selectPhoto
    case exportOptions
    case saveAsLivePhoto
    case saveAsGIF
    case saveAsVideo
    case processingMessage
    case successMessage
    case errorMessage
    case notMotionPhotoError
    // 更多键...
}
```

#### 语言字典

每种支持的语言都有一个对应的字典，将 `LocalizableKey` 映射到该语言的字符串：

```swift
private let english: [LocalizableKey: String] = [
    .welcomeMessage: "Welcome to MotionPhotoConverter",
    .selectPhoto: "Select Motion Photo",
    // 更多键值对...
]

private let simplifiedChinese: [LocalizableKey: String] = [
    .welcomeMessage: "欢迎使用动态照片转换器",
    .selectPhoto: "选择动态照片",
    // 更多键值对...
]

// 其他语言的字典...
```

### 使用方法

在应用中使用本地化字符串的方式：

```swift
// 在 SwiftUI 视图中
Text(Localizable.string(.welcomeMessage))

// 在其他地方
let message = Localizable.string(.errorMessage)
```

## 本地化工作流程

### 添加新的本地化字符串

1. 在 `LocalizableKey` 枚举中添加新的键：

```swift
enum LocalizableKey: String {
    // 现有键...
    case newFeatureTitle
    case newFeatureDescription
}
```

2. 在每个语言字典中添加对应的翻译：

```swift
private let english: [LocalizableKey: String] = [
    // 现有键值对...
    .newFeatureTitle: "New Feature",
    .newFeatureDescription: "This is a new feature description."
]

private let simplifiedChinese: [LocalizableKey: String] = [
    // 现有键值对...
    .newFeatureTitle: "新功能",
    .newFeatureDescription: "这是新功能的描述。"
]

// 更新其他语言字典...
```

### 更新现有翻译

要更新现有翻译，只需修改相应语言字典中的值：

```swift
private let english: [LocalizableKey: String] = [
    // 其他键值对...
    .welcomeMessage: "Welcome to the new MotionPhotoConverter",  // 更新的翻译
]
```

## 添加新语言

要添加对新语言的支持，请按照以下步骤操作：

1. 在 `Localizable.swift` 文件中添加新语言的字典：

```swift
private let italian: [LocalizableKey: String] = [
    .welcomeMessage: "Benvenuto a MotionPhotoConverter",
    .selectPhoto: "Seleziona Motion Photo",
    // 所有其他键的翻译...
]
```

2. 更新 `Language` 枚举，添加新语言：

```swift
enum Language: String {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case japanese = "ja"
    case korean = "ko"
    case italian = "it"  // 新添加的语言
}
```

3. 在 `stringForLanguage` 方法中添加新语言的处理：

```swift
private static func stringForLanguage(_ language: Language, key: LocalizableKey) -> String {
    switch language {
    case .english:
        return english[key] ?? key.rawValue
    case .simplifiedChinese:
        return simplifiedChinese[key] ?? english[key] ?? key.rawValue
    // 其他语言...
    case .italian:
        return italian[key] ?? english[key] ?? key.rawValue
    }
}
```

4. 确保所有键都有对应的翻译，可以使用英语作为回退选项。

## 本地化测试

### 模拟不同语言环境

在开发过程中，您可以通过以下方式测试不同语言：

1. **在模拟器中更改语言**：
   - 打开模拟器
   - 进入设置 > 通用 > 语言与地区
   - 添加并选择要测试的语言
   - 重启应用

2. **在代码中强制设置语言**（仅用于测试）：

```swift
// 在 AppDelegate 或应用启动时
UserDefaults.standard.set(["it"], forKey: "AppleLanguages")
UserDefaults.standard.synchronize()
```

### 检查翻译完整性

确保所有支持的语言都有完整的翻译：

1. 创建一个测试函数，检查每个语言字典是否包含所有 `LocalizableKey`：

```swift
func testAllLanguagesHaveCompleteTranslations() {
    let allKeys = LocalizableKey.allCases
    
    // 检查英语翻译
    for key in allKeys {
        XCTAssertNotNil(english[key], "Missing English translation for \(key)")
    }
    
    // 检查简体中文翻译
    for key in allKeys {
        XCTAssertNotNil(simplifiedChinese[key], "Missing Simplified Chinese translation for \(key)")
    }
    
    // 检查其他语言...
}
```

2. 运行测试，确保没有缺失的翻译。

## 本地化最佳实践

### 字符串格式化

对于包含变量的字符串，使用格式化字符串：

```swift
// 定义键
case photoCountMessage

// 英语翻译
.photoCountMessage: "You have %d photos"

// 使用方式
String(format: Localizable.string(.photoCountMessage), photoCount)
```

### 处理复数形式

不同语言有不同的复数规则。为了正确处理复数形式，可以定义多个键：

```swift
// 定义键
case photoCountZero
case photoCountOne
case photoCountMany

// 英语翻译
.photoCountZero: "No photos",
.photoCountOne: "One photo",
.photoCountMany: "%d photos"

// 使用方式
func photoCountMessage(_ count: Int) -> String {
    switch count {
    case 0:
        return Localizable.string(.photoCountZero)
    case 1:
        return Localizable.string(.photoCountOne)
    default:
        return String(format: Localizable.string(.photoCountMany), count)
    }
}
```

### 考虑文本长度变化

翻译后的文本长度可能与原文有很大差异。在设计 UI 时应考虑这一点：

- 避免固定宽度的文本容器
- 使用自动布局和灵活的容器
- 测试长文本和短文本的显示效果
- 考虑使用截断或滚动来处理过长的文本

### 避免拼接字符串

不要拼接字符串来构建句子，因为不同语言的语法和词序可能不同：

```swift
// 错误示例
let message = Localizable.string(.youHave) + " " + String(count) + " " + Localizable.string(.photos)

// 正确示例
let message = String(format: Localizable.string(.photoCountMessage), count)
```

### 本地化日期和数字

使用 `DateFormatter` 和 `NumberFormatter` 来正确格式化日期和数字：

```swift
// 格式化日期
let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .medium
dateFormatter.timeStyle = .short
let localizedDate = dateFormatter.string(from: date)

// 格式化数字
let numberFormatter = NumberFormatter()
numberFormatter.numberStyle = .decimal
let localizedNumber = numberFormatter.string(from: NSNumber(value: 1234.56))
```

## 常见问题

### 如何处理特定于语言的功能？

某些功能可能需要根据语言进行调整。您可以使用当前语言代码来实现特定于语言的逻辑：

```swift
let currentLanguage = Localizable.currentLanguage

if currentLanguage == .japanese {
    // 日语特定的处理
} else {
    // 默认处理
}
```

### 如何处理从右到左 (RTL) 的语言？

虽然当前支持的语言都是从左到右 (LTR) 的，但如果将来添加阿拉伯语或希伯来语等 RTL 语言，需要考虑以下几点：

- SwiftUI 会自动处理大部分 RTL 适配
- 使用 `HStack` 和 `VStack` 而不是绝对位置
- 测试应用在 RTL 环境下的外观和行为
- 考虑图像和图标的镜像处理

### 如何贡献翻译？

如果您想贡献新的翻译或改进现有翻译：

1. Fork 项目仓库
2. 按照上述指南添加或更新翻译
3. 提交 Pull Request，详细说明您的更改

我们欢迎社区成员帮助改进应用的本地化支持！

## 结语

良好的本地化对于提高应用的可访问性和用户体验至关重要。通过遵循本指南中的最佳实践，MotionPhotoConverter 可以为全球用户提供高质量的本地化体验。

如果您有任何关于本地化的问题或建议，请随时联系项目维护者或在 GitHub 上创建 Issue。