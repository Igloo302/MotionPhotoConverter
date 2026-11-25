//
//  SupportedBrandsView.swift
//  Motion2Live
//
//  Adaptive Light & Dark brand compatibility matrix card.
//

import SwiftUI

struct SupportedBrandsView: View {
    let supportedBrands = MotionPhotoProcessorFactory.getAllSupportedBrands()

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 7, height: 7)
                Text(Localizable.string(.supportedBrandsTitle))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("\(supportedBrands.count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.accent.opacity(0.14))
                    )
            }

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(supportedBrands, id: \.self) { brand in
                    HStack(spacing: 8) {
                        Image(systemName: brandIcon(for: brand))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(brandColor(for: brand))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(brandColor(for: brand).opacity(0.14))
                            )

                        Text(brand.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.surface1)
                    )
                }
            }
        }
        .studioCard(cornerRadius: AppTheme.Radius.card, padding: 14)
    }

    private func brandIcon(for brand: MotionPhotoBrand) -> String {
        switch brand {
        case .xiaomi: return "camera.fill"
        case .pixel: return "camera.macro"
        case .samsung: return "camera.aperture"
        case .huawei: return "camera.circle"
        case .oppo: return "camera.metering.spot"
        case .vivo: return "camera.viewfinder"
        case .universal: return "sparkles.rectangle.stack"
        case .unknown: return "questionmark.circle"
        }
    }

    private func brandColor(for brand: MotionPhotoBrand) -> Color {
        switch brand {
        case .xiaomi: return .orange
        case .pixel: return .blue
        case .samsung: return .purple
        case .huawei: return .red
        case .oppo: return AppTheme.success
        case .vivo: return AppTheme.accent
        case .universal: return .indigo
        case .unknown: return AppTheme.textTertiary
        }
    }
}

#Preview {
    SupportedBrandsView()
        .padding()
        .background(AppTheme.canvas)
}
