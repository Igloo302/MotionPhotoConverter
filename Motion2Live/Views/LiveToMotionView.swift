//
//  LiveToMotionView.swift
//  Motion2Live
//
//  Reverse conversion flow in Lab: Apple Live Photo -> 7-brand Motion Photo (.jpg).
//  Exports raw .jpg bytes via System Share Sheet or Files app.
//

import SwiftUI
import AVFoundation
import ImageIO
import UIKit

struct LiveToMotionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var extractedLivePhoto: ExtractedLivePhoto?
    @State private var previewImage: UIImage?
    @State private var imagePixelSize: CGSize?
    @State private var videoDuration: Double?
    @State private var player: AVPlayer?
    @State private var isPlayingPreview = false

    @State private var selectedBrand: MotionPhotoBrand = .pixel
    @State private var isShowingPicker = false
    @State private var isAnalyzingPick = false
    @State private var isProcessing = false
    @State private var hasDisappeared = false

    @StateObject private var motionExport = MotionPhotoExportCoordinator()

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertIsSuccess = false

    private var canExport: Bool {
        extractedLivePhoto != nil && !isProcessing && !isAnalyzingPick
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveLayoutMetrics(
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                horizontalSizeClass: horizontalSizeClass,
                verticalSizeClass: verticalSizeClass
            )

            ZStack {
                AppTheme.canvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Nav Bar
                    ZStack {
                        Text(Localizable.string(.liveToMotionTitle))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 76)

                        HStack {
                            Button {
                                AppHaptics.lightImpact()
                                dismiss()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(Localizable.string(.lab))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.leading, 10)
                                .padding(.trailing, 13)
                                .frame(height: 36)
                                .contentShape(Capsule())
                                .liquidGlassControl(in: Capsule(), interactive: true)
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                    .frame(height: 54)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 4)

                    ScrollView(showsIndicators: false) {
                        Group {
                            if metrics.isWideSplit {
                                HStack(alignment: .top, spacing: max(16, metrics.hingeAvoidanceGap)) {
                                    livePhotoSelectionCard
                                    VStack(spacing: 14) {
                                        MotionPhotoBrandPickerCard(
                                            selectedBrand: $selectedBrand,
                                            isDisabled: isProcessing || isAnalyzingPick
                                        )
                                        MotionPhotoExportNoticeBanner()
                                    }
                                }
                                .frame(maxWidth: 840)
                            } else {
                                VStack(spacing: 16) {
                                    livePhotoSelectionCard
                                    MotionPhotoBrandPickerCard(
                                        selectedBrand: $selectedBrand,
                                        isDisabled: isProcessing || isAnalyzingPick
                                    )
                                    MotionPhotoExportNoticeBanner()
                                }
                                .frame(maxWidth: metrics.readableContentMaxWidth)
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.isCompactShortScreen ? 10 : 14)
                        .padding(.bottom, metrics.isCompactShortScreen ? 14 : 20)
                        .frame(maxWidth: .infinity)
                    }

                    // Bottom Export Actions: Share (.jpg) & Save to Files
                    VStack(spacing: 10) {
                        MotionPhotoExportActionBar(
                            canExport: canExport,
                            isProcessing: isProcessing,
                            onShare: { startExport(destination: .share) },
                            onSaveToFiles: { startExport(destination: .files) }
                        )
                    }
                    .frame(maxWidth: metrics.floatingDockMaxWidth)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, metrics.dockBottomPadding)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPicker) {
            PhotoPicker(
                onLivePhotoPicked: { extracted in
                    handlePickedLivePhoto(extracted)
                },
                onLivePhotoPickFailed: { message in
                    alertIsSuccess = false
                    alertMessage = message
                    showAlert = true
                },
                onAnalyzingProgress: { current, _ in
                    isAnalyzingPick = current > 0
                }
            )
        }
        .motionPhotoExportSheets(
            coordinator: motionExport,
            onSavedToFiles: {
                alertIsSuccess = true
                alertMessage = Localizable.string(.liveToMotionSavedToFiles)
                showAlert = true
            },
            onError: { message in
                alertIsSuccess = false
                alertMessage = message
                showAlert = true
            }
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertIsSuccess ? Localizable.string(.success) : Localizable.string(.error)),
                message: Text(alertMessage),
                dismissButton: .default(Text(Localizable.string(.ok)))
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let endedItem = notification.object as? AVPlayerItem,
                  endedItem === player?.currentItem else {
                return
            }
            isPlayingPreview = false
        }
        .onDisappear {
            hasDisappeared = true
            player?.pause()
            player = nil
            if !isProcessing {
                extractedLivePhoto?.cleanup()
                if !motionExport.isPresentingExportUI {
                    motionExport.cleanup()
                }
            }
        }
    }

    // MARK: - Subviews

    private var livePhotoSelectionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(Localizable.string(.livePhoto))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                if let size = imagePixelSize, size.width > 0, size.height > 0 {
                    let durationSuffix = videoDuration.map { String(format: " · %.1fs", $0) } ?? ""
                    Text("\(Int(size.width)) × \(Int(size.height))\(durationSuffix)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            if previewImage != nil || player != nil {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.stageBackground)

                    if isPlayingPreview, let player = player {
                        PlayerView(player: player)
                            .frame(maxWidth: .infinity)
                            .frame(height: 210)
                    } else if let previewImage = previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: 210)
                    }

                    if player != nil {
                        Button {
                            togglePreviewPlayback()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isPlayingPreview ? "photo" : "play.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(isPlayingPreview ? Localizable.string(.liveToMotionPreviewPause) : Localizable.string(.liveToMotionPreviewPlay))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.62)))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button {
                AppHaptics.lightImpact()
                isShowingPicker = true
            } label: {
                HStack(spacing: 8) {
                    if isAnalyzingPick {
                        ProgressView()
                    } else {
                        Image(systemName: "livephoto")
                            .font(.system(size: 15, weight: .medium))
                    }
                    Text(extractedLivePhoto == nil ? Localizable.string(.liveToMotionSelect) : Localizable.string(.liveToMotionChange))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudioSecondaryCapsuleButtonStyle())
            .disabled(isAnalyzingPick || isProcessing)
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .frame(maxWidth: .infinity)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
            .fill(AppTheme.surface0)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
            )
    }

    // MARK: - Actions

    private func handlePickedLivePhoto(_ extracted: ExtractedLivePhoto) {
        if hasDisappeared {
            extracted.cleanup()
            return
        }
        player?.pause()
        isPlayingPreview = false
        extractedLivePhoto?.cleanup()
        extractedLivePhoto = extracted

        let newPlayer = AVPlayer(url: extracted.videoURL)
        player = newPlayer

        Task.detached(priority: .userInitiated) {
            let thumbnail = Self.makePreviewThumbnail(from: extracted.imageURL)
            let dimensions = Self.readPixelDimensions(from: extracted.imageURL)
            let duration = (try? await AVAsset(url: extracted.videoURL).load(.duration)).map(CMTimeGetSeconds)

            await MainActor.run {
                guard self.extractedLivePhoto?.imageURL == extracted.imageURL else { return }
                self.previewImage = thumbnail
                self.imagePixelSize = dimensions
                self.videoDuration = (duration?.isFinite == true && (duration ?? 0) > 0) ? duration : nil
            }
        }
    }

    private func togglePreviewPlayback() {
        guard let player = player else { return }
        AppHaptics.lightImpact()
        if isPlayingPreview {
            player.pause()
            isPlayingPreview = false
        } else {
            player.seek(to: .zero)
            player.play()
            isPlayingPreview = true
        }
    }

    private func startExport(destination: MotionPhotoExportDestination) {
        guard let extracted = extractedLivePhoto else { return }

        AppHaptics.mediumImpact()
        isProcessing = true
        motionExport.cleanup()

        Task {
            defer {
                isProcessing = false
                if hasDisappeared {
                    extracted.cleanup()
                }
            }

            do {
                let outputURL = try await MediaExportService.exportMotionPhoto(
                    imageURL: extracted.imageURL,
                    videoURL: extracted.videoURL,
                    targetBrand: selectedBrand,
                    creationDate: extracted.creationDate
                )

                if hasDisappeared {
                    MediaExportService.removeIfInTemporaryDirectory(outputURL)
                    return
                }

                AppHaptics.success()
                motionExport.present(url: outputURL, destination: destination)
            } catch {
                AppHaptics.error()
                alertIsSuccess = false
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private nonisolated static func makePreviewThumbnail(from url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 900
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private nonisolated static func readPixelDimensions(from url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: w, height: h)
    }
}
