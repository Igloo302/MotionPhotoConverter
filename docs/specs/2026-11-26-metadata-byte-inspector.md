# Spec: 动态照片“文件结构”面板（File Structure & Metadata）

- **日期**: 2026-11-26
- **状态**: Draft（待确认）
- **设计门禁**: L2（需同步更新 Figma 设计稿：新增 `MetadataInspectorSheet` 弹窗与 `MotionPhotoView` 触发入口；定稿后需将 Figma Frame 链接 / Node ID 回填至本 Spec，再进入编码阶段）
- **Figma 视觉稿**: 待补充（[Motion2Live — Key Screens](https://www.figma.com/design/JK41SuSED8UAlRZJrnvtUS/Untitled?node-id=43-2)）
- **关联文档**: [docs/architecture.md](../architecture.md)、[docs/design-system.md](../design-system.md)、[docs/decisions.md](../decisions.md)

---

## 1. 目标与设计克制原则

在单图检查页（`MotionPhotoView`）中，面向有排查兼容性、了解文件内部构成或调试编码参数需求的进阶用户，提供轻量的**文件结构面板（File Structure & Metadata）**，展示：
1. **文件内部构造比例条**：按真实字节偏移与长度切分并可视化各段占比（例如 `JPEG 3.4 MB | GainMap 0.3 MB | MP4 1.9 MB | SEF 123 B`）。
2. **视频流技术规格**：编码格式（`HEVC` / `H.264` 等 FourCC 映射）、分辨率、帧率（fps）与时长。
3. **原始 XMP 关键字段**：已解析的核心 XMP 标签（如 `GCamera:MotionPhoto`、`MicroVideoOffset`、`Item:Length`、`MotionPhotoPresentationTimestampUs` 等）与 EXIF 设备信息（Make / Model）。

### 克制原则（Non-Intrusive Design）
- **零主舞台干扰**：绝不在全屏预览舞台上常驻大型图表或技术参数面板，保持普通用户视角的纯净沉浸体验。
- **渐进式披露（Progressive Disclosure）**：仅将现有左上角下方的 `quietMetadataRow`（`LIVE · Pixel · 2.40s` 徽标胶囊）升级为**可轻点触发入口**（右侧附带一枚极简 `info.circle` 微标，不新增额外悬浮控件），点击后以 `.medium` / `.large` 半屏 Sheet 呈现文件结构与元数据。

---

## 2. 待确认事项与开放问题（User Review Required）

> [!NOTE]
> **1. 入口范围：`MotionPhotoView` 单图检查页为主，暂不侵入 `LabView`**
> - **建议方案**：首期仅在 `MotionPhotoView`（单图检查页）提供入口。原因是 `LabView`（`CustomLivePhotoView` / `LiveToMotionView`）定位为“合成器”，而 `MotionPhotoView` 才是“检查与转换页”。
> - **可选扩展**：如果您希望在 `LabView` 逆向导出 Motion Photo 完成后也能直接查看刚生成的 `.jpg` 文件结构，后续只需复用同一套 `MetadataInspectorSheet` 组件即可零成本接入。

> [!NOTE]
> **2. GainMap 分段识别策略**
> - Android Ultra HDR（Google Pixel / 小米 / OPPO 等）动态照片常在主 JPEG 与尾部 MP4 之间内嵌第二段 JPEG 作为 HDR GainMap。
> - **拟定方案**：在 `0..<videoStart` 区间内优先结合 XMP `GainMap` 长度或扫描次级 JPEG SOI/EOI（`0xFF 0xD8 ... 0xFF 0xD9`）并以 `CGImageSourceCopyAuxiliaryDataInfoAtIndex(..., kCGImageAuxiliaryDataTypeHDRGainMap)` 辅助确认；若无 GainMap 则不显示该分段，保持比例条简洁。

---

## 3. 交互与视觉规格（L2 · 待 Figma 定稿回填）

### 3.1 触发入口（`MotionPhotoView.quietMetadataRow`）
- 保持原有非玻璃静态胶囊外观（`AppTheme.quietPhotoBadgeFill`，圆角 `14pt`，高度 `30pt`），在 `LIVE · Pixel · 2.40s` 文案右侧增加 `info.circle`（`11pt`, `white.opacity(0.72)`）。
- 轻点触发 `AppHaptics.lightImpact()` 并弹出 `MetadataInspectorSheet`；同时为无障碍访问补充 `accessibilityHint`。

### 3.2 半屏信息面板（`MetadataInspectorSheet`）
采用标准不透明模态页（`AppTheme.canvas` 背景 + `.studioCard` 卡片分组，严格遵循“内容层禁用 Liquid Glass”规范），支持 `.presentationDetents([.medium, .large])` 与 `.presentationDragIndicator(.visible)`：

```text
┌──────────────────────────────────────────────┐
│  文件结构                        [复制] [×]   │  <- Header: 标题 + 一键复制摘要 + 关闭
├──────────────────────────────────────────────┤
│  容器构成 · 总大小 5.6 MB                     │  <- Card 1: 字节构造比例条
│  [███████████|██|███████|▌]                  │     圆角分段条 (continuous, height: 10pt)
│  ● JPEG 3.4 MB (60%)   ● GainMap 0.3 MB (5%) │     2列图例，等宽字体 (.monospaced)
│  ● MP4  1.9 MB (34%)   ● SEF     123 B  (<1%)│
├──────────────────────────────────────────────┤
│  视频流规格                                   │  <- Card 2: 紧凑 2x2 指标网格
│  编码格式   HEVC (hvc1)   分辨率   1440×1080 │
│  帧率       30.00 fps     时长     2.40 s    │
├──────────────────────────────────────────────┤
│  XMP 与设备元数据                             │  <- Card 3: 键值列表（仅展示非空关键字段）
│  Brand / EXIF         Pixel · Google Pixel 8 │
│  MotionPhoto          1                      │
│  PresentationTsUs     1240000                │
│  Item:Length          1992341                │
│  ...                                         │
└──────────────────────────────────────────────┘
```

### 3.3 颜色语义映射（复用 `AppTheme` Token）
- **JPEG / HEIC（主图像）**：`AppTheme.accent`（主青蓝）
- **GainMap（HDR 增益图）**：`AppTheme.warning`（琥珀橙）
- **MP4（内嵌视频流）**：`AppTheme.success`（翠绿）
- **SEF / Trailer（厂商尾部标记）**：`AppTheme.textTertiary`（中性灰）

### 3.4 四态与边界处理
- **Loading（加载态）**：视频轨信息异步加载期间，视频规格卡片显示紧凑 `ProgressView()` 占位；字节分段与 XMP 数据随主解析同步就绪，无需等待。
- **Empty（空态）**：若文件无 XMP 字段（例如纯尾部拼接的 Universal 动态照片），XMP 卡片显示柔和提示文案（如“未检测到 XMP 元数据，已通过二进制容器特征识别”），不留空白卡片。
- **Error / 边界情况**：
  - 极小分段（如 `SEF 123 B` 占比 `< 1%`）：比例条渲染层强制保留最小可见宽度 `4pt`，避免在视觉上完全消失；图例显示 `<1%` 与精确字节格式化（`ByteCountFormatter`）。
  - 所有字节切片严格校验 `0 <= start <= end <= data.count`，各分段字节之和恒等于源文件总大小。
  - 若文件非标准视频轨或读取编码失败，编码字段优雅降级为 `"—"`，不影响其余分段与 XMP 展示。

---

## 4. 架构与数据模型设计

遵守 `Motion2Live/AGENTS.md` 职责边界：**UI 层不得直接解析二进制媒体流**，所有只读字节分析与元数据汇总收口至模型/工具层。

### 4.1 数据模型（`MotionPhotoInspectionReport`）

```swift
// Motion2Live/Models/MotionPhotoStructureAnalyzer.swift

enum MotionPhotoSegmentKind: String, CaseIterable, Sendable {
    case primaryImage   // JPEG / HEIC
    case gainMap        // Ultra HDR GainMap JPEG
    case video          // ISOBMFF MP4
    case sefTrailer     // Samsung SEF / SEFT
    case unknownTrailer // 其他尾部填充或私有块
}

struct MotionPhotoByteSegment: Identifiable, Equatable, Sendable {
    let id: String
    let kind: MotionPhotoSegmentKind
    let label: String           // e.g. "JPEG", "HEIC", "GainMap", "MP4", "SEF"
    let byteOffset: Int
    let byteCount: Int

    var percentage: Double { ... } // 由报告总字节数计算
}

struct MotionPhotoVideoSpecs: Equatable, Sendable {
    let codecName: String       // e.g. "HEVC (hvc1)", "H.264 (avc1)"
    let width: Int
    let height: Int
    let frameRate: Double
    let durationSeconds: Double
}

struct MotionPhotoInspectionReport: Equatable, Sendable {
    let totalBytes: Int
    let brand: MotionPhotoBrand
    let exifMake: String
    let exifModel: String
    let segments: [MotionPhotoByteSegment]
    let xmpFields: [(key: String, value: String)] // 按重要性排序，已去重
    var videoSpecs: MotionPhotoVideoSpecs?
}
```

### 4.2 只读字节分析器（`MotionPhotoStructureAnalyzer`）
1. **输入**：原始只读 `data: Data`、`xmpInfo: [String: String]`、`extracted: MotionPhotoData`（复用已有解析结果，避免重复全文件扫描）。
2. **分段边界计算**（严格只读、边界安全）：
   - `videoStart`：优先采用 `extracted.videoOffset`，若为空则回退 `ISOBMFFHelper.findMP4Offset(in: data)`。
   - `pureVideoLength`：调用 `ISOBMFFHelper.measurePureMP4Length(in: data, startingAt: videoStart) ?? extracted.videoData.count`，确保 `videoEnd <= data.count`。
   - **图像前置区 `0..<videoStart`**：
     - 检测容器前缀：JPEG (`0xFF 0xD8`) 标记为 `"JPEG"`，否则检查 `ftyp` (`heic`/`mif1`/`heix`) 标记为 `"HEIC"`。
     - 若为 JPEG 且存在 GainMap（通过 `CGImageSourceCopyAuxiliaryDataInfoAtIndex` 确认或 XMP `GainMap` 辅助判断，并在 `0..<videoStart` 内定位第二个有效 `SOI (0xFF 0xD8)` 至 `videoStart` 前的完整 JPEG 段），则拆分为 `primaryImage`（`0..<gainMapStart`）与 `gainMap`（`gainMapStart..<videoStart`）。
   - **尾部区块 `videoEnd..<data.count`**：
     - 若 `data.count - videoEnd > 0`，检查是否含 `MotionPhoto_Data` / `SEFH` / `SEFT` 标记：命中则标记为 `sefTrailer`（`"SEF"`），否则标记为 `unknownTrailer`（`"Trailer"`）。
3. **视频流规格提取**（异步 `AVAsset` 读取）：
   - 在 `MotionPhotoView` 已有的 `AVAsset(url: loaded.tempVideoURL)` 加载流程中顺带读取 `track.load(.formatDescriptions)` 与 `track.load(.naturalSize)` / `track.load(.preferredTransform)`，零额外磁盘 I/O。
   - 通过 `CMFormatDescriptionGetMediaSubType` 将 FourCC（`kCMVideoCodecType_HEVC` / `hvc1` / `hev1`、`kCMVideoCodecType_H264` / `avc1` 等）映射为可读名称。

---

## 5. 拟变更文件清单

### 5.1 解析与分析层
- #### [NEW] `Motion2Live/Models/MotionPhotoStructureAnalyzer.swift`
  - 实现 `MotionPhotoByteSegment`、`MotionPhotoVideoSpecs`、`MotionPhotoInspectionReport` 与 `MotionPhotoStructureAnalyzer`（纯只读静态分析 + `AVAsset` 规格提取 + 纯文本摘要格式化方法 `formattedSummary()`）。
- #### [MODIFY] [MotionPhotoProcessor.swift](../../Motion2Live/Models/MotionPhotoProcessor.swift)
  - 仅按需暴露 `ISOBMFFHelper` 辅助常量（如 `isJPEG(data:)` 等），不改变现有 7 品牌解析行为与结果。

### 5.2 UI 与交互层
- #### [NEW] `Motion2Live/Views/Components/MetadataInspectorSheet.swift`
  - 实现半屏信息面板：字节构造比例条 + 2 列图例、视频编码与分辨率/帧率卡片、关键 XMP/EXIF 字段列表、一键复制摘要（带短暂“已复制”反馈）。
- #### [MODIFY] [MotionPhotoView.swift](../../Motion2Live/Views/MotionPhotoView.swift)
  - 在 `LoadedMotionPhoto` 中携带只读构建的 `inspectionReport: MotionPhotoInspectionReport`（不常驻持有原始大文件 `Data`，避免内存升高）。
  - 在视频轨加载完成后补全 `inspectionReport.videoSpecs`。
  - 将 `quietMetadataRow` 中的品牌时长胶囊升级为可点击按钮（附带微弱 `info.circle` 图标），点击弹出 `MetadataInspectorSheet`。

### 5.3 本地化与测试
- #### [MODIFY] [Localizable.swift](../../Motion2Live/Localizable.swift)
  - 新增文件结构面板所需文案键（如标题、分段图例、视频规格标签、XMP 标题、复制摘要等），同步补全全部 7 种语言分支（`en` / `zh` / `fr` / `de` / `es` / `ja` / `ko`）。
- #### [MODIFY] [Motion2LiveTests.swift](../../Motion2LiveTests/Motion2LiveTests.swift)
  - 新增单元测试覆盖 `MotionPhotoStructureAnalyzer`：
    1. 合成 JPEG + MP4、JPEG + GainMap + MP4、JPEG + MP4 + Samsung SEF 三种容器布局的字节分段精确性与 `sum(segments) == totalBytes` 恒等式。
    2. 越界偏移 / 损坏尾部 / 空 XMP 等边界输入的安全降级测试。
    3. Bundled 真实样图的 `MotionPhotoInspectionReport` 冒烟验证。

---

## 6. 验证计划

### 6.1 编译与单元测试（Automated Tests）
执行项目标准验证命令（确保零警告、全部已有及新增测试通过）：
```bash
xcodebuild build -project Motion2Live.xcodeproj -scheme Motion2Live -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO

DESTINATION=$(xcrun simctl list devices available iPhone | grep -m1 -oE '[0-9A-F-]{36}')
xcodebuild test -project Motion2Live.xcodeproj -scheme Motion2Live -destination "platform=iOS Simulator,id=${DESTINATION}" -only-testing:Motion2LiveTests CODE_SIGNING_ALLOWED=NO
```

### 6.2 手工与 Simulator 冒烟验证（Manual Verification）
1. 在 iPhone Simulator 中打开任意一张动态照片（如 Pixel / 三星 / 小米样图），确认主舞台视觉与长按播放交互无任何干扰。
2. 轻点左上角下方的 `LIVE · <Brand> · <Duration>` 胶囊，确认流畅弹出半屏 `MetadataInspectorSheet`。
3. 核对比例条颜色与图例字节数总和是否与原图大小一致、视频编码（`HEVC`/`H.264`）与分辨率/帧率显示准确、XMP 关键字段可阅读。
4. 切换深色模式（Obsidian Dark）与浅色模式（Porcelain Light），以及横屏/iPad 尺寸，确认弹窗排版与对比度符合 `docs/design-system.md`。
5. 点击「复制」按钮，确认剪贴板内容完整且无本地绝对路径泄露。

---

### 下一步操作
请审阅以上规格与两个待确认点。确认后可选择以下任一推进方式：
- **「建 Worktree」**：由我执行 `make wt name=byte-inspector` 创建独立工作树并输出新会话启动词，您在新会话中启动实现。
- **「自动开干」**：回复确认（或直接说「自动开干」），我将在独立 Worktree 中调度 Builder 与只读 Reviewer 完成编码、测试与盲审。
