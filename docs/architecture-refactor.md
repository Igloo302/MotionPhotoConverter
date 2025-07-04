# 动态照片处理架构重构

## 概述

为了更好地支持不同品牌的动态照片格式，我们重构了原有的处理逻辑，采用了基于协议的可扩展架构。

## 新架构设计

### 核心组件

#### 1. MotionPhotoProcessorProtocol
定义了处理动态照片的标准接口：
- `canProcess(xmpInfo:)` - 检测是否能处理特定格式
- `processMotionPhoto(data:xmpInfo:)` - 处理动态照片数据
- `calculateStillImageTime(...)` - 计算静态图片时间

#### 2. BaseMotionPhotoProcessor
提供基础实现和通用逻辑的抽象基类。

#### 3. 品牌特定处理器
- **XiaomiMotionPhotoProcessor** - 处理小米动态照片（已完全实现）
- **PixelMotionPhotoProcessor** - 处理Pixel动态照片（已完全实现）
- **SamsungMotionPhotoProcessor** - 处理三星动态照片（已完全实现）

#### 4. MotionPhotoProcessorFactory
工厂类，负责根据XMP数据自动选择合适的处理器。

### 数据结构

#### MotionPhotoBrand
```swift
enum MotionPhotoBrand: String, CaseIterable {
    case xiaomi = "Xiaomi"
    case pixel = "Pixel"
    case samsung = "Samsung"
    case unknown = "Unknown"
}
```

#### MotionPhotoData
```swift
struct MotionPhotoData {
    let imageData: Data
    let videoData: Data
    let stillImageTime: Int
    let brand: MotionPhotoBrand
    let videoOffset: Int?
    let presentationTimestamp: Double?
}
```

## 重构前后对比

### 重构前
- 所有品牌的处理逻辑混合在一个函数中
- 硬编码的条件判断
- 难以维护和扩展
- 代码重复

### 重构后
- 每个品牌有独立的处理器
- 清晰的接口定义
- 易于添加新品牌支持
- 代码模块化，便于测试

## 扩展新品牌支持

要添加对新品牌动态照片的支持，只需要：

1. 在 `MotionPhotoBrand` 枚举中添加新品牌
2. 创建继承自 `BaseMotionPhotoProcessor` 的新处理器类
3. 实现 `canProcess` 和 `processMotionPhoto` 方法
4. 在 `MotionPhotoProcessorFactory` 中注册新处理器

### 示例：添加华为支持

```swift
// 1. 添加枚举值
enum MotionPhotoBrand: String, CaseIterable {
    // ... 现有品牌
    case huawei = "Huawei"
}

// 2. 创建处理器
class HuaweiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() {
        super.init(brand: .huawei)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        // 检测华为特有的XMP标签
        return xmpInfo["Huawei:MotionPhoto"] != nil
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // 实现华为动态照片的处理逻辑
        // ...
    }
}

// 3. 在工厂中注册
class MotionPhotoProcessorFactory {
    private static let processors: [MotionPhotoProcessorProtocol] = [
        XiaomiMotionPhotoProcessor(),
        PixelMotionPhotoProcessor(),
        SamsungMotionPhotoProcessor(),
        HuaweiMotionPhotoProcessor() // 添加新处理器
    ]
}
```

## 当前支持状态

| 品牌 | 状态 | 说明 |
|------|------|------|
| 小米 | ✅ 完全支持 | 新旧版本动态照片均支持 |
| Pixel | ✅ 完全支持 | 支持GContainer:ItemLength格式 |
| 三星 | ✅ 完全支持 | 支持Directory Item和GCamera两种格式 |

## UI 改进

- 添加了 `SupportedBrandsView` 组件，在主界面显示支持的品牌信息
- 用户可以清楚地了解当前支持哪些品牌的动态照片
- 所有支持的格式均已完全实现，提供完整的功能体验

## 代码质量提升

1. **单一职责原则** - 每个处理器只负责一个品牌
2. **开放封闭原则** - 对扩展开放，对修改封闭
3. **依赖倒置原则** - 依赖抽象而非具体实现
4. **可测试性** - 每个处理器可以独立测试
5. **可维护性** - 代码结构清晰，易于理解和修改

## 下一步计划

1. 添加单元测试覆盖所有品牌处理器
2. 性能优化和内存使用优化
3. 错误处理和用户体验改进
4. 支持更多设备厂商的动态照片格式
5. 批量处理功能