# Motion2Live 产品官网设计与文案规格书

- **日期**：2026-11-26
- **状态**：Draft（待确认视觉方向、待补业务链接后进入开发）
- **设计门禁级别**：L2（全新对外产品官网、自定义交互舞台、多形态桌面/移动端与深浅色适配）
- **适用技能方法论**：`frontend-design`（两阶段设计评审与反模板约束） + `copywriting`（状况诊断、三问门禁、Human Action Model、无 AI 痕迹自检与可证声明规范）
- **关联文档**：`docs/architecture.md`、`docs/design-system.md`、`docs/privacy-policy.html`

---

## 一、Copywriting 诊断与上下文边界

### 1.1 输入状况诊断（Situation Diagnosis）
- **诊断结论**：**Situation A（空白官网需求 + 完备工程真相源）**。当前仓库尚无产品官网草稿（仅有已托管于 GitHub Pages 的 `docs/privacy-policy.html`），但 `docs/architecture.md`、`docs/design-system.md` 与 `README.md` 提供了完整的品牌解析器、导出管线、权限边界与多端适配事实。
- **写作边界**：所有技术与功能描述严格以仓库代码和文档为依据；**绝不虚构**用户量、App Store 评分、媒体背书或用户评价。凡缺失的外部商务信息一律标注 `[NEED: ...]` 并说明解锁方式。

### 1.2 写作人格与声音锚点（Build a Writer）
- **执笔视角**：Motion2Live 的独立开发者（iOS / macOS 工程师），因为跨安卓与苹果设备传图时动态照片反复变成静止 JPEG，所以亲手写了这套本地二进制解析与封装工具。
- **核心专长区（高密度展开）**：Motion Photo 的真实文件结构（JPEG 静图 + XMP 元数据 + 尾部 MP4 / 三星 SEF 容器）、Apple Live Photo 的 Maker `"17"` 与 `still-image-time` 配对机制、无重编码提取与双向封装、关键帧毫秒级挑封面。
- **主动克制区（简洁陈述或裁剪）**：不写泛泛的“记录美好瞬间”情绪口号；不把每项功能平均拆成三栏对称卖点；直接说明边界——Motion2Live 是专注格式互转的离线工具，不提供云相册同步，也不替代系统相册修图。
- **语言策略**：与现有 `docs/privacy-policy.html` 保持一致，提供**简体中文 / English 双语原生版本**（根据 `?lang=` 参数或浏览器语言自动切换，顶部保留显式切换控件）。中文与英文分别按母语表达重写，避免逐字直译。

### 1.3 可支持声明边界与信息缺口（Declined Claims & Unlock Paths）

| 待补充/受限声明 | 当前处理方式 | 解锁所需证据或输入 |
| :--- | :--- | :--- |
| App Store 下载链接（iOS / iPadOS / macOS） | 按钮保留 `[NEED: App Store URL]` 占位，开发阶段填入真实链接 | App Store Connect 正式上架链接或 TestFlight 公开链接 |
| 定价与付费模式（免费 / 买断 / 内购） | CTA 下方微文案预留 `[NEED: 定价说明]` 槽位 | 确认 App Store 实际定价策略（例如：免费下载、无内购，或一次性买断价格） |
| “全部无损”表述 | **主动收窄为精确陈述**：前向转换提取原内嵌 MP4 流并保留 EXIF/GPS；逆向转换遇到 HEIC 时以 0.95 质量转 JPEG 并保留方向与 EXIF，视频优先 `Passthrough` 混流（格式不兼容时回退重编码） | 已与 `MotionPhotoEncoder.swift` 源码对齐，无需额外证明 |
| 社会证明（下载量、评分、用户原话） | **暂不设置虚假评分栏或伪造评价卡片**，改用可公开核验的事实栏（MPL-2.0 开源、7 大厂商格式、零第三方 SDK、支持 7 种界面语言） | 导出真实 App Store 评分截图/评论原文，或获得用户署名授权原话后可增设评价模块 |
| 官网托管域名与路径 | 默认规划为 `docs/index.html`（直接复用现有 GitHub Pages：`https://igloo302.github.io/MotionPhotoConverter/`，与 `privacy-policy.html` 同源） | 若计划绑定独立域名（如 `motion2live.app`），提供 `CNAME` 配置即可 |

---

## 二、Frontend Design 两阶段设计方案

### 2.1 Pass 1：初始构想（草稿）
最初容易想到的常规方案是：
- 全站深黑底色（`#0B0D0F`）配青蓝发光渐变背景；
- 首屏居中大标题 + “立即下载”按钮 + 静态 iPhone 样机图；
- 下方依次堆叠 3 列等宽圆角功能卡片（Bento Grid）、`01 / 02 / 03` 步骤卡片、品牌 Logo 墙、以及带大写字母眉标（`PRIVACY — ZERO CLOUD`）的隐私卡片。

### 2.2 Pass 1 审视与修订（Critique & Revision）
对照 `frontend-design` 原则与 Motion2Live 自身的产品气质，上述 Pass 1 存在 4 处明显的通用 AI 模板倾向，逐一修订：

1. **避免“全黑发光 SaaS 模板”，改为「瓷白画廊底 + 暗夜光学舞台」的明暗分层**
   - **问题**：全黑底色配单一亮色强调是目前最常见的生成式工具站默认风格，且会掩盖 Motion2Live 在浅色模式（Porcelain Light）下干净克制的苹果原生感。
   - **修订**：默认采用 `docs/design-system.md` 中的 **Porcelain Light (`#F4F6F9` / `#FFFFFF`)** 作为页面阅读底面，而将 **Obsidian Stage (`#101316`)** 专门保留给“照片预览、视频播放与字节结构透视”的暗房舞台区域（同时完整支持 `prefers-color-scheme: dark`，在系统深色模式下无缝切换为 `Obsidian Dark` 体系）。这既贴合摄影看片台“白墙展陈 + 暗室看片”的行业直觉，也直接呼应 App 内部“浅色首页/批量页 + 深色全出血播放舞台”的真实层次。
2. **把视觉张力集中在唯一核心亮点：首屏「可按住播放 + 字节透视」动态照片舞台**
   - **问题**：静态手机壳截图无法直观传达“一张看似静止的 JPEG 里其实藏着一段视频”这一产品核心洞察。
   - **修订**：首屏右侧构建一个**交互式动态照片舞台（Interactive Live Stage）**：复刻 App 标志性的三卡叠放与 LIVE 同心圆环，支持访客**按住（或点击切换）播放动态效果**，并提供一个**「透视容器字节（Inspect bytes）」开关**——一键把画面切换为真实容器结构视图（`JPEG 静图 2.1 MB | XMP 索引 4 KB | MP4 视频 1.8 MB`），直观展示 Motion2Live 到底在文件里做了什么。页面其余部分刻意保持克制留白，不叠加多余装饰动画。
3. **剔除模板化排版痕迹，实施“零外链资源”的原生字体策略**
   - **问题**：引入 Google Fonts CDN 会向外部服务器发起网络请求，与 Motion2Live“纯离线、零追踪”的产品主张自相矛盾；同时每段标题上方加全大写追踪眉标、中点分隔元信息（`A · B · C`）、按钮后缀箭头（`→`）或标题局部变色都是典型模板特征。
   - **修订**：全站**零外部 CDN 请求**（零第三方字体、零统计脚本），采用原生系统字体栈（`-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "PingFang SC", "Hiragino Sans GB", sans-serif`）搭配等宽字体（`"SF Mono", ui-monospace, Menlo, monospace`）；等宽字体**仅用于真实技术读数**（时间码 `00:01.18`、字节大小 `1.8 MB`、容器标记 `ftyp` / `XMP`），绝不用于装饰性小标题。标题通体单色，不做局部斜体或变色强调；按钮不加 `→` 符号；正文单行宽度严格控制在 `62–72ch`（低于 80 字符）。
4. **打破“等宽三列卡片”均质节奏，按内容形态定制版式**
   - **问题**：把所有功能切进大小一致的圆角卡片，会让页面显得机械平淡。
   - **修订**：不同段落采用差异化版式密度——首屏采用左文右舞台非对称布局；“问题机制”采用紧凑的双态对比条；“双向格式转换”做成可切换方向的交互工作台；“精细控制”采用一大两小的非对称摄影工作台组合；“隐私与架构”做成无冗余装饰的工程规格清单表（Spec Sheet）。

### 2.3 修订后视觉 Token 体系（严格对齐 `docs/design-system.md`）

#### 色彩系统（6 个命名核心色，自带浅/深色映射）
| Token 名称 | Light（默认瓷白画廊） | Dark（Obsidian 暗夜） | 使用约束 |
| :--- | :--- | :--- | :--- |
| `--porcelain-canvas` | `#F4F6F9` | `#0B0D0F` | 页面主画布背景 |
| `--gallery-surface` | `#FFFFFF` | `#121518` | 工作台、对照面板、规格表底层 |
| `--surface-recessed` | `#EBEEF3` | `#181B1F` | 切换槽位、代码/字节条底槽 |
| `--obsidian-stage` | `#101316` | `#101316` | **恒定暗房衬底**：仅用于照片/视频看片舞台，确保影像对比度 |
| `--ink-primary` / `--ink-secondary` | `#0F1419` / `#536070` | `#FAFAFA` / `#A6ADB8` | 主文字 / 正文说明（辅助文字 `#8391A2` / `#6B7585`） |
| `--optical-cyan` | `#0284C7` | `#38BCE0` | **唯一强调色**：仅用于 LIVE 同心环、时间轴指针与主 CTA，禁止作为大面积背景渐变 |
| `--hairline-slate` | `#D4DBE5` | `#2A2F36` | 1px 结构线、容器分段分隔线与面板描边 |

> 语义状态色沿用 `ObsidianTheme.swift`：成功 `#248A3D`（暗 `#30D158`），用于字节校验通过与权限状态标记。

#### 字体与尺标（遵循 *The Elements of Typographic Style* 比例）
- **Display / H1**：`clamp(2.25rem, 4.2vw, 3.35rem)`，字重 `700`，行高 `1.12`（英文） / `1.22`（中文），字距 `-0.03em`（英文）/ `-0.015em`（中文）。
- **Section H2**：`clamp(1.625rem, 2.6vw, 2.15rem)`，字重 `650`，行高 `1.22`，左对齐。
- **Card / Module H3**：`1.125rem`（`18px`），字重 `600`，行高 `1.35`。
- **Body**：`1.0625rem`（`17px`），行高 `1.65`（英文） / `1.75`（中文），最大宽度 `64ch`。
- **Technical Readout（Mono）**：`0.8125rem`（`13px`），`font-variant-numeric: tabular-nums`，仅用于时间码、文件体积、偏移量与协议字段。

#### 圆角层级（按体量区分，拒绝全站统一圆角）
- 舞台外框：`24px`（对齐 `AppTheme.Radius.stage`）
- 主工作台面板：`18px`（对齐 `AppTheme.Radius.card`）
- 表单/交互分段控件：`12px`（对齐 `AppTheme.Radius.control`）
- 主 CTA 与胶囊切换器：`999px`（对齐 `AppTheme.Radius.capsule`）
- 技术字节分段条：`4px`（精密仪器感，与圆润照片卡片形成材质对照）

#### 动效与无障碍底线
- **单次页面入场克制**：不做“滚动到每个区块都淡入上移”的模板动效，也不对普通卡片加统一悬浮放大。
- **响应用户操作的微动效**：按住舞台卡片播放时的同心环呼吸脉冲、切换 `Android → Apple` 与 `Apple → Android` 方向时的数据流路径过渡、关键帧时间轴拖动指示。
- **完整降级与可访问性**：尊重 `prefers-reduced-motion: reduce`（关闭循环脉冲与平滑位移）；所有交互控件具备 `2px solid var(--optical-cyan)` 可见键盘焦点环；对比度满足 WCAG AA（正文 ≥ 7:1，次级文案 ≥ 4.5:1）。

### 2.4 页面布局结构与 ASCII 线框图

#### 对齐策略
- **全局左对齐为主**：阅读路径清晰、扫描效率高，适合摄影与工程工具的理性气质；仅底部收尾 CTA 区与媒体舞台内部画面居中。
- **最大内容宽度**：`1120px`，左右安全边距桌面 `32px` / 移动端 `20px`。

#### 桌面端线框图（Desktop ≥ 1024px）

```text
+-------------------------------------------------------------------------+
| [BrandMark] Motion2Live          工作台   精细工具   隐私   [中文 | EN]  |  <- 极简 64px 顶栏，无搜索框、无冗余菜单
+-------------------------------------------------------------------------+

  BAND 1: ASYMMETRIC HERO (左文 52% / 右光学舞台 48%)
+-----------------------------------+  +----------------------------------+
|                                   |  |  OBSIDIAN STAGE (#101316)        |
|  让安卓动态照片，                   |  |  +----------------------------+  |
|  在 iPhone 相册里重新动起来         |  |  | (o) LIVE        [2.40s]    |  |
|                                   |  |  |                              |  |
|  从安卓传到 iPhone 的动态照片，      |  |  |     [ 真实海岸动态照片 ]     |  |
|  视频其实还在原图里。Motion2Live    |  |  |     (叠放左右副卡边缘)       |  |
|  在本机解析小米、Pixel、三星等 7 类  |  |  |                              |  |
|  格式，导出原生实况、视频或 GIF，    |  |  |  ||||||||||||||  按住预览    |  |
|  也能将 Apple 实况转回安卓动态照片。 |  |  +----------------------------+  |
|                                   |  |  [ 画面预览 ]  [ 透视文件字节 ]   |
|  [ 在 App Store 下载 Motion2Live ] |  |  [JPEG 2.1MB][XMP][MP4 1.8MB]   |
|  查看 GitHub 源码                   |  +----------------------------------+
|  支持 iPhone、iPad 与 Mac · 纯离线  |
+-----------------------------------+

  BAND 2: PROBLEM & MECHANISM (非对称双态对比条，紧凑留白)
+-------------------------------------------------------------------------+
| 同一张 3.9 MB 照片，为什么在 iOS 相册里不会动？                           |
|                                                                         |
|  [ 左: iOS 原生相册收到时 ]         -->    [ 右: 经 Motion2Live 封装后 ]  |
|  只读取前半段 JPEG 静图                    拆出尾部 MP4 并写入 Apple       |
|  尾部 MP4 字节被静默忽略                   Maker "17" + content.id 配对  |
|  (显示冻结画面 + 灰掉的 MP4 字节块)         (显示原生实况角标 + 保留 EXIF)  |
+-------------------------------------------------------------------------+

  BAND 3: TWO-WAY FORMAT WORKBENCH (单面板交互工作台，非多卡片堆砌)
+-------------------------------------------------------------------------+
| 双向转换，覆盖主流厂商容器格式              [ 安卓 -> Apple | Apple -> 安卓 ]|
+-------------------------------------------------------------------------+
|  输入来源 (7 类识别器)            处理管线                输出结果         |
|  - 小米 (HyperOS 2 / 旧版)       只读二进制探测           - Apple 实况照片 |
|  - Google Pixel (v1 / v2)        校验 ftyp 签名           - 独立 MP4 / MOV |
|  - 三星 (含 SEF 尾部标记)         剥离冲突 XMP             - 自定义帧率 GIF   |
|  - 华为 / OPPO・一加 / vivo       保留 EXIF / GPS / 时间   (切换后显示      |
|  - 通用 MP4 拼接格式              自校验输出容器            7 品牌 .jpg)     |
+-------------------------------------------------------------------------+

  BAND 4: PRECISION CRAFT (一大两小非对称摄影暗房组合)
+-------------------------------------------------------------------------+
|  +-------------------------------------------------------------------+  |
|  | [宽幅主模块 100%] 挑一帧更好的封面，看清文件里的每一段字节           |  |
|  | 左侧：可交互模拟时间轴 [ | | | | [00:01.18] | | | ] + 真实详情截图   |  |
|  | 右侧：容器比例条 JPEG 54% / MP4 46% · H.264 30fps · XMP 键值摘要    |  |
|  +-------------------------------------------------------------------+  |
|  +---------------------------------+ +-------------------------------+  |
|  | [左模块 55%] 批量转换，自动筛图  | | [右模块 45%] 分享菜单 & 实验室 |  |
|  | 3x3 缩略图网格截图               | | Share Extension 原地转换       |  |
|  | 自动跳过普通静图、串行控内存峰值  | | Lab: 任意静图 + 视频双向合成   |  |
|  +---------------------------------+ +-------------------------------+  |
+-------------------------------------------------------------------------+

  BAND 5: NATIVE ON IPHONE, IPAD & MAC (真实跨设备画面，非 3D 夸张倾斜)
+-------------------------------------------------------------------------+
| 为 iPhone、iPad 与 Mac 原生构建                                          |
| [ Mac 窗口主界面截图 (支持文件拖放) ]  +  [ iPhone 竖屏详情截图 ]          |
| 一行具体平台规格说明（iOS 16+ / iPadOS 16+ / macOS 14.4+ / 7 国语言）     |
+-------------------------------------------------------------------------+

  BAND 6: PRIVACY & ARCHITECTURE SPEC SHEET (纯事实工程规格表，无营销空话)
+-------------------------------------------------------------------------+
| 你的照片从未离开过这台设备                                                |
| ----------------------------------------------------------------------- |
| 网络请求         | 0 次。纯离线运行，无后端服务器，无分析与崩溃上报 SDK     |
| 相册读取权限     | 不申请全相册读取。选图仅经系统 PHPickerViewController    |
| 相册写入权限     | 仅在保存时申请 Add-Only，无法读取、修改或删除既有照片    |
| 临时文件清理     | 仅写入 NSTemporaryDirectory，导出结束或离页立即清除      |
| 开源协议         | Mozilla Public License 2.0，全部解析代码可在 GitHub 审查 |
| 隐私清单         | 内置 PrivacyInfo.xcprivacy，完整声明见《隐私政策》       |
+-------------------------------------------------------------------------+

  BAND 7: FAQ (6 个真实问题，简洁手风琴) + BAND 8: QUIET CLOSING CTA + FOOTER
+-------------------------------------------------------------------------+
| 常见问题 (6 条折叠面板)                                                  |
+-------------------------------------------------------------------------+
| 准备好整理你的动态照片了吗？                                             |
| [ 在 App Store 下载 Motion2Live ]   [ 在 GitHub 查看源码 ]               |
+-------------------------------------------------------------------------+
| © 2024–2026 Motion2Live · Larry Shen   隐私政策 · GitHub · 邮件联系       |
+-------------------------------------------------------------------------+
```

#### 移动端适配（Mobile < 768px）
- **Band 1**：改为单栏堆叠，**文案与主 CTA 置顶，Interactive Live Stage 紧随其下**（首屏即可看到标题、主操作按钮及舞台顶部，无需长滚）。舞台交互从“鼠标按住/悬停”自然适配为“点按切换播放 + 透视字节开关”，避免与页面垂直滚动手势冲突。
- **Band 2 / 3 / 4 / 5**：统一单列流式排布，保留 `20px` 边距；Band 3 工作台切换器固定在模块顶部，输入/输出列表紧凑纵向排列；Band 6 规格表在窄屏改为“标签在上、事实在下”的清晰键值对。

### 2.5 交互状态与四态规范（L2 Design Gate 必备）
| 交互模块 | 默认态 (Default) | 交互/激活态 (Active) | 边界/降级态 (Edge / Reduced Motion) |
| :--- | :--- | :--- | :--- |
| 首屏 Live 舞台 | 显示真实示范静图、LIVE 角标、时长 `2.40s` 与波形静帧 | 按住或点击「播放」：同心环脉冲、视频/序列动效播放；点击「透视文件字节」：切换为暗房字节分段视图（JPEG/XMP/MP4 字节偏移与大小） | `prefers-reduced-motion` 下改为静态淡切，不自动循环；若动图/视频加载失败，优雅回退至高清静图海报并保留字节透视功能 |
| 双向转换工作台 | 默认选中 `Android → Apple` 标签，展示 7 品牌输入与 3 种 Apple 导出格式 | 切换 `Apple → Android`：平滑切换输入为 Apple Live Photo，输出为 7 品牌兼容 Motion Photo `.jpg` 及 `Passthrough` 封装路径 | 无 JS 降级或键盘操作时支持 `role="tablist"` 与方向键完整切换 |
| 关键帧时间轴预览 | 指示游标位于默认中点 `00:01.18`，上方展示对应封面帧与 EXIF 保留标识 | 拖动滑块（input range）：实时更新等宽时间码、帧预览与当前帧标记 | 支持键盘左右键步进，触控区域 ≥ `44px` |
| 语言切换器 | 按 `?lang=zh/en` 或 `navigator.language` 初始化（未知默认英文或中文可配置） | 一键切换整站文案并同步 `<html lang>`、`<title>`、`meta description` 与隐私政策跳转参数（`privacy-policy.html?lang=...`） | 刷新后可通过 URL 参数保持语言，不依赖 Cookie 追踪 |

---

## 三、完整落地页文案（双语锁定稿）

> 下方全部文案均已通过「三问门禁（画面感 / 可证伪 / 竞品替换测试）」与 `ai-tells.md` 严检：零“不是 X 而是 Y”对比揭晓、零“无需 A 无需 B 无需 C”否定排比、零短文案破折号、零感叹号、零空洞营销词、零虚构数据。

### 3.1 简体中文完整稿（`zh-CN`）

#### 顶部导航
- 品牌名：`Motion2Live`
- 导航项：`格式工作台`、`精细工具`、`隐私规格`、`常见问题`
- 语言切换：`中文` / `EN`

#### Band 1：首屏（Hero）
- **Headline (H1)**：`让安卓动态照片，在 iPhone 相册里重新动起来`
- **Subheadline**：`从安卓传到 iPhone 的动态照片，视频其实还在原图里。Motion2Live 在本机解析小米、Pixel、三星、华为、OPPO 与 vivo 的文件结构，导出为原生 Apple 实况照片、独立视频或 GIF，也能把 Apple 实况转回各品牌安卓动态照片。`
- **Primary CTA**：`在 App Store 下载 Motion2Live` `[NEED: App Store URL]`
- **Secondary Action**：`查看 GitHub 源码`
- **Microcopy**：`支持 iPhone、iPad 与 Mac（iOS 16+ / macOS 14.4+）。全部处理在本机完成。[NEED: 定价说明，如免费下载或一次性买断]`
- **右侧交互舞台控件文案**：
  - 切换按钮：`画面预览` / `透视文件字节`
  - 舞台提示：`按住预览动态`（移动端：`轻点播放动态`）
  - 字节视图读数（真实结构示意）：`JPEG 静图 2.1 MB` · `XMP 元数据 4 KB` · `内嵌 MP4 1.8 MB` · `ftyp 偏移校验通过`

#### Band 2：问题与机制
- **Section Heading (H2)**：`同一张照片，为什么在 iOS 相册里变成了静态图`
- **Body**：`小米、Google Pixel、三星等安卓手机把动态视频直接拼接在 JPEG 文件末尾，并用 XMP 字段或 SEF 尾部标记记录偏移位置。Apple 相册只认配对的静图与 QuickTime 媒体标识符，因此直接导入时只会显示前半段静态画面。Motion2Live 读取原文件中的视频字节，写入 Apple Maker "17" 与配对标识，让系统相册把它识别为真正的实况照片。`
- **对比示意标签**：
  - 左框标题：`直接导入 iOS 相册` — `前半段 JPEG 正常显示，尾部 MP4 数据被系统忽略，长按无反应。`
  - 右框标题：`经 Motion2Live 转换` — `提取原视频流并按 Apple 规范配对封装，长按直接播放，拍摄时间与 GPS 原样保留。`

#### Band 3：双向格式工作台
- **Section Heading (H2)**：`双向转换，按各品牌规范解析与封装`
- **Intro**：`换机迁移、跨系统互传原图，或者把 iPhone 拍的实况发回安卓相册，都在同一个工具里完成。`
- **模式 A：`安卓动态照片 → Apple 格式`**
  - **识别来源**：`小米（含 HyperOS 2 与早期 MicroVideo）、Google Pixel、三星（含 SEF 容器）、华为、OPPO 与一加、vivo，以及通用 MP4 拼接格式。`
  - **导出选项**：
    - `原生 Apple 实况照片`：写入系统相册即可长按播放，保留原图 EXIF、拍摄时间与地理坐标。
    - `独立 MP4 / MOV 视频`：直接提取内嵌视频片段，便于剪辑或发送给不支持实况的聊天软件。
    - `GIF 动图`：按设定帧率与尺寸采样输出，方便直接贴进文档或社交评论区。
- **模式 B：`Apple 实况照片 → 安卓动态照片`**
  - **识别来源**：`直接从系统相册选取任意 Apple Live Photo。`
  - **封装方式**：`非 JPEG 静图（如 HEIC）在保留方向与 EXIF 的前提下转为高质量 JPEG 并清理冲突旧标签；配对视频优先通过 Passthrough 直接混流为 MP4，按你指定的目标品牌结构封装为单个 .jpg 文件，并在导出前完成容器自校验。`
  - **导出方式**：`同步文件拍摄时间戳，通过系统分享面板或「文件」App 保留原始字节导出。`

#### Band 4：精细控制与效率工具（非对称暗房组合）
- **主模块（宽幅）— 封面关键帧与容器检查**
  - **Heading (H3)**：`挑一帧更好的封面，看清文件里的每一段字节`
  - **Body**：`很多动态照片的默认封面恰好落在眨眼或晃动的那一瞬。拖动胶卷时间轴到毫秒级位置，选定清晰的静态帧作为新的实况封面，同时保留原图拍摄参数与位置信息。打开元数据检查器，还能查看静图与视频的体积占比、编码规格与原始 XMP 字段，一键复制摘要用于排查问题。`
- **次模块左 — 批量转换**
  - **Heading (H3)**：`一次选几十张，自动筛掉普通静图`
  - **Body**：`批量导入相册照片时，Motion2Live 会先逐张探测容器结构，自动跳过不含视频流的普通静态图片。导出过程采用串行管线控制内存占用，整批转换为实况照片、视频或 GIF。`
- **次模块右 — 分享扩展与实验室**
  - **Heading (H3)**：`从系统分享菜单直达，也能自定义合成`
  - **Body**：`在相册、「文件」或聊天软件里点一下分享，即可在扩展面板中原地预览并保存为实况、视频或 GIF。想把任意一张照片和一段短视频合成为 Apple 实况或安卓动态照片，打开顶部「实验室」即可双向拼装。`

#### Band 5：全平台原生体验
- **Section Heading (H2)**：`iPhone、iPad 与 Mac，同一套本地引擎`
- **Body**：`全部界面基于 SwiftUI 与 Apple 原生媒体框架构建。在 iPhone 与 iPad 上可直接从相册或分享菜单处理；在 Mac 上支持从访达直接拖入动态照片或批量导入本地文件夹。界面支持简体中文、英文、日文、韩文、法文、德文与西班牙文 7 种语言。`
- **设备图示说明**：
  - `macOS 14.4+`：支持拖放文件与原生深色看片舞台
  - `iOS / iPadOS 16.0+`：适配分屏布局与系统相册选择器

#### Band 6：隐私与架构规格表
- **Section Heading (H2)**：`照片始终留在你的设备上`
- **Intro**：`Motion2Live 依赖系统原生框架完成所有二进制解析与音视频混流，不接入任何第三方 SDK，代码以 MPL-2.0 协议开源。`
- **工程规格表（键值对）**：
  - `网络连接`：`0 次请求。离线可用，不设后端服务器，不接入统计、广告或崩溃上报框架。`
  - `选图权限`：`调用系统 PHPickerViewController，应用仅能接触你主动勾选的照片，不请求读取整个图库。`
  - `保存权限`：`仅在写入结果时请求 Add-Only 权限，无法读取、修改或删除相册中的其他内容。`
  - `临时缓存`：`解析产生的临时媒体仅存于 NSTemporaryDirectory，导出完成或离开页面后立即清除。首页最近转换最多缓存 3 张缩略图，可随时关闭或清空。`
  - `首次试玩`：`内置 3 张示范动态照片，安装打开就能体验预览与关键帧调整，确认好用再授予保存权限。`
  - `合规与源码`：`内置 Apple PrivacyInfo.xcprivacy 隐私清单；查看完整《隐私政策》或在 GitHub 审查全部源码。`

#### Band 7：常见问题（FAQ）
1. **Q：换了 iPhone 后，旧安卓手机里的动态照片怎么导进来最好？**
   **A**：请尽量通过「文件」传输、AirDrop/局域网原图传输、数据线或云盘原文件下载，避免经过会自动压缩图片的聊天渠道。只要原 `.jpg` 文件尾部还保留 MP4 数据，Motion2Live 就能识别。
2. **Q：转换后照片的拍摄时间和定位信息会丢失吗？**
   **A**：不会。导出 Apple 实况照片、更换关键帧封面以及逆向导出安卓动态照片时，都会保留原始 EXIF 拍摄时间、设备信息与 GPS 元数据，并同步文件时间戳。
3. **Q：为什么某些“动态照片”导入后提示未检测到动态视频？**
   **A**：常见原因是图片在传输途中被社交软件或网盘重新压缩，导致拼接在 JPEG 末尾的 MP4 字节被剥离。你可以用 App 内的「元数据检查器」确认原文件是否仍包含视频流。
4. **Q：支持哪些手机品牌的动态照片？**
   **A**：专门适配小米（含 HyperOS 2 与早期格式）、Google Pixel、三星（含 SEF 格式）、华为、OPPO/一加与 vivo，并提供通用 MP4 拼接兜底识别器。
5. **Q：把 Apple 实况转回安卓动态照片后，发给安卓手机能直接播放吗？**
   **A**：在导出时选择对方手机对应的品牌格式（如小米、三星或 Pixel），并通过「文件」或发送原图传给对方，即可在对应品牌的系统相册中按原生动态照片识别。
6. **Q：软件开源吗？需要联网或付费订阅吗？**
   **A**：项目以 Mozilla Public License 2.0 协议在 GitHub 开源，全程离线运行，无需注册账号。[NEED: 补充 App Store 实际定价/免费策略]。

#### Band 8：收尾 CTA 与页脚
- **Closing Heading (H2)**：`把相册里静止的动态照片整理回来`
- **Closing Subtext**：`适用于 iPhone、iPad 与 Mac，内置 3 张示范图，打开即可上手体验。`
- **Primary CTA**：`在 App Store 下载 Motion2Live` `[NEED: App Store URL]`
- **Secondary Action**：`访问 GitHub 仓库`
- **Footer**：`© 2024–2026 Motion2Live · Larry Shen` | `隐私政策`（`privacy-policy.html?lang=zh`） | `GitHub` | `联系开发者`（`mailto:shenjy302@live.com`）

---

### 3.2 English Full Copy (`en`)

#### Top Navigation
- Brand: `Motion2Live`
- Links: `Formats`, `Tools`, `Privacy`, `FAQ`
- Language toggle: `中文` / `EN`

#### Band 1: Hero
- **Headline (H1)**: `Turn Android Motion Photos into native Apple Live Photos`
- **Subheadline**: `When an Android Motion Photo lands on your iPhone, the video clip stays hidden inside the JPEG. Motion2Live unpacks Xiaomi, Pixel, Samsung, Huawei, OPPO, and vivo files on your device into native Live Photos, MP4s, or GIFs, and converts Apple Live Photos back to Android Motion Photos.`
- **Primary CTA**: `Download on the App Store` `[NEED: App Store URL]`
- **Secondary Action**: `Browse source on GitHub`
- **Microcopy**: `For iPhone, iPad, and Mac (iOS 16+ / macOS 14.4+). Runs offline on your device. [NEED: pricing qualifier]`
- **Stage Controls**:
  - Toggle: `Live preview` / `Inspect bytes`
  - Hint: `Press and hold to play` (mobile: `Tap to play motion`)
  - Byte readout: `JPEG still 2.1 MB` · `XMP index 4 KB` · `MP4 clip 1.8 MB` · `ftyp verified`

#### Band 2: The Problem & Mechanism
- **Section Heading (H2)**: `Why Android Motion Photos freeze in Apple Photos`
- **Body**: `Android phones append the motion video to the end of a standard JPEG and mark the byte offset with XMP tags or a Samsung SEF trailer. Apple Photos expects a paired still image and QuickTime asset identifier, so it reads the JPEG and ignores the video bytes behind it. Motion2Live splits the stream locally, writes Apple Maker tag "17" and the matching content identifier, and saves a native Live Photo that plays on long press.`
- **Comparison Labels**:
  - Left: `Imported directly to iOS Photos` — `Displays the leading JPEG only. The appended MP4 bytes sit unreadable.`
  - Right: `Converted with Motion2Live` — `Extracts the embedded clip, pairs it to Apple's Live Photo format, and keeps original EXIF and GPS dates.`

#### Band 3: Two-Way Format Workbench
- **Section Heading (H2)**: `Convert in both directions across seven brand formats`
- **Intro**: `Move an Android photo library to iPhone, or send Apple Live Photos back to friends on Android in the container their gallery reads.`
- **Tab A: `Android Motion Photo → Apple`**
  - **Supported sources**: `Xiaomi (HyperOS 2 and legacy MicroVideo), Google Pixel, Samsung (including SEF trailers), Huawei, OPPO and OnePlus, vivo, plus a universal MP4 trailer parser.`
  - **Outputs**:
    - `Native Apple Live Photo`: Saves straight to Apple Photos with long-press playback, capture date, and GPS intact.
    - `Standalone MP4 / MOV`: Extracts the embedded clip as a regular video file ready for editing or messaging apps.
    - `Animated GIF`: Samples frames at your target size for chats, docs, and web posts.
- **Tab B: `Apple Live Photo → Android Motion Photo`**
  - **Source**: `Pick any Apple Live Photo from your library.`
  - **Packaging**: `Converts non-JPEG stills such as HEIC to quality-0.95 JPEG while keeping EXIF orientation and capture metadata, strips conflicting XMP blocks, remuxes the paired MOV to MP4 via passthrough when compatible, builds the chosen brand container, and verifies the output bytes before export.`
  - **Export**: `Syncs original file timestamps and exports raw bytes through the Share Sheet or Files app.`

#### Band 4: Precision Tools (Asymmetric Darkroom Grid)
- **Wide Primary Module — Keyframe Cover Picker & Byte Inspector**
  - **Heading (H3)**: `Pick a sharper cover frame and inspect the file structure`
  - **Body**: `Default covers often land mid-blink. Scrub the embedded filmstrip down to the millisecond to pick a clean still frame while keeping original EXIF, TIFF, and GPS metadata. Open the structure inspector to see exact JPEG-to-MP4 byte ratios, video codec and frame rate, and raw XMP tags, with one-tap summary copy.`
- **Secondary Left — Batch Conversion**
  - **Heading (H3)**: `Drop a whole batch and skip static photos automatically`
  - **Body**: `Select dozens of mixed photos from your library. Motion2Live probes each file first, skips ordinary static JPEGs, and exports valid Motion Photos serially to keep memory steady across Live Photo, Video, or GIF output.`
- **Secondary Right — Share Extension & Lab**
  - **Heading (H3)**: `Convert from any Share Sheet, or pair your own media in Lab`
  - **Body**: `Trigger Motion2Live straight from Photos, Files, or chat apps to preview and save without switching windows. Open Lab to combine any still photo and video clip into a custom Apple Live Photo or Android Motion Photo.`

#### Band 5: Native Across Apple Devices
- **Section Heading (H2)**: `Built natively for iPhone, iPad, and Mac`
- **Body**: `Written purely with SwiftUI, AVFoundation, PhotosUI, and ImageIO. Use the system picker or Share Extension on iPhone and iPad, or drag local Motion Photo folders straight into the Mac window. Localized in English, Simplified Chinese, Japanese, Korean, French, German, and Spanish.`

#### Band 6: Privacy & Architecture Spec Sheet
- **Section Heading (H2)**: `Your photos stay on your device`
- **Intro**: `Motion2Live parses and packages every file locally with Apple frameworks and ships under the MPL-2.0 open-source license.`
- **Spec Rows**:
  - `Network traffic`: `0 requests. Works completely offline with zero backend servers, analytics, or crash SDKs.`
  - `Photo read access`: `Uses Apple's PHPickerViewController. The app only sees items you pick and never requests full library read access.`
  - `Photo write access`: `Requests Add-Only permission solely when saving exported media. Cannot read, edit, or delete existing items.`
  - `Temporary files`: `Written strictly inside NSTemporaryDirectory and removed as soon as export finishes or you leave the screen.`
  - `Try before granting access`: `Ships with 3 built-in demo Motion Photos so you can test playback and cover scrubbing right after install.`
  - `Verification`: `Includes PrivacyInfo.xcprivacy. Read the full Privacy Policy or inspect the full source code on GitHub.`

#### Band 7: FAQ
1. **Q: How should I transfer Android Motion Photos to my iPhone so the video stays intact?**
   **A**: Transfer original files via Files, local network transfer, cable, or cloud drive original download. Messaging apps that recompress JPEGs strip the appended MP4 video bytes.
2. **Q: Does conversion keep my capture date and GPS location?**
   **A**: Yes. Live Photo export, custom keyframe cover extraction, and reverse Motion Photo export preserve original EXIF capture timestamps, orientation, and GPS coordinates, and sync output file timestamps.
3. **Q: Why did a photo from my Android phone show up as static?**
   **A**: The file was likely re-encoded during transfer or backup, which removes the trailing MP4 stream. Open it in the built-in Metadata Inspector to check whether an embedded video segment is still present.
4. **Q: Which phone brands are supported?**
   **A**: Dedicated parsers and reverse encoders cover Xiaomi (HyperOS 2 and older MicroVideo), Google Pixel, Samsung (SEF), Huawei, OPPO / OnePlus, and vivo, backed by a universal MP4 trailer parser.
5. **Q: Will a reverse-converted Apple Live Photo play on an Android phone?**
   **A**: Choose the recipient's phone brand before exporting and send the `.jpg` as an original file through Files or a lossless channel so the Android gallery recognizes its container tags.
6. **Q: Is Motion2Live open source? Does it require an account?**
   **A**: The app is open source under MPL-2.0 on GitHub and runs offline with no sign-up. `[NEED: add App Store pricing note]`

#### Band 8: Closing CTA & Footer
- **Closing Heading (H2)**: `Bring your Android Motion Photos to life in Apple Photos`
- **Closing Subtext**: `Available for iPhone, iPad, and Mac, with three built-in demo photos ready on launch.`
- **Primary CTA**: `Download on the App Store` `[NEED: App Store URL]`
- **Secondary Action**: `View source on GitHub`
- **Footer**: `© 2024–2026 Motion2Live · Larry Shen` | `Privacy Policy` (`privacy-policy.html?lang=en`) | `GitHub` | `Contact` (`mailto:shenjy302@live.com`)

---

### 3.3 关键文案注解（Annotations）
1. **Hero 遵循 Human Action Model**：先点出“视频其实还在原图里”的认知反差与痛点（Discomfort），再给出“在 iPhone 相册重新动起来 + 双向回传”的结果画面（Vision），最后落到原生离线 App 下载（Path）。
2. **Band 2 替代空泛卖点列举**：直接用 3 句话讲透“JPEG 尾部拼接 MP4 vs Apple Maker 17 配对”的真实原因。对摄影和换机用户来说，能把底层原理说清楚本身就是最强的专业信任背书，远胜形容词堆砌。
3. **Band 6 采用工程规格表而非隐私口号卡片**：避免“无广告、无上传、无追踪”的 AI 否定排比，而是精确列出 `PHPickerViewController`、`Add-Only`、`NSTemporaryDirectory` 与 `PrivacyInfo.xcprivacy`，让懂技术的用户一眼就能核验真伪。
4. **有意保留不对称信息密度**：工作台（Band 3）与关键帧/字节检查（Band 4）篇幅最扎实，问题机制（Band 2）与跨设备（Band 5）干练收束，避免每块字数一模一样的机械对称感。

### 3.4 标题与主 CTA 备选方案（Alternatives）

#### Hero Headline 备选
- **Option A（当前锁定）**：
  - ZH：`让安卓动态照片，在 iPhone 相册里重新动起来`
  - EN：`Turn Android Motion Photos into native Apple Live Photos`
  - **Rationale**：画面感最强，一秒说清输入、场景与结果，直接通过“Now you can…”测试。
- **Option B（双向强调型）**：
  - ZH：`把安卓动态照片转成 Apple 实况，也能反向转换`
  - EN：`Convert Android Motion Photos to Apple Live Photos, and back again`
  - **Rationale**：适合双持党或需要高频往返苹果/安卓互传的用户，首屏即突出逆向转换差异化。
- **Option C（品牌搜索意图型）**：
  - ZH：`小米、Pixel、三星动态照片，一键导出 Apple 原生实况`
  - EN：`Xiaomi, Pixel, and Samsung Motion Photos, playable in Apple Photos`
  - **Rationale**：若主要流量来自搜索引擎（SEO）或社媒搜索特定机型教程，品牌词前置能显著提高第一眼相关性。

#### Primary CTA 备选
- **Option A（当前锁定）**：`在 App Store 下载 Motion2Live` / `Download on the App Store`
  - **Rationale**：苹果生态用户心智最直接、信任成本最低的行动动词。
- **Option B（多平台显式型）**：`获取 iPhone 与 Mac 版` / `Get for iPhone, iPad, and Mac`
  - **Rationale**：若希望重点拉动 Mac App Store 下载，可在按钮文案直接点明跨端覆盖。
- **Option C（开源优先型）**：`免费下载（或查看源码）` / `Download Free on the App Store`
  - **Rationale**：仅当确认 App Store 为完全免费上架时启用（需先确认定价信息）。

### 3.5 SEO 与社交分享 Meta 内容

- **中文 `<title>`**：`Motion2Live — 安卓动态照片与 Apple 实况照片离线互转（iPhone / iPad / Mac）`
- **中文 `<meta name="description">`**（118 字）：`纯离线原生应用，在 iPhone、iPad 与 Mac 上解析小米、Pixel、三星、华为、OPPO 与 vivo 动态照片，导出为原生 Apple 实况照片、MP4 视频或 GIF，并支持将 Apple 实况逆向封装回安卓动态照片。`
- **English `<title>`**：`Motion2Live — Convert Android Motion Photos & Apple Live Photos Offline`
- **English `<meta name="description">`**（156 chars）：`Offline iPhone, iPad, and Mac app that converts Xiaomi, Pixel, Samsung, Huawei, OPPO, and vivo Motion Photos to Apple Live Photos, MP4, or GIF, and back again.`
- **Open Graph**：`og:type=website`、`og:image` 使用基于首屏 Porcelain + Obsidian Stage 导出的 `1200×630` 静态卡片图（零外部依赖）。

### 3.6 Copywriting 自检核验记录
- [x] **零对比揭晓**：全篇未使用“不是 X，而是 Y”、“不只是 X，更是 Y”、“It's not X, it's Y”。
- [x] **零否定排比**：未出现“无云端、无注册、无水印”或“No X, no Y, no Z”句式；隐私条款全部改为“发生了什么”的正面机制描述。
- [x] **零短文案破折号 / 零自问自答 / 零冒号揭晓**：Hero 标题、副标题、CTA 与模块小标题均已逐行排查。
- [x] **零感叹号与空洞高频词**：不含“无缝 / seamless”、“强大 / powerful”、“赋能 / empower”、“颠覆 / revolutionary”、“一站式 / all-in-one”等词。
- [x] **竞品替换测试（Swap Test）**：Hero 与各区块标题均绑定 Motion Photo / Live Photo / 7 品牌 / Maker `"17"` / `NSTemporaryDirectory` 等具体事实，无法原样套用于通用图片工具。
- [x] **无虚构背书**：所有缺失链接与商务信息均已以 `[NEED: ...]` 明确标出。

---

## 四、技术实现与静态站架构规划（供 Builder 阶段执行）

### 4.1 目录结构（零构建依赖，直接兼容 GitHub Pages）
现有 `docs/privacy-policy.html` 已在 `https://igloo302.github.io/MotionPhotoConverter/privacy-policy.html` 提供服务。推荐将产品官网直接落盘在 `docs/` 下，保持极简静态架构：

```text
docs/
├── index.html                  # 主入口页面（语义化 HTML5，内置中英双语切换与结构化 JSON-LD）
├── privacy-policy.html         # 既有隐私政策页（保持不变，首页底部直接带 ?lang= 参数互通）
└── site/
    ├── styles.css              # 分层 CSS（@layer reset, tokens, layout, components, utilities 避免选择器覆盖冲突）
    ├── app.js                  # 轻量交互脚本（双语切换、Live Stage 播放/字节透视、双向工作台 Tab、关键帧滑块、FAQ 手风琴）
    └── assets/                 # 压缩优化后的 WebP/PNG 真实截图与首屏演示媒体（从 screenshots/ 与项目示范素材派生）
        ├── hero-poster.webp
        ├── hero-left.webp
        ├── hero-right.webp
        ├── screen-mac-home.webp
        ├── screen-iphone-detail.webp
        ├── screen-iphone-batch.webp
        └── og-card.png
```

### 4.2 CSS 架构防冲突约定（呼应 `frontend-design` 规范）
- 使用原生 CSS Cascade Layers（`@layer reset, tokens, base, layout, components, utilities;`），杜绝 `.section` 与 `.cta` 等类选择器优先级互相抵消的问题。
- 严格禁止在 `docs/site/` 中硬编码本地绝对路径、引入第三方统计脚本或外部字体 CDN，保证 Network 面板 **0 个第三方域名请求**。
- 品牌标志 `Motion2LiveBrandMark` 直接按 `HomeView.swift` 中的双层圆角卡片（`-10°` / `+6°`）+ 同心虚线实况环几何规范手写精确内联 `<svg>`，自动响应浅色/深色主题变量。

### 4.3 验收清单（Builder 完成标准）
1. **桌面端（1440px / 1280px）与移动端（390px）** 均无横向滚动条、无文字重叠、无按钮截断。
2. **浅色（Porcelain Light）与深色（Obsidian Dark）** 双主题完整对比度达标，Obsidian Stage 恒定深色衬底清晰。
3. **交互全闭环**：首屏「按住/点击预览 + 透视文件字节」、双向格式工作台切换、关键帧时间轴拖动、FAQ 展开收起、中英双语切换（含 `?lang=zh` / `?lang=en` 初始化及同步至 `privacy-policy.html` 链接）。
4. **隐私与性能底线**：`prefers-reduced-motion` 生效；键盘 `Tab` 遍历焦点可见；所有外链均带 `rel="noopener noreferrer"`；页面不产生任何第三方网络请求；不破坏现有 iOS/macOS Xcode 工程编译与测试。

---

## 五、待你确认的 4 项输入（确认后即可直接建站）

1. **App Store 下载链接**：目前已有正式链接还是暂用「敬请期待 / GitHub Release / TestFlight」占位？
2. **定价策略**：App Store 是完全免费、一次性买断还是含内购？（决定 Hero Microcopy 与 FAQ 第 6 条的具体表述）
3. **Hero 标题偏好**：默认锁定 Option A（`让安卓动态照片，在 iPhone 相册里重新动起来`），还是更偏好 Option B（突出双向转换）或 Option C（突出小米/Pixel/三星品牌词）？
4. **部署路径确认**：是否按推荐方案直接落盘为 `docs/index.html`（复用现有 GitHub Pages，与 `privacy-policy.html` 同域名），还是另有独立仓库/自定义域名计划？
