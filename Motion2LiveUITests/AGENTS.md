# Motion2LiveUITests/AGENTS.md — UI 自动化测试模块规范

## 1. 技术栈与职责边界
- **技术栈**：XCUITest（`XCUIApplication`、`XCTestCase`）。
- **职责边界**：验证应用冷启动、主界面核心控件可交互性（`HomeView` 导航栏与主操作按钮存在性）及启动性能基线（`XCTApplicationLaunchMetric`），确保多语言及不同屏幕形态下首屏不崩溃、无遮挡。
- **禁止事项**：严禁删改原有启动与主控件断言以强行通过测试；UI 测试不得依赖外部网络或未受控的真实相册数据。

## 2. 确定性验证命令
```bash
DESTINATION=$(xcrun simctl list devices available iPhone | grep -m1 -oE '[0-9A-F-]{36}')
xcodebuild test -project Motion2Live.xcodeproj -scheme Motion2Live -destination "platform=iOS Simulator,id=${DESTINATION}" -only-testing:Motion2LiveUITests CODE_SIGNING_ALLOWED=NO
```

## 3. 测试资源隔离要求
- **运行环境隔离**：UI 测试仅在 iOS Simulator 沙盒内执行，若需注入测试开关应通过 `XCUIApplication().launchArguments` / `launchEnvironment` 传递，避免修改宿主机持久化状态或触发真机相册写入。
- **权限弹窗隔离**：避免在基础启动用例中触发不可控的系统相册授权弹窗阻塞流程。
