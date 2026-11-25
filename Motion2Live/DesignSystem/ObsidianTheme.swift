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

// MARK: - Adaptive Multi-Device Layout Metrics (iPhone / iPhone Duo / iPad)
struct AdaptiveLayoutMetrics {
    let containerSize: CGSize
    let horizontalSizeClass: UserInterfaceSizeClass?
    let verticalSizeClass: UserInterfaceSizeClass?

    /// 宽屏横排模式（iPad 横屏、iPhone Duo 展开态、iPhone 横屏）
    var isWideSplit: Bool {
        containerSize.width >= 680 || (verticalSizeClass == .compact && containerSize.width >= 560)
    }

    /// 宽画布（iPad 竖屏 / iPhone Duo 展开态等）
    var isExpandedCanvas: Bool {
        containerSize.width >= 560 || horizontalSizeClass == .regular
    }

    /// 紧凑高度（iPhone 横屏或小屏）
    var isCompactHeight: Bool {
        verticalSizeClass == .compact || containerSize.height < 640
    }

    /// 水平安全边距
    var horizontalPadding: CGFloat {
        if containerSize.width >= 900 { return 36 }
        if containerSize.width >= 600 { return 28 }
        return 20
    }

    /// 底部悬浮主操作区最大宽度（避免在 iPad / Duo 上过度拉伸）
    var floatingDockMaxWidth: CGFloat {
        isExpandedCanvas ? 460 : .infinity
    }

    /// 表单/列表页面最大阅读宽度
    var readableContentMaxWidth: CGFloat {
        isExpandedCanvas ? 620 : .infinity
    }

    /// 批量转换照片网格列数（iPhone 3 列，iPhone Duo 4–5 列，iPad 5–6 列）
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
}

// MARK: - Haptic Feedback Helper
@MainActor
enum AppHaptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
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
