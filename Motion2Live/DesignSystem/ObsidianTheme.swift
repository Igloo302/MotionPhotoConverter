//
//  ObsidianTheme.swift
//  Motion2Live
//
//  Adaptive Light & Dark Design System (Obsidian Dark / Porcelain Light)
//  with Apple HIG-compliant iOS 26+ Liquid Glass controls & iOS 16+ fallbacks.
//

import SwiftUI
import UIKit

// MARK: - Adaptive Color Tokens
enum AppTheme {
    private static func adaptive(dark: UIColor, light: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// 主画布背景 (Dark: #0B0D0F, Light: #F4F6F9)
    static let canvas = adaptive(
        dark: UIColor(red: 0.043, green: 0.051, blue: 0.059, alpha: 1),
        light: UIColor(red: 0.957, green: 0.965, blue: 0.976, alpha: 1)
    )

    /// 卡片底层 (Dark: #121518, Light: #FFFFFF)
    static let surface0 = adaptive(
        dark: UIColor(red: 0.071, green: 0.082, blue: 0.094, alpha: 1),
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    )

    /// 容器层级 (Dark: #181B1F, Light: #EBEEF3)
    static let surface1 = adaptive(
        dark: UIColor(red: 0.094, green: 0.106, blue: 0.122, alpha: 1),
        light: UIColor(red: 0.922, green: 0.933, blue: 0.953, alpha: 1)
    )

    /// 高亮/次级容器 (Dark: #202429, Light: #E1E6EE)
    static let surface2 = adaptive(
        dark: UIColor(red: 0.125, green: 0.141, blue: 0.161, alpha: 1),
        light: UIColor(red: 0.882, green: 0.902, blue: 0.933, alpha: 1)
    )

    /// 细描边 (Dark: #2A2F36, Light: #D4DBE5)
    static let borderSubtle = adaptive(
        dark: UIColor(red: 0.165, green: 0.184, blue: 0.212, alpha: 0.95),
        light: UIColor(red: 0.831, green: 0.859, blue: 0.898, alpha: 0.95)
    )

    /// 主强调色 (Dark: Electric Cyan #38BCE0, Light: Deep Cyan-Blue #0284C7)
    static let accent = adaptive(
        dark: UIColor(red: 0.220, green: 0.737, blue: 0.878, alpha: 1),
        light: UIColor(red: 0.008, green: 0.518, blue: 0.780, alpha: 1)
    )

    /// 液态玻璃主按钮渐变起止色
    static let accentGradientTop = adaptive(
        dark: UIColor(red: 0.220, green: 0.780, blue: 0.949, alpha: 0.92),
        light: UIColor(red: 0.098, green: 0.631, blue: 0.902, alpha: 0.94)
    )

    static let accentGradientBottom = adaptive(
        dark: UIColor(red: 0.059, green: 0.580, blue: 0.820, alpha: 0.96),
        light: UIColor(red: 0.008, green: 0.478, blue: 0.749, alpha: 0.98)
    )

    /// 主按钮文字色（液态玻璃主行动按钮统一高对比纯白）
    static let accentForeground = Color.white.opacity(0.98)

    /// 成功绿 (Dark: #30D158, Light: #248A3D)
    static let success = adaptive(
        dark: UIColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1),
        light: UIColor(red: 0.141, green: 0.541, blue: 0.239, alpha: 1)
    )

    /// 警告橙 (Dark: #FF9F0A, Light: #D97706)
    static let warning = adaptive(
        dark: UIColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1),
        light: UIColor(red: 0.851, green: 0.467, blue: 0.024, alpha: 1)
    )

    /// 错误红 (Dark: #FF453A, Light: #D70015)
    static let danger = adaptive(
        dark: UIColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1),
        light: UIColor(red: 0.843, green: 0.0, blue: 0.082, alpha: 1)
    )

    /// 主文字
    static let textPrimary = adaptive(
        dark: UIColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1),
        light: UIColor(red: 0.059, green: 0.078, blue: 0.098, alpha: 1)
    )

    /// 次级文字
    static let textSecondary = adaptive(
        dark: UIColor(red: 0.651, green: 0.678, blue: 0.722, alpha: 1),
        light: UIColor(red: 0.325, green: 0.376, blue: 0.439, alpha: 1)
    )

    /// 辅助文字
    static let textTertiary = adaptive(
        dark: UIColor(red: 0.420, green: 0.459, blue: 0.522, alpha: 1),
        light: UIColor(red: 0.514, green: 0.569, blue: 0.635, alpha: 1)
    )

    /// 舞台深色衬底（照片与视频预览区域在浅/深色下均保持柔和对比）
    static let stageBackground = adaptive(
        dark: UIColor(red: 0.063, green: 0.075, blue: 0.086, alpha: 1),
        light: UIColor(red: 0.910, green: 0.925, blue: 0.945, alpha: 1)
    )

    /// 照片内嵌静默角标底色（内容层专用，不使用玻璃效果）
    static let quietPhotoBadgeFill = Color(red: 0.039, green: 0.051, blue: 0.071).opacity(0.56)

    // MARK: - Layout Constants
    enum Radius {
        static let card: CGFloat = 24
        static let tile: CGFloat = 18
        static let stage: CGFloat = 24
        static let control: CGFloat = 14
        static let capsule: CGFloat = 27
        static let sheet: CGFloat = 38
    }
}

// MARK: - iPhone Duo Hinge Abstraction (iOS 16+ Safe, iOS 27.1+ Native)

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

    /// 处于有效半开姿态时启用折屏分栏体验
    var isFlexTabletopPosture: Bool {
        status == .partiallyOpen
    }

    /// 状态机防抖：同状态下角度变化 < 2° 不触发重绘
    static func resolveNext(
        current: HingeStateSnapshot,
        rawStatus: DuoHingeStatus,
        rawAngleDegrees: Double
    ) -> HingeStateSnapshot {
        if current.status == rawStatus && abs(current.angleDegrees - rawAngleDegrees) < 2.0 {
            return current
        }
        return HingeStateSnapshot(status: rawStatus, angleDegrees: rawAngleDegrees)
    }
}

extension View {
    /// 监听 iPhone Duo 铰链开合状态（iOS 27.1+ 启用原生 `.onHingeChange`，低版本零开销降级）
    @ViewBuilder
    func observeDeviceHinge(_ binding: Binding<HingeStateSnapshot>) -> some View {
        if #available(iOS 27.1, *) {
            onHingeChange { _, newContext in
                let mappedStatus: DuoHingeStatus
                let rawAngle: Double
                if let hinge = newContext.hinge {
                    rawAngle = hinge.angle.degrees
                    if hinge.status == .closed {
                        mappedStatus = .closed
                    } else if hinge.status == .partiallyOpen {
                        mappedStatus = .partiallyOpen
                    } else if hinge.status == .fullyOpen {
                        mappedStatus = .fullyOpen
                    } else {
                        mappedStatus = .unavailable
                    }
                } else {
                    mappedStatus = .unavailable
                    rawAngle = 0
                }
                let next = HingeStateSnapshot.resolveNext(
                    current: binding.wrappedValue,
                    rawStatus: mappedStatus,
                    rawAngleDegrees: rawAngle
                )
                if next != binding.wrappedValue {
                    binding.wrappedValue = next
                }
            }
        } else {
            self
        }
    }

    /// 全屏媒体检视器在 iOS 27.1+ 禁用侧边 Vertical Bar 以保持水平对称沉浸感
    @ViewBuilder
    func immersiveToolbarVerticalBehaviorDisabled() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }

    /// 跨 iOS 16 / iOS 17+ 无警告值监听辅助方法
    @ViewBuilder
    func onAdaptiveChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }
}

// MARK: - Adaptive Multi-Device Layout Metrics (iPhone / iPhone Duo / iPad)

enum DuoLayoutMode: Equatable, Sendable {
    case compactVertical          // 标准 iPhone 竖屏 / Duo 外屏 (466×678)
    case compactShortLandscape    // 矮横屏（如普通 iPhone 横屏）
    case unfoldedWideSplit        // Duo 内屏展开或 iPad 宽屏（含 669×951 竖向 & 951×669 横向）
    case hingeFlexSplit           // Duo 半开姿态：主预览区 + 独立控制区避让折痕
}

enum KeyframeSheetDetentMode: Equatable, Sendable {
    case largeOnly
    case mediumAndLarge
}

struct AdaptiveLayoutMetrics: Equatable {
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let horizontalSizeClass: UserInterfaceSizeClass?
    let verticalSizeClass: UserInterfaceSizeClass?
    let hinge: HingeStateSnapshot

    init(
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets = EdgeInsets(),
        horizontalSizeClass: UserInterfaceSizeClass?,
        verticalSizeClass: UserInterfaceSizeClass?,
        hinge: HingeStateSnapshot = .unavailable
    ) {
        self.containerSize = containerSize
        self.safeAreaInsets = safeAreaInsets
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
        self.hinge = hinge
    }

    /// 核心布局形态决策
    var layoutMode: DuoLayoutMode {
        if hinge.isFlexTabletopPosture {
            return .hingeFlexSplit
        }
        if isWideSplit {
            return .unfoldedWideSplit
        }
        if verticalSizeClass == .compact || containerSize.width > containerSize.height {
            return .compactShortLandscape
        }
        return .compactVertical
    }

    /// 矮屏判定（涵盖 Duo 外屏 678pt 与 Duo 内屏横屏 669pt）
    var isCompactShortScreen: Bool {
        containerSize.height <= 700
    }

    /// 宽屏横排模式（iPad、iPhone Duo 展开态 669×951 / 951×669、iPhone 横屏）
    var isWideSplit: Bool {
        if hinge.isFlexTabletopPosture {
            return true
        }
        if hinge.status == .fullyOpen {
            return containerSize.width >= 640 || (verticalSizeClass == .compact && containerSize.width >= 560)
        }
        return containerSize.width >= 660 || (verticalSizeClass == .compact && containerSize.width >= 560)
    }

    /// 宽画布（iPad 竖屏 / iPhone Duo 展开态等）
    var isExpandedCanvas: Bool {
        containerSize.width >= 560 || horizontalSizeClass == .regular
    }

    /// 紧凑高度（iPhone 横屏或小屏）
    var isCompactHeight: Bool {
        verticalSizeClass == .compact || containerSize.height < 640
    }

    /// 半开姿态或宽屏分栏时，是否应使用水平左右分栏（否则为上下分栏，如竖直握持半开折屏）
    var prefersHorizontalSplitAxis: Bool {
        if hinge.isFlexTabletopPosture && containerSize.height > containerSize.width {
            return false
        }
        return isWideSplit
    }

    /// 跨越物理折痕时的中心留白间距
    var hingeAvoidanceGap: CGFloat {
        if hinge.isFlexTabletopPosture {
            return 28
        }
        return isWideSplit ? 24 : 0
    }

    /// 水平安全边距（兼顾外屏非对称大圆角与 Vertical Bar 安全区）
    var horizontalPadding: CGFloat {
        let base: CGFloat
        if containerSize.width >= 900 {
            base = 36
        } else if containerSize.width >= 600 {
            base = 28
        } else {
            base = 20
        }
        let maxEdgeInset = max(safeAreaInsets.leading, safeAreaInsets.trailing)
        return maxEdgeInset > 0 ? max(base, min(40, maxEdgeInset + 12)) : base
    }

    /// 底部悬浮栏外侧安全留白（防止靠近外屏 59pt 圆角时胶囊视觉发紧）
    var dockBottomPadding: CGFloat {
        isCompactShortScreen ? 12 : 16
    }

    /// HomeView Hero 叠卡缩放比例
    var heroDeckScale: CGFloat {
        if prefersHorizontalSplitAxis {
            let verticalReserve: CGFloat = isCompactShortScreen ? 110 : 130
            let maxH = max(200, containerSize.height - verticalReserve)
            let maxW = max(220, containerSize.width * 0.44)
            let upperBound: CGFloat = containerSize.width >= 960 ? 1.32 : 1.16
            return min(upperBound, min(maxH / 358, maxW / 351))
        } else {
            let verticalReserve: CGFloat = isCompactShortScreen ? 290 : 340
            let maxH = max(210, containerSize.height - verticalReserve)
            let maxW = max(260, containerSize.width - horizontalPadding * 2)
            return min(1.12, min(maxH / 358, maxW / 351))
        }
    }

    /// 底部悬浮主操作区最大宽度（避免在 iPad / Duo 上过度拉伸）
    var floatingDockMaxWidth: CGFloat {
        isExpandedCanvas ? 460 : .infinity
    }

    /// 表单/列表页面最大阅读宽度
    var readableContentMaxWidth: CGFloat {
        isExpandedCanvas ? 620 : .infinity
    }

    /// 批量转换照片网格列数（iPhone / 外屏 3 列，Duo 竖屏 4 列，Duo 横屏 5 列，iPad 6 列）
    var batchGridColumns: Int {
        switch containerSize.width {
        case ..<500: return 3
        case 500..<760: return 4
        case 760..<1024: return 5
        default: return 6
        }
    }

    /// 批量转换网格最大宽度
    var batchGridMaxWidth: CGFloat {
        containerSize.width >= 1024 ? 980 : .infinity
    }

    /// KeyframePickerSheet 动态高度档位决策（矮屏直接使用 .large 以避免 540pt 与 .large 高度重叠）
    var keyframeDetentMode: KeyframeSheetDetentMode {
        isCompactShortScreen ? .largeOnly : .mediumAndLarge
    }

    var preferredKeyframeDetents: Set<PresentationDetent> {
        switch keyframeDetentMode {
        case .largeOnly:
            return [.large]
        case .mediumAndLarge:
            return [.height(540), .large]
        }
    }

    /// KeyframePickerSheet 在宽且矮的屏幕上采用左右双列选帧（如 Duo 内屏横屏 951×669）
    var usesSideBySideKeyframeLayout: Bool {
        containerSize.width >= 640 && isCompactShortScreen
    }
}

// MARK: - Haptic Feedback Helper
@MainActor
enum AppHaptics {
    static func selection() {
        #if !targetEnvironment(macCatalyst)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }

    static func lightImpact() {
        #if !targetEnvironment(macCatalyst)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    static func mediumImpact() {
        #if !targetEnvironment(macCatalyst)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    static func success() {
        #if !targetEnvironment(macCatalyst)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if !targetEnvironment(macCatalyst)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }

    static func error() {
        #if !targetEnvironment(macCatalyst)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
}

// MARK: - HIG Liquid Glass Helpers (iOS 26+ Native, iOS 16–25 Specular Material Fallback)

/// 仅用于悬浮导航控制层与浮动工具栏的液态玻璃修饰器（内容层严禁使用）
struct LiquidGlassControlModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let overDarkMedia: Bool

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if interactive {
                content
                    .glassEffect(.regular.interactive(), in: shape)
            } else {
                content
                    .glassEffect(.regular, in: shape)
            }
        } else {
            let isDarkSurface = overDarkMedia || colorScheme == .dark
            content
                .background(
                    shape
                        .fill(isDarkSurface ? Color(red: 0.09, green: 0.11, blue: 0.14).opacity(0.55) : Color.white.opacity(0.76))
                        .background(.ultraThinMaterial, in: shape)
                        .overlay(
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: isDarkSurface
                                        ? [Color.white.opacity(0.42), Color.white.opacity(0.08), Color.white.opacity(0.22)]
                                        : [Color.white.opacity(0.92), Color.black.opacity(0.06), Color.white.opacity(0.65)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                        )
                        .shadow(
                            color: Color.black.opacity(isDarkSurface ? 0.30 : 0.10),
                            radius: 14,
                            y: 6
                        )
                )
        }
    }
}

extension View {
    /// 应用 Apple HIG Liquid Glass 控制层材质（仅限导航栏按钮、悬浮工具胶囊、底部浮层操作栏）
    func liquidGlassControl<S: InsettableShape>(
        in shape: S,
        interactive: Bool = true,
        overDarkMedia: Bool = false
    ) -> some View {
        modifier(LiquidGlassControlModifier(shape: shape, interactive: interactive, overDarkMedia: overDarkMedia))
    }

    /// 应用照片内容层专用的克制静默角标（无玻璃折射、无描边）
    func quietPhotoBadge(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.quietPhotoBadgeFill)
            )
    }
}

/// 包装多个同组液态玻璃控件的容器（iOS 26+ 使用原生 GlassEffectContainer）
struct LiquidGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Reusable Design System Components

/// 主行动按钮（对应 Figma `.glassProminent` 液态玻璃主胶囊，height 54pt）
struct StudioPrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isDisabled ? AppTheme.textTertiary : AppTheme.accentForeground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.horizontal, 20)

        Group {
            if isDisabled {
                label
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.surface2)
                    )
            } else if #available(iOS 26, *) {
                label
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accentGradientTop, AppTheme.accentGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .glassEffect(.regular.tint(AppTheme.accent).interactive(), in: .capsule)
                    .shadow(color: AppTheme.accent.opacity(0.32), radius: 16, y: 8)
            } else {
                label
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accentGradientTop, AppTheme.accentGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.48), Color.white.opacity(0.10), Color.white.opacity(0.24)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: AppTheme.accent.opacity(0.35), radius: 18, y: 9)
                    )
            }
        }
        .scaleEffect(configuration.isPressed && !isDisabled ? 0.98 : 1.0)
        .opacity(configuration.isPressed && !isDisabled ? 0.92 : 1.0)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 内容层表单次级按钮（标准 surface1 胶囊，无玻璃特效，严格遵循 HIG 内容层收敛规范）
struct StudioSecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppTheme.textPrimary)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.surface1)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 悬浮导航栏圆形液态玻璃按钮（38×38pt）
struct StudioIconCircleButton: View {
    let systemName: String
    let accessibilityLabel: String
    var size: CGFloat = 38
    var overDarkMedia: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(overDarkMedia ? .white : AppTheme.textPrimary)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .liquidGlassControl(in: Circle(), interactive: true, overDarkMedia: overDarkMedia)
        }
        .accessibilityLabel(accessibilityLabel)
        .buttonStyle(.plain)
    }
}

/// 标准内容卡片修饰器（无玻璃特效，surface0 + 细描边）
struct StudioCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.Radius.card
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.surface0)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
                    )
            )
    }
}

extension View {
    func studioCard(cornerRadius: CGFloat = AppTheme.Radius.card, padding: CGFloat = 16) -> some View {
        modifier(StudioCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
