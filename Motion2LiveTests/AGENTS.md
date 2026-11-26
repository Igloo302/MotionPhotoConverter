# Motion2LiveTests/AGENTS.md — 单元测试模块规范

## 1. 技术栈与职责边界
- **技术栈**：XCTest（`@testable import Motion2Live`）、AVFoundation、ImageIO、UIKit。
- **职责边界**：验证多品牌动态照片识别与切分（Pixel / Samsung / Xiaomi 新旧版 / Huawei / OPPO / vivo / Universal）、XMP 与 ISOBMFF 边界容错、`MediaExportService` 产物封装（Apple Maker `"17"` 与 QuickTime `content.identifier`）、GIF 导出、封面帧元数据保留、`RecentConversionStore` 缓存上限，以及可选本地样图清单（`samples/local/manifest.json`）回归。
- **禁止事项**：严禁删改原有测试用例或弱化断言以绕过失败；`samples/local/` 为可选本地样图，缺失时仅跳过该条件用例，不得改动测试基线。

## 2. 确定性验证命令
与 `.github/workflows/ios.yml` CI 保持完全一致：
```bash
DESTINATION=$(xcrun simctl list devices available iPhone | grep -m1 -oE '[0-9A-F-]{36}')
xcodebuild test -project Motion2Live.xcodeproj -scheme Motion2Live -destination "platform=iOS Simulator,id=${DESTINATION}" -only-testing:Motion2LiveTests CODE_SIGNING_ALLOWED=NO
```

## 3. 测试资源隔离要求
- **临时文件隔离**：所有测试生成的媒体文件与临时目录必须创建在 `FileManager.default.temporaryDirectory` 下（使用 `UUID().uuidString` 隔离文件名），并在 `defer` 中删除。
- **Store 隔离**：测试 `RecentConversionStore` 时必须通过 `RecentConversionStore(directory: tempDir)` 注入临时目录，严禁调用并污染 `RecentConversionStore.shared` 的真实缓存目录。
- **无相册写入**：单元测试仅验证 `prepareLivePhotoFiles` / `createGIFFile` / `extractCoverFrameData` 等无权限依赖产物，严禁触发真实 `PHPhotoLibrary.shared().performChanges`。
