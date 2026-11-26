(function () {
  "use strict";

  // Single-point App Store URL configuration.
  const APP_STORE_URL = "https://apps.apple.com/cn/app/motion2live/id6705126412";

  const DEMO_DURATION_SEC = 2.416667;
  const DEMO_TOTAL_FRAMES = 58;
  const DEFAULT_COVER_MS = 1180;

  const BYTE_SEGMENTS = {
    jpeg: {
      marker: "FF D8 FF E0 · 146,462 B",
      range: "731×980 · EXIF",
      zh: "前半段标准 JPEG 负责静态显示并保存 EXIF 拍摄参数、方向与 GPS 坐标。转换时原样保留。",
      en: "The leading JPEG renders the still frame and carries EXIF capture metadata, orientation, and GPS coordinates."
    },
    xmp: {
      marker: "FF E1 APP1 · 4,096 B",
      range: "GCamera:MotionPhoto=1",
      zh: "嵌入在 APP1 段中的 XMP 元数据记录了尾部视频长度与默认封面时间戳，转换时会先校验偏移合法性。",
      en: "XMP tags inside APP1 store the appended video length and presentation timestamp. Motion2Live validates offsets before slicing."
    },
    mp4: {
      marker: "66 74 79 70 (ftyp) · 463,934 B",
      range: "H.264 · 720×960 · 24fps",
      zh: "紧接 JPEG 结束标记的完整 MP4 视频流。Motion2Live 核验 ftyp 签名后无重编码提取并写入 Apple 配对标识。",
      en: "An embedded H.264 MP4 stream appended after JPEG EOI. Motion2Live verifies the ftyp box, extracts the stream directly, and pairs it for Apple Photos."
    }
  };

  const I18N = {
    zh: {
      pageTitle: "Motion2Live — 安卓动态照片与 Apple 实况照片离线互转（iPhone / iPad / Mac）",
      pageDescription: "纯离线原生应用，在 iPhone、iPad 与 Mac 上解析小米、Pixel、三星、华为、OPPO 与 vivo 动态照片，导出为原生 Apple 实况照片、MP4 视频或 GIF，并支持将 Apple 实况逆向封装回安卓动态照片。",
      skipToContent: "跳至正文",
      navAria: "主导航",
      langAria: "切换语言",
      navFormats: "格式工作台",
      navTools: "精细工具",
      navPrivacy: "隐私规格",
      navFaq: "常见问题",
      heroTitle: "让安卓动态照片，在 iPhone 相册里重新动起来",
      heroLead: "从安卓传到 iPhone 的动态照片，视频其实还在原图里。Motion2Live 在本机解析小米、Pixel、三星、华为、OPPO 与 vivo 的文件结构，导出为原生 Apple 实况照片、独立视频或 GIF，也能把 Apple 实况转回各品牌安卓动态照片。",
      ctaPrimaryStore: "在 App Store 下载 Motion2Live",
      ctaSecondaryGithub: "查看 GitHub 源码",
      heroMicrocopyStore: "支持 iPhone、iPad 与 Mac（iOS 16+ / macOS 14.4+），以 MPL-2.0 协议开源，纯离线运行且无需注册账号。",
      stageAria: "交互式动态照片预览舞台",
      stageModeAria: "切换舞台视图",
      stageTotalSizeAria: "容器总大小",
      stageFootnoteAria: "示范照片字节构成摘要",
      stageTabPreview: "画面预览",
      stageTabBytes: "透视文件字节",
      heroLeftAlt: "火花动态照片样例",
      heroRightAlt: "树叶与小猫动态照片样例",
      heroCenterAlt: "海岸日落动态照片",
      stageHintHold: "按住预览动态",
      stageHintTap: "轻点播放动态",
      stageHintPlaying: "正在播放动态",
      byteVerified: "ftyp 偏移校验通过",
      byteMapAria: "动态照片容器字节分段",
      byteJpegLabel: "JPEG 静图",
      byteXmpLabel: "XMP 元数据",
      byteMp4Label: "内嵌 MP4",
      byteDescJpeg: BYTE_SEGMENTS.jpeg.zh,
      mechTitle: "同一张照片，为什么在 iOS 相册里变成了静态图",
      mechBody: "小米、Google Pixel、三星等安卓手机把动态视频直接拼接在 JPEG 文件末尾，并用 XMP 字段或 SEF 尾部标记记录偏移位置。Apple 相册只认配对的静图与 QuickTime 媒体标识符，因此直接导入时只会显示前半段静态画面。Motion2Live 读取原文件中的视频字节，写入 Apple Maker \"17\" 与配对标识，让系统相册把它识别为真正的实况照片。",
      compareIgnoredChunk: "MP4 453 KB (忽略)",
      compareStateStatic: "静态图片",
      compareStateLive: "原生实况照片",
      compareLeftTitle: "直接导入 iOS 相册",
      compareLeftBody: "前半段 JPEG 正常显示，尾部 MP4 数据被系统忽略，长按无反应。",
      compareRightTitle: "经 Motion2Live 转换",
      compareRightBody: "提取原视频流并按 Apple 规范配对封装，长按直接播放，拍摄时间与 GPS 原样保留。",
      wbTitle: "双向转换，按各品牌规范解析与封装",
      wbIntro: "换机迁移、跨系统互传原图，或者把 iPhone 拍的实况发回安卓相册，都在同一个工具里完成。",
      wbTabsAria: "切换转换方向",
      wbTabForwardLeft: "安卓动态照片",
      wbTabForwardRight: "Apple 格式",
      wbTabReverseLeft: "Apple 实况照片",
      wbTabReverseRight: "安卓动态照片",
      wbFwdInputTitle: "识别来源",
      wbFwdInputBody: "小米（含 HyperOS 2 与早期 MicroVideo）、Google Pixel、三星（含 SEF 容器）、华为、OPPO 与一加、vivo，以及通用 MP4 拼接格式。",
      brandXiaomi: "小米",
      brandSamsung: "三星",
      brandHuawei: "华为",
      brandOppo: "OPPO 与一加",
      brandUniversal: "通用拼接格式",
      wbFwdPipeTitle: "本地解析管线",
      wbFwdStep1: "只读二进制探测，不修改原始照片文件",
      wbFwdStep2: "校验尾部 ftyp 签名与字节偏移边界",
      wbFwdStep3: "按原流提取视频，保留 EXIF、拍摄时间与 GPS",
      wbFwdStep4: "写入 Apple Maker \"17\" 与 QuickTime 配对标识",
      wbFwdOutTitle: "导出选项",
      wbOutLiveTitle: "原生 Apple 实况照片",
      wbOutLiveBody: "写入系统相册即可长按播放，保留原图 EXIF、拍摄时间与地理坐标。",
      wbOutVideoTitle: "独立 MP4 / MOV 视频",
      wbOutVideoBody: "直接提取内嵌视频片段，便于剪辑或发送给不支持实况的聊天软件。",
      wbOutGifTitle: "GIF 动图",
      wbOutGifBody: "按设定帧率与尺寸采样输出，方便直接贴进文档或社交评论区。",
      wbRevInputTitle: "识别来源",
      wbRevInputBody: "直接从系统相册选取任意 Apple Live Photo。",
      wbRevSourceDetail: "读取配对静图（HEIC / JPEG）与 QuickTime MOV 视频轨道，以及原始拍摄时间戳与地理位置。",
      wbRevPipeTitle: "封装方式",
      wbRevPipeBody: "非 JPEG 静图（如 HEIC）在保留方向与 EXIF 的前提下转为高质量 JPEG 并清理冲突旧标签；配对视频优先通过 Passthrough 直接混流为 MP4，按你指定的目标品牌结构封装为单个 .jpg 文件，并在导出前完成容器自校验。",
      wbRevStep1: "HEIC 静图以 0.95 质量转 JPEG，保留方向与 EXIF",
      wbRevStep2: "剥离冲突旧 XMP 块，优先 Passthrough 混流 MOV 为 MP4",
      wbRevStep3: "按目标品牌写入容器标签并自校验输出字节",
      wbRevOutTitle: "导出方式",
      wbRevOutBody: "同步文件拍摄时间戳，通过系统分享面板或「文件」App 保留原始字节导出。",
      toolsSectionTitle: "精细工具",
      craftMainTitle: "挑一帧更好的封面，看清文件里的每一段字节",
      craftMainBody: "很多动态照片的默认封面恰好落在眨眼或晃动的那一瞬。拖动胶卷时间轴到毫秒级位置，选定清晰的静态帧作为新的实况封面，同时保留原图拍摄参数与位置信息。打开元数据检查器，还能查看静图与视频的体积占比、编码规格与原始 XMP 字段，一键复制摘要用于排查问题。",
      kfVideoAria: "关键帧封面预览视频",
      kfStatusDefault: "默认封面帧",
      kfStatusCustom: "自定义封面帧",
      kfExifKept: "EXIF / GPS 保留",
      kfSliderLabel: "选择封面关键帧时间点",
      kfResetBtn: "回到默认帧",
      inspTitle: "容器结构与元数据",
      inspCopyBtn: "复制摘要",
      inspCopied: "已复制容器摘要到剪贴板。",
      inspCopyFailed: "当前环境不支持剪贴板写入。",
      inspCodec: "视频编码",
      inspResolution: "画面与帧率",
      batchTitle: "一次选几十张，自动筛掉普通静图",
      batchBody: "批量导入相册照片时，Motion2Live 会先逐张探测容器结构，自动跳过不含视频流的普通静态图片。导出过程采用串行管线控制内存占用，整批转换为实况照片、视频或 GIF。",
      batchShotAlt: "Motion2Live 批量转换界面，展示自动忽略普通静图与缩略图网格",
      shareLabTitle: "从系统分享菜单直达，也能自定义合成",
      shareLabBody: "在相册、「文件」或聊天软件里点一下分享，即可在扩展面板中原地预览并保存为实况、视频或 GIF。想把任意一张照片和一段短视频合成为 Apple 实况或安卓动态照片，打开顶部「实验室」即可双向拼装。",
      shareCardTitle: "Share Extension",
      shareCardDesc: "无需切回主应用，在系统分享表单中直接识别并保存为实况、视频或 GIF。",
      labCardTitle: "自定义合成实验室",
      labCardDesc: "将任意静图与短视频封装为 Apple Live Photo，或指定品牌格式的安卓动态照片。",
      platTitle: "iPhone、iPad 与 Mac，同一套本地引擎",
      platBody: "全部界面基于 SwiftUI 与 Apple 原生媒体框架构建。在 iPhone 与 iPad 上可直接从相册或分享菜单处理；在 Mac 上支持从访达直接拖入动态照片或批量导入本地文件夹。界面支持简体中文、英文、日文、韩文、法文、德文与西班牙文 7 种语言。",
      macShotAlt: "Motion2Live macOS 主界面窗口，支持拖放动态照片文件",
      iphoneShotAlt: "Motion2Live iPhone 深色暗房详情播放与导出界面",
      platMacCap: "支持访达文件拖放与原生看片舞台",
      platIosCap: "适配系统相册选择器与全屏暗房预览",
      privTitle: "照片始终留在你的设备上",
      privIntro: "Motion2Live 依赖系统原生框架完成所有二进制解析与音视频混流，不接入任何第三方 SDK，代码以 MPL-2.0 协议开源。",
      privKey1: "网络连接",
      privVal1: "0 次请求。离线可用，不设后端服务器，不接入统计、广告或崩溃上报框架。",
      privKey2: "选图权限",
      privVal2: "调用系统 PHPickerViewController，应用仅能接触你主动勾选的照片，不请求读取整个图库。",
      privKey3: "保存权限",
      privVal3: "仅在写入结果时请求 Add-Only 权限，无法读取、修改或删除相册中的其他内容。",
      privKey4: "临时缓存",
      privVal4: "解析产生的临时媒体仅存于 NSTemporaryDirectory，导出完成或离开页面后立即清除。首页最近转换最多缓存 3 张缩略图，可随时关闭或清空。",
      privKey5: "首次试玩",
      privVal5: "内置 3 张示范动态照片，安装打开就能体验预览与关键帧调整，确认好用再授予保存权限。",
      privKey6: "合规与源码",
      privVal6Prefix: "内置 Apple PrivacyInfo.xcprivacy 隐私清单，可查阅完整",
      privPolicyLink: "隐私政策",
      privVal6Mid: "，或在 ",
      privGithubLink: "GitHub",
      privVal6Suffix: " 审查全部源码。",
      faqTitle: "常见问题",
      faqQ1: "换了 iPhone 后，旧安卓手机里的动态照片怎么导进来最好？",
      faqA1: "请尽量通过「文件」传输、AirDrop/局域网原图传输、数据线或云盘原文件下载，避免经过会自动压缩图片的聊天渠道。只要原 .jpg 文件尾部还保留 MP4 数据，Motion2Live 就能识别。",
      faqQ2: "转换后照片的拍摄时间和定位信息会丢失吗？",
      faqA2: "不会。导出 Apple 实况照片、更换关键帧封面以及逆向导出安卓动态照片时，都会保留原始 EXIF 拍摄时间、设备信息与 GPS 元数据，并同步文件时间戳。",
      faqQ3: "为什么某些动态照片导入后提示未检测到动态视频？",
      faqA3: "常见原因是图片在传输途中被社交软件或网盘重新压缩，导致拼接在 JPEG 末尾的 MP4 字节被剥离。你可以用 App 内的「元数据检查器」确认原文件是否仍包含视频流。",
      faqQ4: "支持哪些手机品牌的动态照片？",
      faqA4: "专门适配小米（含 HyperOS 2 与早期格式）、Google Pixel、三星（含 SEF 格式）、华为、OPPO/一加与 vivo，并提供通用 MP4 拼接兜底识别器。",
      faqQ5: "把 Apple 实况转回安卓动态照片后，发给安卓手机能直接播放吗？",
      faqA5: "在导出时选择对方手机对应的品牌格式（如小米、三星或 Pixel），并通过「文件」或发送原图传给对方，即可在对应品牌的系统相册中按原生动态照片识别。",
      faqQ6: "软件开源吗？需要联网或注册账号吗？",
      faqA6Store: "项目以 Mozilla Public License 2.0 协议在 GitHub 开源，纯离线运行、无需注册账号，可在 App Store 获取。",
      closingTitle: "把相册里静止的动态照片整理回来",
      closingSub: "适用于 iPhone、iPad 与 Mac，内置 3 张示范图，打开即可上手体验。",
      closingGithub: "访问 GitHub 仓库",
      footerPrivacy: "隐私政策",
      footerContact: "联系开发者"
    },
    en: {
      pageTitle: "Motion2Live — Convert Android Motion Photos & Apple Live Photos Offline",
      pageDescription: "Offline iPhone, iPad, and Mac app that converts Xiaomi, Pixel, Samsung, Huawei, OPPO, and vivo Motion Photos to Apple Live Photos, MP4, or GIF, and back again.",
      skipToContent: "Skip to content",
      navAria: "Primary navigation",
      langAria: "Language switch",
      navFormats: "Formats",
      navTools: "Tools",
      navPrivacy: "Privacy",
      navFaq: "FAQ",
      heroTitle: "Turn Android Motion Photos into native Apple Live Photos",
      heroLead: "When an Android Motion Photo lands on your iPhone, the video clip stays hidden inside the JPEG. Motion2Live unpacks Xiaomi, Pixel, Samsung, Huawei, OPPO, and vivo files on your device into native Live Photos, MP4s, or GIFs, and converts Apple Live Photos back to Android Motion Photos.",
      ctaPrimaryStore: "Download on the App Store",
      ctaSecondaryGithub: "Browse source on GitHub",
      heroMicrocopyStore: "For iPhone, iPad, and Mac (iOS 16+ / macOS 14.4+). Open source under MPL-2.0, runs offline on your device with no sign-up.",
      stageAria: "Interactive Motion Photo preview stage",
      stageModeAria: "Switch stage view",
      stageTotalSizeAria: "Container size",
      stageFootnoteAria: "Demo asset summary",
      stageTabPreview: "Live preview",
      stageTabBytes: "Inspect bytes",
      heroLeftAlt: "Sparkler Motion Photo sample",
      heroRightAlt: "Cat and foliage Motion Photo sample",
      heroCenterAlt: "Coastal sunset Motion Photo sample",
      stageHintHold: "Press and hold to play",
      stageHintTap: "Tap to play motion",
      stageHintPlaying: "Playing motion",
      byteVerified: "ftyp verified",
      byteMapAria: "Motion Photo byte segments",
      byteJpegLabel: "JPEG still",
      byteXmpLabel: "XMP index",
      byteMp4Label: "MP4 clip",
      byteDescJpeg: BYTE_SEGMENTS.jpeg.en,
      mechTitle: "Why Android Motion Photos freeze in Apple Photos",
      mechBody: "Android phones append the motion video to the end of a standard JPEG and mark the byte offset with XMP tags or a Samsung SEF trailer. Apple Photos expects a paired still image and QuickTime asset identifier, so it reads the JPEG and ignores the video bytes behind it. Motion2Live splits the stream locally, writes Apple Maker tag \"17\" and the matching content identifier, and saves a native Live Photo that plays on long press.",
      compareIgnoredChunk: "MP4 453 KB (ignored)",
      compareStateStatic: "Static image",
      compareStateLive: "Native Live Photo",
      compareLeftTitle: "Imported directly to iOS Photos",
      compareLeftBody: "Displays the leading JPEG only. The appended MP4 bytes sit unreadable.",
      compareRightTitle: "Converted with Motion2Live",
      compareRightBody: "Extracts the embedded clip, pairs it to Apple's Live Photo format, and keeps original EXIF and GPS dates.",
      wbTitle: "Convert in both directions across seven brand formats",
      wbIntro: "Move an Android photo library to iPhone, or send Apple Live Photos back to friends on Android in the container their gallery reads.",
      wbTabsAria: "Conversion direction",
      wbTabForwardLeft: "Android Motion Photo",
      wbTabForwardRight: "Apple",
      wbTabReverseLeft: "Apple Live Photo",
      wbTabReverseRight: "Android Motion Photo",
      wbFwdInputTitle: "Supported sources",
      wbFwdInputBody: "Xiaomi (HyperOS 2 and legacy MicroVideo), Google Pixel, Samsung (including SEF trailers), Huawei, OPPO and OnePlus, vivo, plus a universal MP4 trailer parser.",
      brandXiaomi: "Xiaomi",
      brandSamsung: "Samsung",
      brandHuawei: "Huawei",
      brandOppo: "OPPO & OnePlus",
      brandUniversal: "Universal trailer",
      wbFwdPipeTitle: "On-device pipeline",
      wbFwdStep1: "Read-only binary probe without touching source files",
      wbFwdStep2: "Verify trailing ftyp box signature and byte bounds",
      wbFwdStep3: "Extract original stream while keeping EXIF, capture date, and GPS",
      wbFwdStep4: "Write Apple Maker \"17\" and QuickTime content identifier",
      wbFwdOutTitle: "Outputs",
      wbOutLiveTitle: "Native Apple Live Photo",
      wbOutLiveBody: "Saves straight to Apple Photos with long-press playback, capture date, and GPS intact.",
      wbOutVideoTitle: "Standalone MP4 / MOV",
      wbOutVideoBody: "Extracts the embedded clip as a regular video file ready for editing or messaging apps.",
      wbOutGifTitle: "Animated GIF",
      wbOutGifBody: "Samples frames at your target size for chats, docs, and web posts.",
      wbRevInputTitle: "Source",
      wbRevInputBody: "Pick any Apple Live Photo from your library.",
      wbRevSourceDetail: "Reads the paired still image (HEIC / JPEG), QuickTime MOV track, capture timestamp, and location metadata.",
      wbRevPipeTitle: "Packaging",
      wbRevPipeBody: "Converts non-JPEG stills such as HEIC to quality-0.95 JPEG while keeping EXIF orientation and capture metadata, strips conflicting XMP blocks, remuxes the paired MOV to MP4 via passthrough when compatible, builds the chosen brand container, and verifies the output bytes before export.",
      wbRevStep1: "Convert HEIC stills to 0.95 JPEG while preserving EXIF and orientation",
      wbRevStep2: "Strip conflicting XMP blocks and remux MOV to MP4 via passthrough",
      wbRevStep3: "Build the selected brand container and verify output bytes",
      wbRevOutTitle: "Export",
      wbRevOutBody: "Syncs original file timestamps and exports raw bytes through the Share Sheet or Files app.",
      toolsSectionTitle: "Precision tools",
      craftMainTitle: "Pick a sharper cover frame and inspect the file structure",
      craftMainBody: "Default covers often land mid-blink. Scrub the embedded filmstrip down to the millisecond to pick a clean still frame while keeping original EXIF, TIFF, and GPS metadata. Open the structure inspector to see exact JPEG-to-MP4 byte ratios, video codec and frame rate, and raw XMP tags, with one-tap summary copy.",
      kfVideoAria: "Keyframe cover preview video",
      kfStatusDefault: "Default cover",
      kfStatusCustom: "Custom cover",
      kfExifKept: "EXIF / GPS kept",
      kfSliderLabel: "Scrub keyframe cover timestamp",
      kfResetBtn: "Reset default",
      inspTitle: "Container structure & metadata",
      inspCopyBtn: "Copy summary",
      inspCopied: "Container summary copied to clipboard.",
      inspCopyFailed: "Clipboard write is unavailable here.",
      inspCodec: "Video codec",
      inspResolution: "Dimensions & rate",
      batchTitle: "Drop a whole batch and skip static photos automatically",
      batchBody: "Select dozens of mixed photos from your library. Motion2Live probes each file first, skips ordinary static JPEGs, and exports valid Motion Photos serially to keep memory steady across Live Photo, Video, or GIF output.",
      batchShotAlt: "Motion2Live batch screen showing static photos automatically skipped and thumbnail grid",
      shareLabTitle: "Convert from any Share Sheet, or pair your own media in Lab",
      shareLabBody: "Trigger Motion2Live straight from Photos, Files, or chat apps to preview and save without switching windows. Open Lab to combine any still photo and video clip into a custom Apple Live Photo or Android Motion Photo.",
      shareCardTitle: "Share Extension",
      shareCardDesc: "Preview and save as Live Photo, MP4, or GIF directly inside the system Share Sheet.",
      labCardTitle: "Custom Media Lab",
      labCardDesc: "Combine any still photo and short video into an Apple Live Photo or brand-specific Android Motion Photo.",
      platTitle: "Built natively for iPhone, iPad, and Mac",
      platBody: "Written purely with SwiftUI, AVFoundation, PhotosUI, and ImageIO. Use the system picker or Share Extension on iPhone and iPad, or drag local Motion Photo folders straight into the Mac window. Localized in English, Simplified Chinese, Japanese, Korean, French, German, and Spanish.",
      macShotAlt: "Motion2Live macOS home window supporting drag-and-drop Motion Photos",
      iphoneShotAlt: "Motion2Live iPhone darkroom detail playback and export screen",
      platMacCap: "Finder drag-and-drop and native darkroom stage",
      platIosCap: "System photo picker and full-bleed playback",
      privTitle: "Your photos stay on your device",
      privIntro: "Motion2Live parses and packages every file locally with Apple frameworks and ships under the MPL-2.0 open-source license.",
      privKey1: "Network traffic",
      privVal1: "0 requests. Works completely offline with zero backend servers, analytics, or crash SDKs.",
      privKey2: "Photo read access",
      privVal2: "Uses Apple's PHPickerViewController. The app only sees items you pick and never requests full library read access.",
      privKey3: "Photo write access",
      privVal3: "Requests Add-Only permission solely when saving exported media. Cannot read, edit, or delete existing items.",
      privKey4: "Temporary files",
      privVal4: "Written strictly inside NSTemporaryDirectory and removed as soon as export finishes or you leave the screen. Recent conversions cache at most 3 thumbnails and can be cleared anytime.",
      privKey5: "Try before granting access",
      privVal5: "Ships with 3 built-in demo Motion Photos so you can test playback and cover scrubbing right after install.",
      privKey6: "Verification",
      privVal6Prefix: "Includes PrivacyInfo.xcprivacy. Read the full ",
      privPolicyLink: "Privacy Policy",
      privVal6Mid: " or inspect the full source code on ",
      privGithubLink: "GitHub",
      privVal6Suffix: ".",
      faqTitle: "Frequently asked questions",
      faqQ1: "How should I transfer Android Motion Photos to my iPhone so the video stays intact?",
      faqA1: "Transfer original files via Files, local network transfer, cable, or cloud drive original download. Messaging apps that recompress JPEGs strip the appended MP4 video bytes.",
      faqQ2: "Does conversion keep my capture date and GPS location?",
      faqA2: "Yes. Live Photo export, custom keyframe cover extraction, and reverse Motion Photo export preserve original EXIF capture timestamps, orientation, and GPS coordinates, and sync output file timestamps.",
      faqQ3: "Why did a photo from my Android phone show up as static?",
      faqA3: "The file was likely re-encoded during transfer or backup, which removes the trailing MP4 stream. Open it in the built-in Metadata Inspector to check whether an embedded video segment is still present.",
      faqQ4: "Which phone brands are supported?",
      faqA4: "Dedicated parsers and reverse encoders cover Xiaomi (HyperOS 2 and older MicroVideo), Google Pixel, Samsung (SEF), Huawei, OPPO / OnePlus, and vivo, backed by a universal MP4 trailer parser.",
      faqQ5: "Will a reverse-converted Apple Live Photo play on an Android phone?",
      faqA5: "Choose the recipient's phone brand before exporting and send the .jpg as an original file through Files or a lossless channel so the Android gallery recognizes its container tags.",
      faqQ6: "Is Motion2Live open source? Does it require an account?",
      faqA6Store: "Motion2Live is open source under MPL-2.0 on GitHub, runs completely offline with no sign-up, and is available on the App Store.",
      closingTitle: "Bring your Android Motion Photos to life in Apple Photos",
      closingSub: "Available for iPhone, iPad, and Mac, with three built-in demo photos ready on launch.",
      closingGithub: "View source on GitHub",
      footerPrivacy: "Privacy Policy",
      footerContact: "Contact"
    }
  };

  let currentLang = "zh";
  let currentByteSeg = "jpeg";
  let isHeroPlaying = false;
  let isTouchPrimary = false;

  const reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  const touchPrimaryQuery = window.matchMedia("(hover: none), (pointer: coarse)");
  isTouchPrimary = touchPrimaryQuery.matches;

  function formatTimecode(ms) {
    const clamped = Math.max(0, Math.min(2417, ms));
    const sec = Math.floor(clamped / 1000);
    const centi = Math.floor((clamped % 1000) / 10);
    return "00:" + String(sec).padStart(2, "0") + "." + String(centi).padStart(2, "0");
  }

  function updatePrimaryCtas(lang) {
    const dict = I18N[lang];
    const targetUrl = APP_STORE_URL.trim();

    document.querySelectorAll("[data-primary-cta]").forEach(function (link) {
      link.setAttribute("href", targetUrl);
      link.textContent = dict.ctaPrimaryStore;
    });

    const microEl = document.querySelector("[data-hero-microcopy]");
    if (microEl) {
      microEl.textContent = dict.heroMicrocopyStore;
    }

    const faqA6El = document.querySelector("[data-faq-a6]");
    if (faqA6El) {
      faqA6El.textContent = dict.faqA6Store;
    }
  }

  function updateStageHint() {
    const hintEl = document.querySelector("[data-stage-hint]");
    if (!hintEl) return;
    const dict = I18N[currentLang];
    if (isHeroPlaying) {
      hintEl.textContent = dict.stageHintPlaying;
    } else {
      hintEl.textContent = isTouchPrimary ? dict.stageHintTap : dict.stageHintHold;
    }
  }

  function updateByteDetail(segKey) {
    currentByteSeg = BYTE_SEGMENTS[segKey] ? segKey : "jpeg";
    const info = BYTE_SEGMENTS[currentByteSeg];
    const markerEl = document.getElementById("byte-detail-marker");
    const rangeEl = document.getElementById("byte-detail-range");
    const descEl = document.getElementById("byte-detail-desc");

    if (markerEl) markerEl.textContent = info.marker;
    if (rangeEl) rangeEl.textContent = info.range;
    if (descEl) descEl.textContent = info[currentLang];

    document.querySelectorAll("[data-byte-seg]").forEach(function (btn) {
      const active = btn.getAttribute("data-byte-seg") === currentByteSeg;
      btn.classList.toggle("is-selected", active);
      btn.setAttribute("aria-pressed", active ? "true" : "false");
    });

    document.querySelectorAll("[data-byte-card]").forEach(function (btn) {
      const active = btn.getAttribute("data-byte-card") === currentByteSeg;
      btn.classList.toggle("is-selected", active);
      btn.setAttribute("aria-pressed", active ? "true" : "false");
    });
  }

  function updateKeyframeStatus(ms) {
    const statusEl = document.getElementById("kf-cover-status");
    if (!statusEl) return;
    const dict = I18N[currentLang];
    statusEl.textContent = Math.abs(ms - DEFAULT_COVER_MS) <= 15 ? dict.kfStatusDefault : dict.kfStatusCustom;
  }

  function applyLanguage(lang, syncUrl) {
    currentLang = lang === "en" ? "en" : "zh";
    const dict = I18N[currentLang];

    document.documentElement.lang = currentLang === "zh" ? "zh-CN" : "en";
    document.title = dict.pageTitle;

    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) {
      metaDesc.setAttribute("content", dict.pageDescription);
    }

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      const key = el.getAttribute("data-i18n");
      if (key && Object.prototype.hasOwnProperty.call(dict, key)) {
        el.textContent = dict[key];
      }
    });

    document.querySelectorAll("[data-i18n-aria]").forEach(function (el) {
      const key = el.getAttribute("data-i18n-aria");
      if (key && Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("aria-label", dict[key]);
      }
    });

    document.querySelectorAll("[data-i18n-alt]").forEach(function (el) {
      const key = el.getAttribute("data-i18n-alt");
      if (key && Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("alt", dict[key]);
      }
    });

    document.querySelectorAll("[data-lang-btn]").forEach(function (btn) {
      const active = btn.getAttribute("data-lang-btn") === currentLang;
      btn.classList.toggle("is-active", active);
      btn.setAttribute("aria-pressed", active ? "true" : "false");
    });

    document.querySelectorAll("[data-privacy-link]").forEach(function (link) {
      link.setAttribute("href", "./privacy-policy.html?lang=" + currentLang);
    });

    updatePrimaryCtas(currentLang);
    updateStageHint();
    updateByteDetail(currentByteSeg);

    const slider = document.getElementById("keyframe-slider");
    if (slider) {
      updateKeyframeStatus(Number(slider.value));
    }

    const feedbackEl = document.getElementById("copy-feedback");
    if (feedbackEl) {
      feedbackEl.textContent = "";
    }

    if (syncUrl && window.history && typeof window.history.replaceState === "function") {
      try {
        const url = new URL(window.location.href);
        url.searchParams.set("lang", currentLang);
        window.history.replaceState(null, "", url.toString());
      } catch (_err) {
        // Ignore file:// URL mutation limits
      }
    }
  }

  function setupLanguageSwitch() {
    document.querySelectorAll("[data-lang-btn]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        const target = btn.getAttribute("data-lang-btn");
        applyLanguage(target, true);
      });
    });

    const params = new URLSearchParams(window.location.search);
    const qLang = params.get("lang");
    if (qLang === "en" || qLang === "zh") {
      applyLanguage(qLang, false);
    } else {
      const navLang = (navigator.language || "zh").toLowerCase();
      applyLanguage(navLang.startsWith("zh") ? "zh" : "en", false);
    }
  }

  function setupHeroStage() {
    const deck = document.getElementById("live-deck");
    const card = document.getElementById("live-card");
    const video = document.getElementById("hero-video");
    const playBtn = document.getElementById("hero-play-btn");
    const durationEl = document.getElementById("hero-duration");
    const modeTabs = Array.from(document.querySelectorAll("[data-stage-mode]"));
    const previewPanel = document.getElementById("stage-panel-preview");
    const bytesPanel = document.getElementById("stage-panel-bytes");

    if (!deck || !card || !video || !playBtn) return;

    isTouchPrimary = touchPrimaryQuery.matches;
    updateStageHint();

    const onTouchMediaChange = function (event) {
      isTouchPrimary = event.matches;
      updateStageHint();
    };
    if (typeof touchPrimaryQuery.addEventListener === "function") {
      touchPrimaryQuery.addEventListener("change", onTouchMediaChange);
    } else if (typeof touchPrimaryQuery.addListener === "function") {
      touchPrimaryQuery.addListener(onTouchMediaChange);
    }

    let videoFailed = false;
    let holdActive = false;
    let touchTap = null;
    const TAP_MOVE_THRESHOLD_PX = 10;

    video.addEventListener("error", function () {
      videoFailed = true;
      stopPlayback();
    });

    video.addEventListener("timeupdate", function () {
      if (isHeroPlaying && durationEl && Number.isFinite(video.currentTime)) {
        durationEl.textContent = video.currentTime.toFixed(2) + "s";
      }
    });

    function startPlayback() {
      if (videoFailed) return;
      isHeroPlaying = true;
      deck.setAttribute("data-playing", "true");
      playBtn.setAttribute("aria-pressed", "true");
      updateStageHint();

      if (reducedMotionQuery.matches) {
        video.loop = false;
      } else {
        video.loop = true;
      }

      const playPromise = video.play();
      if (playPromise && typeof playPromise.catch === "function") {
        playPromise.catch(function () {
          stopPlayback();
        });
      }
    }

    function stopPlayback() {
      isHeroPlaying = false;
      holdActive = false;
      deck.setAttribute("data-playing", "false");
      playBtn.setAttribute("aria-pressed", "false");
      try {
        video.pause();
        video.currentTime = 0;
      } catch (_err) {
        // Ignore seek errors before metadata loads
      }
      if (durationEl) {
        durationEl.textContent = "2.42s";
      }
      updateStageHint();
    }

    video.addEventListener("ended", function () {
      if (!video.loop) {
        stopPlayback();
      }
    });

    // Desktop: press-and-hold on the center photo card.
    // Touch: only toggle on clean tap (pointerup within 10px, never during scroll).
    card.addEventListener("pointerdown", function (event) {
      if (event.target.closest("#hero-play-btn")) return;
      if (event.pointerType === "touch" || isTouchPrimary) {
        touchTap = {
          pointerId: event.pointerId,
          startX: event.clientX,
          startY: event.clientY,
          moved: false
        };
        return;
      }
      holdActive = true;
      startPlayback();
    });

    card.addEventListener("pointermove", function (event) {
      if (!touchTap || event.pointerId !== touchTap.pointerId) return;
      const dx = event.clientX - touchTap.startX;
      const dy = event.clientY - touchTap.startY;
      if (Math.hypot(dx, dy) > TAP_MOVE_THRESHOLD_PX) {
        touchTap.moved = true;
      }
    });

    card.addEventListener("pointerup", function (event) {
      if (event.target.closest("#hero-play-btn")) {
        touchTap = null;
        return;
      }
      if (touchTap && event.pointerId === touchTap.pointerId) {
        const wasCleanTap = !touchTap.moved;
        touchTap = null;
        if (wasCleanTap) {
          if (isHeroPlaying) {
            stopPlayback();
          } else {
            startPlayback();
          }
        }
        return;
      }
      if (event.pointerType !== "touch" && holdActive) {
        stopPlayback();
      }
    });

    card.addEventListener("pointerleave", function () {
      if (holdActive) {
        stopPlayback();
      }
    });

    card.addEventListener("pointercancel", function () {
      touchTap = null;
      if (holdActive) {
        stopPlayback();
      }
    });

    // Click/keyboard toggle on the trigger button
    playBtn.addEventListener("click", function () {
      if (isHeroPlaying) {
        stopPlayback();
      } else {
        startPlayback();
      }
    });

    function switchStageMode(mode) {
      const isBytes = mode === "bytes";
      if (isBytes && isHeroPlaying) {
        stopPlayback();
      }
      modeTabs.forEach(function (tab) {
        const active = tab.getAttribute("data-stage-mode") === mode;
        tab.classList.toggle("is-active", active);
        tab.setAttribute("aria-selected", active ? "true" : "false");
        tab.setAttribute("tabindex", active ? "0" : "-1");
      });
      if (previewPanel) previewPanel.hidden = isBytes;
      if (bytesPanel) bytesPanel.hidden = !isBytes;
    }

    modeTabs.forEach(function (tab, index) {
      tab.addEventListener("click", function () {
        switchStageMode(tab.getAttribute("data-stage-mode"));
      });
      tab.addEventListener("keydown", function (event) {
        if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
          event.preventDefault();
          const next = modeTabs[(index + 1) % modeTabs.length];
          next.focus();
          switchStageMode(next.getAttribute("data-stage-mode"));
        }
      });
    });

    document.querySelectorAll("[data-byte-seg]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        updateByteDetail(btn.getAttribute("data-byte-seg"));
      });
    });

    document.querySelectorAll("[data-byte-card]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        updateByteDetail(btn.getAttribute("data-byte-card"));
      });
    });
  }

  function setupWorkbenchTabs() {
    const tabs = Array.from(document.querySelectorAll("[data-wb-tab]"));
    const fwdPanel = document.getElementById("wb-panel-forward");
    const revPanel = document.getElementById("wb-panel-reverse");
    if (!tabs.length || !fwdPanel || !revPanel) return;

    function activate(tabKey) {
      const isForward = tabKey === "forward";
      tabs.forEach(function (tab) {
        const active = tab.getAttribute("data-wb-tab") === tabKey;
        tab.classList.toggle("is-active", active);
        tab.setAttribute("aria-selected", active ? "true" : "false");
        tab.setAttribute("tabindex", active ? "0" : "-1");
      });
      fwdPanel.hidden = !isForward;
      revPanel.hidden = isForward;
    }

    tabs.forEach(function (tab, index) {
      tab.addEventListener("click", function () {
        activate(tab.getAttribute("data-wb-tab"));
      });
      tab.addEventListener("keydown", function (event) {
        if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
          event.preventDefault();
          const next = tabs[(index + 1) % tabs.length];
          next.focus();
          activate(next.getAttribute("data-wb-tab"));
        }
      });
    });
  }

  function setupKeyframeScrubber() {
    const slider = document.getElementById("keyframe-slider");
    const video = document.getElementById("keyframe-video");
    const timecodeEl = document.getElementById("kf-timecode");
    const frameEl = document.getElementById("kf-frame-index");
    const playheadEl = document.getElementById("kf-playhead");
    const resetBtn = document.getElementById("kf-reset-btn");
    const copyBtn = document.getElementById("copy-summary-btn");
    const feedbackEl = document.getElementById("copy-feedback");

    if (!slider || !video) return;

    let pendingSeekSec = DEFAULT_COVER_MS / 1000;

    function seekVideo(sec) {
      const maxSec =
        Number.isFinite(video.duration) && video.duration > 0.05
          ? video.duration - 0.02
          : DEMO_DURATION_SEC - 0.02;
      pendingSeekSec = Math.max(0, Math.min(maxSec, sec));
      if (video.readyState >= 1) {
        try {
          video.currentTime = pendingSeekSec;
        } catch (_err) {
          // Ignore seek errors on locked streams
        }
      }
    }

    video.addEventListener("loadedmetadata", function () {
      seekVideo(pendingSeekSec);
    });

    function syncScrubber(ms) {
      const sec = ms / 1000;
      const pct = (ms / 2417) * 100;
      const frame = Math.min(DEMO_TOTAL_FRAMES, Math.max(1, Math.round((ms / 2417) * (DEMO_TOTAL_FRAMES - 1)) + 1));
      const formatted = formatTimecode(ms);

      slider.value = String(ms);
      slider.setAttribute("aria-valuenow", String(ms));
      slider.setAttribute("aria-valuetext", formatted);

      if (timecodeEl) timecodeEl.textContent = formatted;
      if (frameEl) frameEl.textContent = "Frame " + frame + " / " + DEMO_TOTAL_FRAMES;
      if (playheadEl) playheadEl.style.left = pct.toFixed(2) + "%";

      updateKeyframeStatus(ms);
      seekVideo(sec);
    }

    slider.addEventListener("input", function () {
      syncScrubber(Number(slider.value));
    });

    if (resetBtn) {
      resetBtn.addEventListener("click", function () {
        syncScrubber(DEFAULT_COVER_MS);
      });
    }

    if (copyBtn && feedbackEl) {
      copyBtn.addEventListener("click", function () {
        const ms = Number(slider.value);
        const summary = [
          "Motion2Live Container Summary",
          "File: MVIMG_coast_demo.jpg (614,492 bytes / 600 KB)",
          "JPEG Still: 146,462 bytes (24%, 731x980, EXIF/GPS preserved)",
          "XMP APP1: 4,096 bytes (1%, GCamera:MotionPhoto=1)",
          "MP4 Stream: 463,934 bytes (75%, H.264 avc1, 720x960, 24 fps, 2.42s)",
          "ftyp Offset: 0x024C1E (verified)",
          "Selected Cover: " + formatTimecode(ms)
        ].join("\n");

        if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
          navigator.clipboard.writeText(summary).then(
            function () {
              feedbackEl.textContent = I18N[currentLang].inspCopied;
            },
            function () {
              feedbackEl.textContent = I18N[currentLang].inspCopyFailed;
            }
          );
        } else {
          feedbackEl.textContent = I18N[currentLang].inspCopyFailed;
        }
      });
    }

    syncScrubber(DEFAULT_COVER_MS);
  }

  function setupFaqAccordion() {
    const triggers = Array.from(document.querySelectorAll(".faq-trigger"));
    triggers.forEach(function (trigger) {
      trigger.addEventListener("click", function () {
        const expanded = trigger.getAttribute("aria-expanded") === "true";
        const panelId = trigger.getAttribute("aria-controls");
        const panel = panelId ? document.getElementById(panelId) : null;
        trigger.setAttribute("aria-expanded", expanded ? "false" : "true");
        if (panel) {
          panel.hidden = expanded;
        }
      });
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    setupLanguageSwitch();
    setupHeroStage();
    setupWorkbenchTabs();
    setupKeyframeScrubber();
    setupFaqAccordion();
  });
})();
