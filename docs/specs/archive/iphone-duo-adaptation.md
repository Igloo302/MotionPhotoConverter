# Spec: iPhone Duo 体验增强态适配规划

- **Feature Key**: `iphone-duo-adaptation`
- **Status**: `Draft (Ready for Review / Build)`
- **Target Branch / Isolation**: `feat/iphone-duo-adaptation`（按 `AGENTS.md` 在主仓库同级 worktree 开发）
- **Minimum Deployment Target**: `iOS 16.0`（保留向下兼容；iPhone Duo 专属能力通过 `#available(iOS 27.1, *)` 门控启用）

---

## 1. 背景与目标 (Goals & Non-Goals)

### 1.1 设备硬件与系统基线（已通过本地 SDK 与 Simulator Profile 实测确认）

依据 Xcode iOS 27.2 SDK 与 [capabilities.plist](file:///Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone%20Duo.simdevicetype/Contents/Resources/capabilities.plist) 实测参数：

| 物理形态 | 显示屏 ID | 逻辑尺寸 (`@3x`) | 宽高比 | 色域 | 圆角与硬件特征 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **折叠外屏** | `LCD` (`primary`, ID `1`) | **`466 × 678 pt`** | `1 : 1.45` | **P3** | 靠铰链侧圆角 `8pt`，外侧 `59pt`（非对称），带灵动岛；高度显著偏矮 |
| **展开内屏（竖向）** | `LCD-1` (`primary-1`, ID `3`) | **`669 × 951 pt`** | `1 : 1.42` | **sRGB** | 四角统一 `55pt`；`idiom` 仍为 `phone` |
| **展开内屏（横向）** | `LCD-1` (`nativeOrientation: 270`) | **`951 × 669 pt`** | `1.42 : 1` | **sRGB** | 高仅 `669pt`；可能触发 iOS 27.1+ 侧边竖向系统栏（Vertical Bar） |

系统能力关键点：
1. **铰链状态**：iOS 27.1+ SwiftUI 提供 `View.onHingeChange(_:)` + `DeviceHinge`（`.closed` / `.partiallyOpen` / `.fullyOpen` + `angle`）；UIKit 提供 `UIHingeInteraction` / `UIHinge`。
2. **竖向系统栏（Vertical Bar）**：iOS 27.1+ 提供 `UITraitCollection.verticalBarEdge`、`UIViewController.preferredVerticalBarBehavior`、SwiftUI `toolbarVerticalBehavior(_:)` 与 `ToolbarItemAxisBehavior`。
3. **多任务标识**：`DeviceSupportsEnhancedMultitasking` 为 `False`，设备形态切换主要体现为 **外屏 ↔ 内屏切换**、**内屏横竖屏旋转** 及 **铰链半开（Flex / Tabletop）姿态**。

### 1.2 核心目标 (Goals)
1. **三态断点精准覆盖**：修正当前 `669pt`（内屏竖向）未命中宽屏分栏与 `669~678pt`（外屏 / 内屏横屏）高度溢出问题，使 5 个核心页面在折叠外屏、展开全平、半开桌面三种姿态下均不遮挡、不裁切、跨中缝有安全留白。
2. **铰链半开体验增强（Flex / Tabletop Mode）**：在 iOS 27.1+ 设备上感知 `DeviceHinge.Status.partiallyOpen`，将“预览舞台”与“控制/时间轴区”分置折痕两侧，提供影棚级桌面免手持查看与选帧体验。
3. **开合切换零状态丢失**：外屏与内屏动态切换时，不重跑耗时解析任务、不中断 `AVPlayer` 预览、不丢失 `KeyframePickerSheet` 拖拽位置与 `BatchConvertView` 转换进度，且绝不误清理临时文件。
4. **外屏非对称圆角与系统栏安全兼容**：严格基于安全区与可读宽度排布悬浮控件，避免被外屏 `59pt` 圆角或系统 Vertical Bar 状态栏挤压遮挡。

### 1.3 非目标 (Non-Goals)
- 不改变动态照片底层解析（[MotionPhotoProcessor.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/Models/MotionPhotoProcessor.swift)）与媒体导出（[MediaExportService.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/Services/MediaExportService.swift)）的核心编解码契约。
- 不将最低支持版本从 `iOS 16.0` 提高到 `iOS 27.1`；所有 27.1+ 新 API 均必须包裹 `#available(iOS 27.1, *)` 并在低版本优雅降级。
- 不在此需求中开启 `PortraitUpsideDown` 倒置旋转（维持 `project.pbxproj` 中 `UISupportedInterfaceOrientations_iPhone` 现有配置，如未来实机验证半开/帐篷姿态需要再单独立项评估）。

---

## 2. 现状缺口分析 (Gap Analysis against Current Code)

| 模块与代码位置 | 当前实现 | 在 iPhone Duo 下的具体缺陷 |
| :--- | :--- | :--- |
| [ObsidianTheme.swift:133-145](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/DesignSystem/ObsidianTheme.swift#L133-L145) | `isWideSplit = width >= 680 \|\| (verticalSizeClass == .compact && width >= 560)` | 内屏竖屏宽度 `669pt < 680pt` 且 `verticalSizeClass == .regular`，`isWideSplit` 误判为 `false`，导致展开态退回居中单栏并可能跨中缝。 |
| [MotionPhotoView.swift:183](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/Views/MotionPhotoView.swift#L183) | `.presentationDetents([.height(540), .large])` | 外屏高 `678pt`、内屏横屏高 `669pt`，固定 `540pt` 占满 80% 高度，几乎无法区分中/大 detent，且内部舞台压缩严重。 |
| [KeyframePickerSheet.swift:59-154](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/Views/Components/KeyframePickerSheet.swift#L59-L154) | 固定 `VStack`（顶部标题 + `190~230pt` 预览 + `86pt` 胶卷轨 + 底部双行按钮） | 在 `669pt` 高度（内屏横屏/外屏）下垂直溢出风险高；在 `951pt` 宽度下浪费横向空间，未提供宽屏左右分栏排布。 |
| [HomeView.swift:38-42, 313-324](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/HomeView.swift#L38-L42) | 顶栏隐藏原生 `NavigationBar` 并自绘 `topNavigationBar`；`portrait` 扣除 `340pt` 计算 `heroDeckScale` | 外屏（`466×678`）仅余 ~338pt 扣除余量导致画廊卡片偏紧；自绘顶栏在 iOS 27.1 Vertical Bar 生效时无法自动迁移至系统侧栏。 |
| [MotionPhotoView.swift:99-120](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/Views/MotionPhotoView.swift#L99-L120) | 无 `DeviceHinge` 感知，全屏居中舞台 + 底部悬浮 Dock | 半开姿态（`.partiallyOpen`）时底部 Dock 与长按提示可能横跨弯折中缝；展开态横屏未能利用左右或上下分区。 |
| [HomeView.swift:38-42](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/HomeView.swift#L38-L42) & [MotionPhotoView.swift:67-120](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/Views/MotionPhotoView.swift#L67-L120) | 通过 `if / else` 切换 `portraitEditorialLayout` 与 `wideEditorialLayout` | 切换分支会销毁重建子视图树；若后续在 `MotionPhotoView` 或 `KeyframePickerSheet` 中使用条件分支而不固定视图 identity，开合屏会导致局部 `@State` 重置。 |

---

## 3. 系统架构、数据流与接口设计 (Architecture, Data Flow & Interfaces)

### 3.1 铰链状态抽象层（隔离 iOS 27.1+ SDK）

在 [ObsidianTheme.swift](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/DesignSystem/ObsidianTheme.swift) 或新增 `Motion2Live/DesignSystem/DuoAdaptation.swift` 中定义平台无关值类型，确保任何视图都能在 `iOS 16.0` 下无条件编译：

```swift
enum DuoHingeStatus: Equatable, Sendable {
    case unavailable   // 非折叠设备或 iOS < 27.1
    case closed        // 合盖使用外屏
    case partiallyOpen // 半开姿态（Flex / Tabletop，建议分屏避让折痕）
    case fullyOpen     // 180° 完全展开
}

struct HingeStateSnapshot: Equatable, Sendable {
    let status: DuoHingeStatus
    let angleDegrees: Double

    static let unavailable = HingeStateSnapshot(status: .unavailable, angleDegrees: 0)

    /// 处于有效半开夹角区间（例如 60° ~ 155°）时启用折屏分栏体验
    var isFlexTabletopPosture: Bool {
        status == .partiallyOpen
    }
}
```

View 观察修饰器（桥接 SwiftUI 原生 `.onHingeChange`）：
```swift
extension View {
    func observeDeviceHinge(_ binding: Binding<HingeStateSnapshot>) -> some View
}
```
- **iOS 27.1+ 实现路径**：调用 `.onHingeChange { _, newContext in ... }`，将 `DeviceHinge.Status`（`.closed` / `.partiallyOpen` / `.fullyOpen`）及 `angle.degrees` 映射为 `HingeStateSnapshot` 并防抖更新（角度微小抖动 < `2°` 且 `status` 不变时不触发重绘）。
- **iOS 16.0–27.0 实现路径**：保持 `.unavailable`，零运行时开销。

---

### 3.2 自适应布局决策模型 (`AdaptiveLayoutMetrics`)

升级现有 `AdaptiveLayoutMetrics`（[ObsidianTheme.swift:127-178](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/DesignSystem/ObsidianTheme.swift#L127-L178)），将“设备尺寸 + SafeArea + 铰链状态”收口为纯计算属性（便于脱离 UI 直接单元测试）：

```swift
enum DuoLayoutMode: Equatable {
    case compactVertical          // 标准 iPhone 竖屏 / Duo 外屏 (466×678)
    case compactShortLandscape    // 矮横屏（如普通 iPhone 横屏）
    case unfoldedWideSplit        // Duo 内屏展开或 iPad 宽屏（含 669×951 竖向展开 & 951×669 横向展开）
    case hingeFlexSplit           // Duo 半开姿态：主预览区 + 独立控制区避让折痕
}

struct AdaptiveLayoutMetrics: Equatable {
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let horizontalSizeClass: UserInterfaceSizeClass?
    let verticalSizeClass: UserInterfaceSizeClass?
    let hinge: HingeStateSnapshot

    // 核心决策属性
    var layoutMode: DuoLayoutMode { ... }
    var isCompactShortScreen: Bool { containerSize.height <= 700 }
    var isWideSplit: Bool { ... }
    var hingeAvoidanceGap: CGFloat { ... }        // 跨越物理折痕时的中心留白间距（建议 24–32pt）
    var heroDeckScale: CGFloat { ... }
    var batchGridColumns: Int { ... }
    var floatingDockMaxWidth: CGFloat { ... }
    var preferredKeyframeDetents: [PresentationDetent] { ... } // 避免在 669~678pt 矮屏写死 .height(540)
}
```

**关键断点规则校准**：
1. **外屏 (`466 × 678 pt`)**：`width < 560 && height <= 700` → `compactVertical` + `isCompactShortScreen = true`。
   - 收紧垂直间距：减少无效 `Spacer` 与 Hero 卡片缩放余量；
   - 外屏大圆角安全：底部浮动操作区及右上角按钮保留基于 `safeAreaInsets` 的最小内边距（`max(20, maxTrailingSafeArea + 12)`），防止靠近右下 `59pt` 圆角处的胶囊视觉发紧。
2. **内屏竖向展开 (`669 × 951 pt`)**：
   - 将原 `isWideSplit` 阈值从 `680` 下调评估为：当 `hinge.status == .fullyOpen || hinge.status == .partiallyOpen` 时或 `width >= 640` 时允许双区/网格展开；但若高度充足（`951pt`）且横宽相对紧凑（`669pt`），**HomeView** 与 **LabView** 需显式处理“上下双区避让中线”或“宽屏双列（每列宽 `(669 - 2*24 - 28) / 2 ≈ 296pt`，足够清晰展示左图卡与右文案/操作）”。
3. **内屏横向展开 (`951 × 669 pt`)**：
   - `width >= 680` 且 `height <= 700` → `unfoldedWideSplit` + `isCompactShortScreen = true`。
   - 必须启用双列/左右分栏（左预览 + 右操作），把原本纵向堆叠的顶栏+预览+底栏高度压力转为横向分配，保证单屏无滚动即可点击所有主行动按钮。
4. **半开姿态 (`hinge.isFlexTabletopPosture == true`)**：
   - 依据当前容器宽高比自动决定切分轴向（若水平折痕 / 竖直握持 `height > width` → 上半区预览、下半区控制且中间保留 `hingeAvoidanceGap`；若垂直折痕 / 横向握持 `width >= height` → 左半区预览、右半区控制且中间保留 `hingeAvoidanceGap`）。

---

### 3.3 核心数据流与跨形态状态连续性

```text
[物理开合 / 旋转 / 折弯]
   ├─ GeometryReader (containerSize + safeAreaInsets)
   ├─ Environment (horizontalSizeClass, verticalSizeClass)
   └─ .observeDeviceHinge (HingeStateSnapshot: closed / partiallyOpen / fullyOpen)
          │
          ▼
   AdaptiveLayoutMetrics（纯值类型计算，零副作用）
          │
          ├─ HomeView: 共享单一 HeroPhotoDeckStage 状态与 HomeViewModel（不因布局切换销毁 VM）
          ├─ MotionPhotoView: 提取预览舞台与控制坞为子组件，AVPlayer & loaded data 持有在统一外层 @State，
          │                   切屏/转屏仅改父容器 Axis (VStack <-> HStack)，绝不重新触发 .task / .onDisappear
          ├─ KeyframePickerSheet: 根据 isCompactShortScreen 与 isWideSplit 切换为「左右分栏选帧」或「动态占比高度」
          └─ BatchConvertView: 保持 BatchConvertViewModel 串行任务与临时 URL 列表不变，仅重排 LazyVGrid 列数 (3/4/5/6)
```

**关键防坑机制**：
- **禁止通过 `if mode == ... { ViewA() } else { ViewB() }` 破坏同源播放器/弹窗生命周期**：在 `MotionPhotoView` 中，`PlayerView(player:)` 与 `Image(uiImage:)` 应通过单一视图树 + `AnyLayout`（`HStackLayout` / `VStackLayout`）或统一 `frame` 定位切换排布，避免 SwiftUI 销毁重建 `PlayerUIView` 导致播放闪烁或重置进度。
- **临时文件保护不变**：`MotionPhotoView` 的 `.onDisappear` 仅放在最外层 `NavigationStack` 目的页根节点上，防止内部条件容器切换误删 `previewVideoURL` 或 `sourceURL`。

---

## 4. 子任务拆解与实施计划 (Subtasks)

| 编号 | 任务名称 | 涉及文件 | 核心实现要点 | 工作量 | 依赖 |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **T1** | **建立 `HingeStateSnapshot`、`onHingeChange` 桥接与升级 `AdaptiveLayoutMetrics`** | `Motion2Live/DesignSystem/ObsidianTheme.swift` | 定义 `DuoHingeStatus` / `HingeStateSnapshot` / `DuoLayoutMode`；补充 `observeDeviceHinge`（`#available(iOS 27.1, *)` 桥接 `.onHingeChange` 并对 `< 2°` 角度变化去抖）；校准 `669pt` 宽断点、`isCompactShortScreen` 矮屏判定与 `hingeAvoidanceGap`。 | M | 无 |
| **T2** | **补充 `AdaptiveLayoutMetrics` 纯逻辑单元测试** | `Motion2LiveTests/Motion2LiveTests.swift` | 覆盖 `466×678`（外屏）、`669×951`（内屏竖向）、`951×669`（内屏横向）、`partiallyOpen`（半开）四种场景的 `layoutMode`、`batchGridColumns`、`heroDeckScale`、`preferredKeyframeDetents` 断言。 | S | T1 |
| **T3** | **`HomeView` 与 `AboutSheetView` Duo 全形态适配** | `Motion2Live/HomeView.swift` | 外屏（`678pt` 高）紧缩顶部/底部留白与 `heroDeckScale`；内屏竖/横展开（`669×951` & `951×669`）校验 `wideEditorialLayout` 中缝留白与文字可读宽；使用 `AnyLayout` 避免开合切换时重建 `HeroPhotoDeckStage`；`AboutSheetView` 在宽屏限制最大表单宽度并居中对齐。 | M | T1 |
| **T4** | **`MotionPhotoView` 半开分屏体验增强与连续性加固** | `Motion2Live/Views/MotionPhotoView.swift`、`Motion2Live/Views/Components/PlayerView.swift` | 使用 `.observeDeviceHinge`；在半开（`isFlexTabletopPosture`）或宽屏横握（`951×669`）下，支持将预览舞台与 `floatingBottomDock`（格式切换+封面帧+主 CTA）分布于折痕/左右两侧并留出 `hingeAvoidanceGap`；以单一视图树重构舞台布局，保证开合屏不重触发 `.task` 与 `PlayerUIView` 重建。 | L | T1 |
| **T5** | **`KeyframePickerSheet` 矮屏与宽屏自适应布局** | `Motion2Live/Views/Components/KeyframePickerSheet.swift`、`Motion2Live/Views/MotionPhotoView.swift` | 将固定 `.height(540)` 替换为随容器尺寸计算的动态 detent（外屏/矮横屏使用 `.fraction(0.88)` + `.large` 或 `.large`）；在 `width >= 640 && height <= 700`（如 Duo 内屏横屏 `951×669`）下采用“左实时帧预览 + 右时间码/7帧胶卷轴/确认按钮”双列布局，消除矮屏溢出。 | M | T1 |
| **T6** | **`BatchConvertView`、`LabView` 适配及系统 Vertical Bar 兼容校验** | `Motion2Live/BatchConvertView.swift`、`Motion2Live/LabView.swift` | 校验 `BatchConvertView` 4 列（`669pt`）/ 5 列（`951pt`）下缩略图、进度浮条与关闭按钮对齐；确保 `CustomLivePhotoView` 在 `669pt` / `951pt` 双列卡片对折痕留白充足；在 iPhone Duo Simulator 上检查横竖屏与系统状态栏/Vertical Bar 区域无重叠。 | M | T1 |
| **T7** | **iPhone Duo Simulator 多屏多态全量截图与回归验证** | `Motion2LiveUITests/` / `xcrun simctl` | 在 `iPhone Duo`（`LCD` `--display=1` 与 `LCD-1` `--display=3`）分别抓取首页、关于、批量、详情、选封面帧 5 页截图；人工/自动核对零裁切、零重叠，并运行 `xcodebuild test` 全绿。 | M | T2–T6 |

---

## 5. 边界与异常场景评估 (Edge Cases & Risk Assessment)

1. **内屏竖屏 `669 × 951 pt` 刚好处于手机与平板边界**
   - *风险*：宽度 `669pt` 若强行用左右双列（如 `HomeView` 左图右文）每侧仅约 `300pt`，文案在德语/法语等长词条语种下容易换行过多；若完全用居中单栏，正中央内容又会跨过纵向折叠中线。
   - *处理策略*：针对 `669 × 951` 采用“上舞台 / 下控制或带中缝安全区检查的自适应双列（限制主标题 `.minimumScaleFactor(0.78)` + 允许 2–3 行）”，并在英/中/德三语下实测截断情况。
2. **外屏（`678pt`）与内屏横屏（`669pt`）极矮高度下的 Modal Detent 冲突**
   - *风险*：`KeyframePickerSheet` 现有 `.height(540)` 在 `669pt` 屏幕上占 81%，导致 `.height(540)` 与 `.large` 视觉几乎无差异且键盘/手势拖拽体验差。
   - *处理策略*：由 `AdaptiveLayoutMetrics` 决定 detent，矮屏直接采用单 detent `.large`（配合内部紧凑或左右双栏排版），常规高屏才保留 `[.height(540), .large]`。
3. **iOS 27.1+ 竖向系统栏（Vertical Bar）与自定义隐藏导航栏的冲突**
   - *风险*：目前所有页面使用 `.toolbar(.hidden, for: .navigationBar)` 自绘顶栏，在 Duo 横向展开态若系统显示侧边 Vertical Bar（占用 leading/trailing 安全区并缩短水平有效宽度），自绘悬浮栏若忽略 `safeAreaInsets` 会与系统图标碰撞或偏移。
   - *处理策略*：顶部/底部自绘栏严禁使用 `.ignoresSafeArea()` 覆盖水平边缘；评估在 `MotionPhotoView` / `BatchConvertView` 外层或 iOS 27.1+ 场景下结合 `@available(iOS 27.1, *) .toolbarVerticalBehavior(.disabled)`（针对全屏沉浸式影像检视器，Apple SDK `UIViewController.h:793` 明确建议全屏媒体播放器场景可禁用竖向栏以维持水平视觉对称）。
4. **半开角度传感器高频抖动引发 SwiftUI 布局震荡**
   - *风险*：`DeviceHinge.angle` 在用户缓慢开合手机时持续连续回调，若每次角度微变都修改布局状态会导致 `AnyLayout` / `AVPlayer` 频繁重绘卡顿。
   - *处理策略*：UI 布局只响应离散状态（`DeviceHinge.Status`: `.closed` / `.partiallyOpen` / `.fullyOpen`）的变化，不将连续的 `angle` 数值直接绑定到视图尺寸或动画驱动；角度仅记录阈值滞回（例如 `< 155°` 进入半开、`> 165°` 退回全开）防止边界反复横跳。
5. **开合屏瞬间切换导致 `AVPlayer` 重建或临时预览文件被误删**
   - *风险*：如果外层用 `if/else` 替换整棵视图树，触发 SwiftUI `.onDisappear`，[MotionPhotoView.swift:161-164](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/Views/MotionPhotoView.swift#L161-L164) 会执行 `cleanupPlaybackResources()` 并删除 `previewVideoURL` 与 `sourceURL`，导致展开瞬间黑屏报错。
   - *处理策略*：`NavigationStack` 与 `MotionPhotoView` 根视图保持统一 identity，布局切换仅在内部通过 `AnyLayout` 或位置 modifier 调整容器方向。
6. **外屏 P3 与内屏 sRGB 色域切换**
   - *风险*：用户在 P3 外屏看到的高饱和/HDR 实况照片，展开至 sRGB 内屏时视觉饱和度回落，可能误以为导出丢色。
   - *处理策略*：确保导出管线与封面抽帧（`MediaExportService.extractCoverFrameData`）只从原始文件/视频数据中读取并保留原图 ICC/EXIF，绝对不经过当前屏幕渲染缓冲二次采样。
7. **System Photo Picker (`PHPickerViewController`) 与 `Alert` 在跨屏切换时的表现**
   - *风险*：`PhotoPicker` 在折叠外屏弹出，用户在选图期间展开至内屏，`PHPickerViewController` 会由系统重新排版；若此时 `HomeView` 视图树发生重组，需确保 `isShowingPhotoPicker` 与进度遮罩 `isAnalyzingPhotos` 不丢失回调。
   - *处理策略*：所有弹出状态（`isShowingPhotoPicker`、`isShowingBatchView`、`selectedImageURL`）均托管在 `HomeViewModel` 中，且 `.sheet` 修饰符挂载在 `NavigationStack` 根部（[HomeView.swift:57-94](file:///Users/jyshen/Library/CloudStorage/OneDrive-个人/Projects/Motion2Live/Motion2Live/HomeView.swift#L57-L94)），不挂载在随布局切换的内部子节点上。
8. **外屏靠铰链侧 `8pt` 与外侧 `59pt` 非对称圆角**
   - *风险*：外屏右下角圆角高达 `59pt`，底部悬浮主按钮若贴底距不足且圆角小于外框，会产生视觉“撞角”。
   - *处理策略*：底部浮层与主胶囊按钮圆角（`Capsule` 27pt）保持居中对称并确保底部留白 ≥ 16pt + safeArea bottom inset。

---

## 6. 验收清单 (Definition of Done)

- [x] **T1**: `AdaptiveLayoutMetrics` 支持 `DuoLayoutMode` 与 `#available(iOS 27.1, *)` `onHingeChange` 桥接，最低兼容目标 `iOS 16.0` 编译 0 警告。
- [x] **T2**: `Motion2LiveTests` 新增并全绿通过 `iPhone Duo`（外屏 `466×678`、内屏竖屏 `669×951`、内屏横屏 `951×669`、半开态）布局参数与断点计算测试。
- [x] **T3**: `HomeView` 与 `AboutSheetView` 在 Duo 外屏、内屏竖/横屏下主标题、Hero 叠卡、底部按钮无遮挡、无截断。
- [x] **T4**: `MotionPhotoView` 在外屏/内屏切换期间 `AVPlayer` 与视频加载状态不中断、临时文件不误删；半开态或宽屏下控制台与预览舞台分离且避让中缝。
- [x] **T5**: `KeyframePickerSheet` 在 `669~678pt` 矮屏中采用适配 detent 与紧凑/左右双栏排版，胶卷时间轴拖动手感流畅、无溢出。
- [x] **T6**: `BatchConvertView`（3/4/5 列网格、进度浮条）与 `LabView`（双列步骤卡片）在 Duo 全形态排版工整，长按/点击热区 ≥ 44pt。
- [x] **T7**: 在 `iPhone Duo` 模拟器实测 `--display=1`（外屏）与 `--display=3`（内屏）真实渲染截图并验证全量单元测试通过（`xcodebuild test` 全绿）。

---

## 7. 待确认产品决策（Open Questions for Execution）

1. **半开桌面态（`.partiallyOpen`）的方向策略**：当用户在 `MotionPhotoView` 中半开折屏使用“预览+选封面”时，是否希望默认开启**横折上屏预览 / 下屏调参**（对应 `UISupportedInterfaceOrientations_iPhone` 允许的旋转方向），还是仅在宽屏展开时做左右分栏？
2. **`MotionPhotoView` 在 iOS 27.1 横向展开态是否显式禁用系统 Vertical Bar**：Apple SDK `UIViewController.h` 建议全屏媒体查看器可返回 `.disabled`（SwiftUI `.toolbarVerticalBehavior(.disabled)`）以保持沉浸对称。如无异议，Builder 将在 `MotionPhotoView` 启用该选项，而其余页面保持 `.automatic`。

---

## Handoff Notes

- **当前状态**：已完成规划与接口/边界设计，文档已落盘至 `docs/specs/iphone-duo-adaptation.md`。本阶段严格遵守只读代码原则，**未修改任何 Swift 源码或 `.xcodeproj` 工程文件**。
- **已核查文件**：
  - 设备配置与 SDK：`/Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone Duo.simdevicetype/Contents/Resources/capabilities.plist`、`UIHinge.h`、`UIHingeInteraction.h`、`UIVerticalBarEdge.h`、`UIArrangementViewController.h`、`UISplitArrangement.h`、`SwiftUICore.swiftinterface`
  - 工程源码：`Motion2Live/DesignSystem/ObsidianTheme.swift`、`Motion2Live/HomeView.swift`、`Motion2Live/HomeViewModel.swift`、`Motion2Live/Views/MotionPhotoView.swift`、`Motion2Live/Views/Components/KeyframePickerSheet.swift`、`Motion2Live/BatchConvertView.swift`、`Motion2Live/LabView.swift`、`Motion2Live/Services/MediaExportService.swift`、`Motion2Live.xcodeproj/project.pbxproj`
- **下一步动作（面向 Builder）**：
  1. 若用户确认 §7 两个决策（或按推荐默认执行），切至独立 worktree `../Motion2Live-worktrees/iphone-duo-adaptation`（分支 `feat/iphone-duo-adaptation`）；
  2. 按 **T1 → T2 → T3 → T4 → T5 → T6 → T7** 顺序逐步实现并每步自测。
