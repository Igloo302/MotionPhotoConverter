# Spec: UI 与 Figma Liquid Glass 定稿对齐

- **日期**: 2026-11-25
- **分支 / Worktree**: `feat/ui-figma-liquid-glass-sync`
- **设计分级**: **L2**（核心页面视觉重构与 iOS 26 Liquid Glass 材质分层）
- **Figma 视觉源**: [Motion2Live — Key Screens](https://www.figma.com/design/JK41SuSED8UAlRZJrnvtUS/Untitled?node-id=43-2)
- **参考规范**: [docs/design-system.md](../design-system.md)

---

## 1. 目标与背景
当前 Figma 定稿（`01 · Motion2Live — Key Screens`）已完成 Apple iOS 26 Liquid Glass 规范升级与体验重构，而现有 SwiftUI 代码仍停留在旧版卡片/列表形态。本需求将代码全面对齐至 Figma 定稿，同时严格遵守 `#available(iOS 26, *)` 降级兼容与 **Liquid Glass 仅用于导航/浮层控制层、内容层禁用玻璃** 的 HIG 原则。

---

## 2. 变更范围与页面拆解

### 2.1 Design System 基础层（[ObsidianTheme.swift](../../Motion2Live/DesignSystem/ObsidianTheme.swift)）
- 新增 Liquid Glass 兼容封装：
  - `StudioGlassCapsuleModifier` / `.studioGlassControl()`：`#available(iOS 26, *)` 使用 `.glassEffect(.regular.interactive(), in: .capsule)`，低版本降级为 `.ultraThinMaterial` + `AppTheme.borderSubtle`。
  - `StudioGlassProminentButtonStyle`：`#available(iOS 26, *)` 优先使用 `.buttonStyle(.glassProminent)` 或带高光折射的胶囊按钮，低版本保持 `StudioPrimaryButtonStyle`。
- 保留现有 `AppTheme`、`AppHaptics`、`StudioCardModifier` 供内容层复用。

### 2.2 首页（[HomeView.swift](../../Motion2Live/HomeView.swift)）
- **状态**：顶部 `Motion2LiveBrandMark` 已对齐；需检查并确保：
  - 顶部右侧「实验室」胶囊与「更多」按钮使用 `GlassEffectContainer` + Liquid Glass 样式。
  - 中央 3 张叠加示范卡组使用 `HeroDemoLeft` / `HeroDemoCenter` / `HeroDemoRight`（如尚未替换占位渐变），卡片内 `LIVE` / `2.4s` / 波形条保持克制的暗色半透角标（**不使用** Liquid Glass）。
  - 底部「选择动态照片」主按钮升级为 `StudioGlassProminentButtonStyle`。

### 2.3 单张详情与取景舞台（[MotionPhotoView.swift](../../Motion2Live/Views/MotionPhotoView.swift)）
- **全屏出血舞台**：移除原有 `padding(16)` 与圆角卡片边框，照片/视频舞台扩展至全屏出血（`ignoresSafeArea()`），顶部与底部叠加柔和光学渐变遮罩（Scrim）保证文字可读性。
- **悬浮导航与工具栏**：
  - 左上角拍摄时间与品牌信息改为纯排版标题（去除玻璃胶囊）。
  - 右上角「切换照片 | 关闭」组合为 `GlassEffectContainer` 成组 Liquid Glass 工具胶囊。
  - 底部「格式分段切换 + 封面帧按钮 + 导出主按钮」作为悬浮控制台使用 Liquid Glass；`LIVE` 徽标与「长按画面预览动态」提示保持无玻璃静默提示。

### 2.4 批量转换（[BatchConvertView.swift](../../Motion2Live/BatchConvertView.swift)）
- **3×3 纯照片缩略图网格**：移除原有单行文件列表与文件名/大小展示，改为 `LazyVGrid` 3 列正方形缩略图网格（`18pt` 圆角、`8pt` 间距）。
- **网格四态**：
  - `pending`：左下角展示静默时长微标（无玻璃）。
  - `processing`：当前项高亮 `AppTheme.accent` 描边 + 居中圆形进度环，未处理项柔和降暗。
  - `success`：右上角展示绿色 `✓` 徽章。
  - `failed`：右上角展示红色错误徽章，点击弹窗查看详情。
- **导航与底部栏**：左上角关闭按钮与底部操作/进度栏使用 Liquid Glass；中间格式分段控制器保持原生 `surface1/surface0` 样式（不使用玻璃）。

### 2.5 实验室（[LabView.swift](../../Motion2Live/LabView.swift)）
- 顶部返回/关闭胶囊与底部「创建实况照片」主按钮接入 Liquid Glass；内容区入口卡片与「更改图片 / 更改视频」次级按钮保持原生 `surface0/surface1` 分组样式。

---

## 3. 四态与边界检查
- **Loading**：解析遮罩、网格单项处理中进度、底部总进度胶囊均正常响应取消与状态切换。
- **Empty**：首页无权限时直接展示内置 3 张示范图，不阻断首屏体验。
- **Error**：批量单项失败可点击查看错误原因；相册权限拒绝保留「前往设置」引导。
- **兼容性**：iOS 16–25 降级为 `.ultraThinMaterial` / `AppTheme`，iOS 26+ 启用原生 Liquid Glass。

---

## 4. 验证计划
1. **编译与单元测试**：运行 `xcodebuild -project Motion2Live.xcodeproj -scheme Motion2Live -destination 'generic/platform=iOS Simulator' CODE_SIGN_ALLOWED=NO test`，确保所有测试通过。
2. **肉眼冒烟**：在 Simulator 中依次验证 Home（深/浅色）、MotionPhotoView（全屏出血与长按播放）、KeyframePickerSheet、BatchConvertView（3×3 网格三态）、LabView。
