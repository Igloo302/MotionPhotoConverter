# Motion2Live Design System

> 视觉规范与代码实现唯一事实源。新增或变更基础 Token / 通用组件须同步更新本文件；严禁在业务视图中硬编码魔法色值或未登记样式。

## 1. 核心视觉 Token（[ObsidianTheme.swift](Motion2Live/DesignSystem/ObsidianTheme.swift)）

### 自适应色彩体系（`AppTheme`，Obsidian Dark / Porcelain Light）
| Token | Dark | Light | 用途 |
| :--- | :--- | :--- | :--- |
| `canvas` | `#0B0D0F` | `#F4F6F9` | 主画布背景 |
| `surface0` / `surface1` / `surface2` | `#121518` / `#181B1F` / `#202429` | `#FFFFFF` / `#EBEEF3` / `#E1E6EE` | 卡片底层 / 容器层级 / 高亮容器 |
| `borderSubtle` | `#2A2F36` (95%) | `#D4DBE5` (95%) | 卡片与胶囊细描边 |
| `accent` / `accentForeground` | `#38BCE0` / `#0B0D0F` | `#0284C7` / `#FFFFFF` | 主强调色 / 主按钮前景 |
| `success` / `warning` / `danger` | `#30D158` / `#FF9F0A` / `#FF453A` | `#248A3D` / `#D97706` / `#D70015` | 语义状态色 |
| `textPrimary` / `textSecondary` / `textTertiary` | `#FAFAFA` / `#A6ADB8` / `#6B7585` | `#0F1419` / `#536070` / `#8391A2` | 主 / 次 / 辅助文字 |
| `stageBackground` | `#101316` | `#E8ECF1` | 照片与视频预览舞台衬底 |

### 圆角、排版与材质规范
- **圆角（`AppTheme.Radius`）**：`control = 14`、`card = 18`、`stage = 24`、`capsule = 27`（统一使用 `.continuous`）。
- **字体层级**：系统动态字体，数字与时间码统一使用 `.monospaced`（如 `2.40s • 30fps`、`00:01.18`）。
- **iOS 26 Liquid Glass 分层原则**：
  - **导航与浮层控制层**：悬浮工具栏、导航胶囊、主 CTA 使用 `.glassEffect(.regular.interactive())` / `.buttonStyle(.glassProminent)`，并配合 `GlassEffectContainer` 组合；低于 iOS 26 降级为 `AppTheme` 实色/半透明材质。
  - **内容层禁用玻璃**：列表、网格卡片、静态标题、非交互状态徽标严禁使用 Liquid Glass，防止玻璃叠玻璃。

## 2. 现有可复用 UI 组件清单

| 组件 / 样式 | 文件路径 | 用途 |
| :--- | :--- | :--- |
| `StudioPrimaryButtonStyle` | [ObsidianTheme.swift](Motion2Live/DesignSystem/ObsidianTheme.swift) | 底部主行动胶囊按钮（`minHeight: 52`） |
| `StudioSecondaryCapsuleButtonStyle` | [ObsidianTheme.swift](Motion2Live/DesignSystem/ObsidianTheme.swift) | 次级操作胶囊按钮（`minHeight: 44`） |
| `StudioIconCircleButton` | [ObsidianTheme.swift](Motion2Live/DesignSystem/ObsidianTheme.swift) | `40×40` 圆形图标按钮 |
| `.studioCard(cornerRadius:padding:)` | [ObsidianTheme.swift](Motion2Live/DesignSystem/ObsidianTheme.swift) | 标准卡片容器（`surface0` + `borderSubtle`） |
| `Motion2LiveBrandMark` | [HomeView.swift](Motion2Live/HomeView.swift) | `24×24` 双层液态玻璃叠卡矢量品牌标志（自适应深浅色） |
| `SupportedBrandsView` | [SupportedBrandsView.swift](Motion2Live/Views/Components/SupportedBrandsView.swift) | 2 列品牌兼容矩阵卡片 |
| `KeyframePickerSheet` | [KeyframePickerSheet.swift](Motion2Live/Views/Components/KeyframePickerSheet.swift) | 封面关键帧微调弹窗（胶卷缩略图时间轴 + 毫秒时间码） |
| `PlayerView` | [PlayerView.swift](Motion2Live/Views/Components/PlayerView.swift) | `AVPlayer` 视频播放视图 |
| `PhotoPicker` | [PhotoPicker.swift](Motion2Live/Views/Components/PhotoPicker.swift) | 系统相册单选/多选选择器 |

## 3. 交互与四态约定（及目标视觉基线）

- **Loading（加载态）**：全屏解析使用半透明遮罩 + `ProgressView().tint(AppTheme.accent)`；行内/网格处理中态使用局部进度指示与高亮描边。
- **Empty（空态）**：首页采用居中叠加照片卡组 + 极简引导文案 + 底部主 CTA；无有效动态照片时通过系统 `Alert` 提示。
- **Error（报错态）**：统一使用 `AppTheme.danger` 图标/文案与系统 `Alert` 展示本地化错误；相册权限拒绝提供「前往设置」直达按钮。
- **反馈与目标演进基线**：触感统一经 `AppHaptics`；后续 UI 迭代以 Figma 定稿为准——`BatchConvertView` 演进为 **3×3 纯照片缩略图网格**（去文件名），`MotionPhotoView` 演进为 **全屏出血舞台 + 悬浮 Liquid Glass 导航/工具栏**。

## 4. 视觉源与编码红线

- **核心 Figma 视觉源**：[Motion2Live — Key Screens](https://www.figma.com/design/JK41SuSED8UAlRZJrnvtUS/Untitled?node-id=43-2)（`01 · Motion2Live — Key Screens` / `02 · Design System & Components`）。
- **编码红线**：严禁硬编码魔法色值或随手新造未登记样式；涉及 `UserDefaults` / 相册权限变更须同步核对 `PrivacyInfo.xcprivacy` 与 `Info.plist`。
