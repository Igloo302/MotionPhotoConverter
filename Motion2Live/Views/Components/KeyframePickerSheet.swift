//
//  KeyframePickerSheet.swift
//  Motion2Live
//
//  Precision Keyframe & Cover Frame Selector Sheet (Adaptive Light & Dark).
//  Follows Apple HIG: standard opaque modal sheet (no glass-on-glass) + modern Playhead Lens.
//

import SwiftUI
import AVFoundation

@MainActor
struct KeyframePickerSheet: View {
    let videoURL: URL
    let videoDuration: Double
    let initialSeconds: Double
    let hasCustomCover: Bool
    let onConfirm: (Double) -> Void
    let onRestoreOriginal: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedSeconds: Double
    @State private var filmstripImages: [UIImage] = []
    @State private var previewFrame: UIImage?
    @State private var isLoadingThumbnails = true
    @State private var previewTask: Task<Void, Never>?
    @State private var lastHapticBucket: Int = -1

    private let filmstripCount = 7

    init(
        videoURL: URL,
        videoDuration: Double,
        initialSeconds: Double,
        hasCustomCover: Bool,
        onConfirm: @escaping (Double) -> Void,
        onRestoreOriginal: @escaping () -> Void
    ) {
        self.videoURL = videoURL
        self.videoDuration = max(0.1, videoDuration)
        self.initialSeconds = max(0, min(initialSeconds, max(0.1, videoDuration)))
        self.hasCustomCover = hasCustomCover
        self.onConfirm = onConfirm
        self.onRestoreOriginal = onRestoreOriginal
        _selectedSeconds = State(initialValue: max(0, min(initialSeconds, max(0.1, videoDuration))))
    }

    private var normalizedProgress: Double {
        guard videoDuration > 0 else { return 0 }
        return max(0, min(1, selectedSeconds / videoDuration))
    }

    var body: some View {
        ZStack {
            AppTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header: Title + standard surface1 Timecode Pill
                HStack(spacing: 10) {
                    Text(Localizable.string(.selectCoverFrame))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    Text("\(formatTimecode(selectedSeconds)) / \(formatTimecode(videoDuration))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppTheme.surface1)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.6)
                                )
                        )
                }
                .padding(.top, 14)

                // Live Frame Preview (r=24)
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.stageBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
                        )

                    if let frame = previewFrame {
                        Image(uiImage: frame)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        ProgressView()
                            .tint(AppTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 190, maxHeight: 230)

                // Filmstrip Scrubber with Playhead Lens
                filmstripScrubber

                Spacer(minLength: 4)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        AppHaptics.mediumImpact()
                        onConfirm(selectedSeconds)
                        dismiss()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                            Text(Localizable.string(.setCoverFrame))
                        }
                    }
                    .buttonStyle(StudioPrimaryButtonStyle(height: 52))

                    HStack(spacing: 28) {
                        if hasCustomCover {
                            Button {
                                AppHaptics.selection()
                                onRestoreOriginal()
                                dismiss()
                            } label: {
                                Text(Localizable.string(.restoreOriginalCover))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text(Localizable.string(.cancel))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .task {
            await loadFilmstrip()
            schedulePreviewFrame(at: selectedSeconds)
        }
        .onDisappear {
            previewTask?.cancel()
        }
    }

    private var filmstripScrubber: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let lensWidth: CGFloat = 52
            let halfLens = lensWidth / 2
            let clampedX = max(halfLens + 2, min(width - halfLens - 2, width * normalizedProgress))

            ZStack(alignment: .leading) {
                // 7 Rounded Filmstrip Frames
                HStack(spacing: 2) {
                    if filmstripImages.isEmpty {
                        ForEach(0..<filmstripCount, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.surface2)
                        }
                    } else {
                        ForEach(Array(filmstripImages.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
                .frame(height: 86)
                .background(AppTheme.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
                )

                // Playhead Lens (52×78, r=14, 2.2pt cyan border + center white hairline)
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppTheme.accent, lineWidth: 2.2)
                        )
                        .shadow(color: AppTheme.accent.opacity(0.45), radius: 10, y: 2)

                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 2, height: 64)
                }
                .frame(width: lensWidth, height: 78)
                .position(x: clampedX, y: 43)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / width))
                        let newSeconds = ratio * videoDuration
                        selectedSeconds = newSeconds

                        let bucket = Int(ratio * 24)
                        if bucket != lastHapticBucket {
                            lastHapticBucket = bucket
                            AppHaptics.selection()
                        }

                        schedulePreviewFrame(at: newSeconds)
                    }
            )
        }
        .frame(height: 86)
    }

    private func loadFilmstrip() async {
        let url = videoURL
        let duration = videoDuration
        let count = filmstripCount

        let images = await Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 160)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

            var results: [UIImage] = []
            for index in 0..<count {
                if Task.isCancelled { break }
                let fraction = count > 1 ? Double(index) / Double(count - 1) : 0
                let targetTime = CMTime(seconds: fraction * max(0, duration - 0.02), preferredTimescale: 600)
                if let cgImage = try? await generator.image(at: targetTime).image {
                    results.append(UIImage(cgImage: cgImage))
                }
            }
            return results
        }.value

        filmstripImages = images
        isLoadingThumbnails = false
    }

    private func schedulePreviewFrame(at seconds: Double) {
        previewTask?.cancel()
        let url = videoURL
        let clamped = max(0, min(seconds, max(0, videoDuration - 0.01)))

        previewTask = Task {
            let frame = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                let asset = AVAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 600, height: 600)
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.03, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.03, preferredTimescale: 600)

                let time = CMTime(seconds: clamped, preferredTimescale: 600)
                guard let cgImage = try? await generator.image(at: time).image else { return nil }
                return UIImage(cgImage: cgImage)
            }.value

            if !Task.isCancelled, let frame {
                self.previewFrame = frame
            }
        }
    }

    private func formatTimecode(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let mins = Int(clamped) / 60
        let secs = clamped - Double(mins * 60)
        return String(format: "%02d:%05.2f", mins, secs)
    }
}
