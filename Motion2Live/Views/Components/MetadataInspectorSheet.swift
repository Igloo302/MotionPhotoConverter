//
//  MetadataInspectorSheet.swift
//  Motion2Live
//
//  Half-sheet File Structure & Metadata Inspector (Adaptive Obsidian Dark / Porcelain Light).
//  Content layer strictly avoids Liquid Glass and uses AppTheme tokens + .studioCard.
//

import SwiftUI
import UIKit

@MainActor
struct MetadataInspectorSheet: View {
    let report: MotionPhotoInspectionReport

    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false
    @State private var copyResetTask: Task<Void, Never>?

    private let legendColumns = [
        GridItem(.flexible(minimum: 110), spacing: 12, alignment: .leading),
        GridItem(.flexible(minimum: 110), spacing: 12, alignment: .leading)
    ]

    var body: some View {
        ZStack {
            AppTheme.canvas
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    headerRow

                    containerCard

                    videoSpecsCard

                    xmpMetadataCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .onDisappear {
            copyResetTask?.cancel()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text(Localizable.string(.fileStructureTitle))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            HStack(spacing: 8) {
                Button(action: copySummaryToPasteboard) {
                    HStack(spacing: 5) {
                        if isCopied {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.success)
                        }
                        Text(isCopied ? Localizable.string(.copied) : Localizable.string(.copySummary))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isCopied ? AppTheme.success : AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.surface1)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.75)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Localizable.string(.copySummary))

                Button {
                    AppHaptics.lightImpact()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(AppTheme.surface1)
                                .overlay(
                                    Circle()
                                        .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.75)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Localizable.string(.close))
            }
        }
    }

    // MARK: - Card 1: Container Composition

    private var containerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(Localizable.string(.containerComposition))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(Localizable.string(.totalSize)) \(MotionPhotoStructureAnalyzer.formatByteCount(report.totalBytes))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }

            if !report.segments.isEmpty {
                segmentBar
                    .frame(height: 10)

                LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 8) {
                    ForEach(report.segments) { segment in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color(for: segment.kind))
                                .frame(width: 8, height: 8)

                            Text("\(segment.label) \(MotionPhotoStructureAnalyzer.formatByteCount(segment.byteCount)) (\(MotionPhotoStructureAnalyzer.formatPercentage(segment.percentage)))")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }
            }
        }
        .studioCard(cornerRadius: AppTheme.Radius.tile, padding: 14)
    }

    private var segmentBar: some View {
        GeometryReader { geometry in
            let widths = segmentWidths(totalWidth: geometry.size.width, spacing: 2, minSegmentWidth: 4)
            HStack(spacing: 2) {
                ForEach(Array(report.segments.enumerated()), id: \.element.id) { index, segment in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(for: segment.kind))
                        .frame(width: widths[index], height: 10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }

    /// 分配比例条宽度：极小分段强制保留 `minSegmentWidth`（4pt），其余宽度按字节比例分配
    private func segmentWidths(totalWidth: CGFloat, spacing: CGFloat, minSegmentWidth: CGFloat) -> [CGFloat] {
        let count = report.segments.count
        guard count > 0 else { return [] }
        let totalSpacing = spacing * CGFloat(max(0, count - 1))
        let usableWidth = max(0, totalWidth - totalSpacing)
        guard usableWidth > 0 else {
            return Array(repeating: 0, count: count)
        }

        let effectiveMin = min(minSegmentWidth, usableWidth / CGFloat(count))
        let totalBytes = max(1, report.segments.reduce(0) { $0 + max(0, $1.byteCount) })

        var rawWidths = report.segments.map { segment -> CGFloat in
            let ratio = CGFloat(max(0, segment.byteCount)) / CGFloat(totalBytes)
            return max(effectiveMin, usableWidth * ratio)
        }

        let sumWidth = rawWidths.reduce(0, +)
        if sumWidth > usableWidth {
            let excess = sumWidth - usableWidth
            let adjustableTotal = rawWidths.reduce(0) { $0 + max(0, $1 - effectiveMin) }
            if adjustableTotal > 0 {
                for index in rawWidths.indices {
                    let adjustable = max(0, rawWidths[index] - effectiveMin)
                    rawWidths[index] -= excess * (adjustable / adjustableTotal)
                }
            }
        }
        return rawWidths
    }

    private func color(for kind: MotionPhotoSegmentKind) -> Color {
        switch kind {
        case .primaryImage:
            return AppTheme.accent
        case .gainMap:
            return AppTheme.warning
        case .video:
            return AppTheme.success
        case .sefTrailer, .unknownTrailer:
            return AppTheme.textTertiary
        }
    }

    // MARK: - Card 2: Video Stream Specs

    private var videoSpecsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizable.string(.videoStreamSpecs))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            if let specs = report.videoSpecs {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        specCell(
                            title: Localizable.string(.videoCodec),
                            value: specs.codecName
                        )
                        specCell(
                            title: Localizable.string(.videoResolution),
                            value: (specs.width > 0 && specs.height > 0) ? "\(specs.width) × \(specs.height)" : "—"
                        )
                    }

                    HStack(spacing: 8) {
                        specCell(
                            title: Localizable.string(.videoFrameRate),
                            value: specs.frameRate > 0 ? String(format: "%.2f fps", specs.frameRate) : "—"
                        )
                        specCell(
                            title: Localizable.string(.videoDuration),
                            value: specs.durationSeconds > 0 ? String(format: "%.2f s", specs.durationSeconds) : "—"
                        )
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(AppTheme.accent)
                    Text(Localizable.string(.processing))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                        .fill(AppTheme.surface1)
                )
            }
        }
        .studioCard(cornerRadius: AppTheme.Radius.tile, padding: 14)
    }

    private func specCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(AppTheme.textTertiary)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .fill(AppTheme.surface1)
        )
    }

    // MARK: - Card 3: XMP & Device Metadata

    private var xmpMetadataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizable.string(.xmpAndDeviceMetadata))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 8) {
                metadataRow(
                    key: Localizable.string(.brandAndExifLabel),
                    value: report.formattedBrandAndDevice,
                    isMonospacedKey: false
                )

                if report.xmpFields.isEmpty {
                    Text(Localizable.string(.noXmpMetadataNotice))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                                .fill(AppTheme.surface1)
                        )
                } else {
                    ForEach(report.xmpFields) { field in
                        Rectangle()
                            .fill(AppTheme.borderSubtle)
                            .frame(height: 1)

                        metadataRow(
                            key: field.key,
                            value: field.value,
                            isMonospacedKey: true
                        )
                    }
                }
            }
        }
        .studioCard(cornerRadius: AppTheme.Radius.tile, padding: 14)
    }

    private func metadataRow(key: String, value: String, isMonospacedKey: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key)
                .font(.system(size: 12, weight: .regular, design: isMonospacedKey ? .monospaced : .default))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    // MARK: - Actions

    private func copySummaryToPasteboard() {
        UIPasteboard.general.string = report.formattedSummary()
        AppHaptics.success()

        copyResetTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            isCopied = true
        }
        copyResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isCopied = false
            }
        }
    }
}
