//
//  ShareExtensionView.swift
//  Motion2LiveShareExtension
//
//  Compact Share Sheet UI following ObsidianTheme & Liquid Glass guidelines.
//

import SwiftUI
import AVFoundation
import ImageIO
import UIKit

@MainActor
final class ShareExtensionViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case exporting
        case success
        case permissionDenied
        case error(String)
    }

    @Published var phase: Phase = .loading
    @Published var selectedFormat: BatchExportFormat = .livePhoto
    @Published var isPlaying: Bool = false
    @Published var hasMultipleItems: Bool = false
    @Published var coverImage: UIImage?
    @Published var detectedBrand: MotionPhotoBrand = .unknown
    @Published var videoDurationSeconds: Double?
    @Published var player: AVPlayer?
    @Published var exportAlertMessage: String?

    private var copiedSourceURL: URL?
    private var previewVideoURL: URL?
    private var parsedPhoto: ParsedShareMotionPhoto?
    private var loopObserver: NSObjectProtocol?

    deinit {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        MediaExportService.removeIfInTemporaryDirectory(copiedSourceURL)
        MediaExportService.removeIfInTemporaryDirectory(previewVideoURL)
    }

    func load(extensionItems: [Any]?) async {
        phase = .loading
        cleanupTemporaryFiles()

        do {
            let loaded = try await ShareAttachmentLoader.loadFirstImage(from: extensionItems)
            copiedSourceURL = loaded.fileURL
            hasMultipleItems = loaded.hasMultipleItems

            let parsed = try await Task.detached(priority: .userInitiated) {
                try ShareAttachmentLoader.parseMotionPhoto(at: loaded.fileURL)
            }.value

            parsedPhoto = parsed
            detectedBrand = parsed.motionPhotoData.brand
            coverImage = Self.makePreviewThumbnail(from: parsed.motionPhotoData.imageData)

            let tempVideoURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("share_preview_\(UUID().uuidString).mp4")
            try parsed.motionPhotoData.videoData.write(to: tempVideoURL, options: .atomic)
            previewVideoURL = tempVideoURL

            let asset = AVAsset(url: tempVideoURL)
            if let duration = try? await asset.load(.duration) {
                let sec = CMTimeGetSeconds(duration)
                if sec.isFinite && sec > 0 {
                    videoDurationSeconds = sec
                }
            }

            setupPlayer(with: tempVideoURL)
            phase = .ready
        } catch {
            cleanupTemporaryFiles()
            phase = .error(error.localizedDescription)
        }
    }

    func startPlayback() {
        guard !isPlaying, let player = player else { return }
        AppHaptics.lightImpact()
        player.seek(to: .zero)
        player.play()
        isPlaying = true
    }

    func stopPlayback() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    func exportSelectedFormat() async {
        guard let parsed = parsedPhoto else { return }
        phase = .exporting
        exportAlertMessage = nil

        do {
            switch selectedFormat {
            case .livePhoto:
                try await MediaExportService.exportLivePhoto(
                    motionPhotoData: parsed.motionPhotoData,
                    originalData: parsed.originalData,
                    fallbackURL: parsed.sourceURL,
                    processor: parsed.processor,
                    recordRecent: false
                )
            case .video:
                try await MediaExportService.exportVideo(
                    videoData: parsed.motionPhotoData.videoData,
                    originalData: parsed.originalData,
                    fallbackURL: parsed.sourceURL,
                    recordRecent: false
                )
            case .gif:
                try await MediaExportService.exportGIF(
                    videoData: parsed.motionPhotoData.videoData,
                    originalData: parsed.originalData,
                    fallbackURL: parsed.sourceURL,
                    recordRecent: false
                )
            }

            AppHaptics.success()
            phase = .success
        } catch MediaExportError.photoLibraryPermissionDenied {
            AppHaptics.warning()
            phase = .permissionDenied
        } catch {
            AppHaptics.error()
            exportAlertMessage = error.localizedDescription
            phase = .ready
        }
    }

    func cleanupTemporaryFiles() {
        player?.pause()
        isPlaying = false
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player = nil
        MediaExportService.removeIfInTemporaryDirectory(copiedSourceURL)
        MediaExportService.removeIfInTemporaryDirectory(previewVideoURL)
        copiedSourceURL = nil
        previewVideoURL = nil
    }

    private static func makePreviewThumbnail(from imageData: Data, maxPixelSize: CGFloat = 1600) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return UIImage(data: imageData)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(data: imageData)
    }

    private func setupPlayer(with videoURL: URL) {
        let item = AVPlayerItem(url: videoURL)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = false
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak avPlayer] _ in
            avPlayer?.seek(to: .zero)
            avPlayer?.play()
        }
        self.player = avPlayer
    }
}

struct ShareExtensionView: View {
    let extensionItems: [Any]?
    let onDismiss: () -> Void

    @StateObject private var viewModel = ShareExtensionViewModel()
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()

            VStack(spacing: 16) {
                headerBar

                switch viewModel.phase {
                case .loading:
                    loadingView
                case .ready, .exporting:
                    readyView
                case .success:
                    successView
                case .permissionDenied:
                    permissionDeniedView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await viewModel.load(extensionItems: extensionItems)
        }
        .onDisappear {
            viewModel.cleanupTemporaryFiles()
        }
        .alert(
            Localizable.string(.error),
            isPresented: Binding(
                get: { viewModel.exportAlertMessage != nil },
                set: { if !$0 { viewModel.exportAlertMessage = nil } }
            )
        ) {
            Button(Localizable.string(.ok), role: .cancel) {
                viewModel.exportAlertMessage = nil
            }
        } message: {
            Text(viewModel.exportAlertMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Motion2Live")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(Localizable.string(.shareExtensionSubtitle))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            StudioIconCircleButton(
                systemName: "xmark",
                accessibilityLabel: Localizable.string(.close)
            ) {
                dismissWithCleanup()
            }
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.15)
                .tint(AppTheme.accent)
            Text(Localizable.string(.shareLoadingPhoto))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ready / Exporting State

    private var readyView: some View {
        VStack(spacing: 16) {
            if viewModel.hasMultipleItems {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.accent)
                    Text(Localizable.string(.shareMultipleItemsNotice))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                        .fill(AppTheme.surface1)
                )
            }

            previewStage

            formatPicker

            Button {
                Task {
                    await viewModel.exportSelectedFormat()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.phase == .exporting {
                        ProgressView()
                            .tint(AppTheme.textTertiary)
                        Text(Localizable.string(.processing))
                    } else {
                        Image(systemName: viewModel.selectedFormat.icon)
                        Text(Localizable.string(.shareSaveToPhotos))
                    }
                }
            }
            .buttonStyle(StudioPrimaryButtonStyle(isDisabled: viewModel.phase == .exporting, height: 52))
            .disabled(viewModel.phase == .exporting)
        }
    }

    private var previewStage: some View {
        let mediaAspectRatio: CGFloat = {
            if let size = viewModel.coverImage?.size, size.height > 0 {
                return size.width / size.height
            }
            return 3.0 / 4.0
        }()

        return ZStack {
            AppTheme.stageBackground

            if let coverImage = viewModel.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFit()
            }

            if let player = viewModel.player {
                PlayerView(player: player)
                    .opacity(viewModel.isPlaying ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: viewModel.isPlaying)
                    .allowsHitTesting(false)
            }

            // Quiet top-right play/pause button & bottom-left brand + duration badge
            VStack {
                HStack {
                    Spacer()
                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "livephoto")
                            .font(.system(size: 11, weight: .semibold))
                        Text(viewModel.detectedBrand.displayName)
                            .font(.system(size: 12, weight: .semibold))
                        if let sec = viewModel.videoDurationSeconds {
                            Text("· \(String(format: "%.1fs", sec))")
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.85)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .quietPhotoBadge(cornerRadius: 12)

                    Spacer()
                }
                .padding(12)
            }
        }
        .aspectRatio(mediaAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.stage, style: .continuous))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220, maxHeight: 360)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.stage, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in viewModel.startPlayback() }
                .onEnded { _ in viewModel.stopPlayback() }
        )
        .accessibilityLabel(viewModel.isPlaying ? Localizable.string(.shareTapToPause) : Localizable.string(.shareTapToPlay))
    }

    private var formatPicker: some View {
        HStack(spacing: 8) {
            ForEach(BatchExportFormat.allCases) { format in
                let isSelected = viewModel.selectedFormat == format
                Button {
                    AppHaptics.selection()
                    viewModel.selectedFormat = format
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: format.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(format.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                            .fill(isSelected ? AppTheme.accent.opacity(0.14) : AppTheme.surface1)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                                    .strokeBorder(isSelected ? AppTheme.accent.opacity(0.6) : AppTheme.borderSubtle, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Success State

    private var successView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.success)

            VStack(spacing: 6) {
                Text(Localizable.string(.shareSavedSuccess))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(viewModel.selectedFormat.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                dismissWithCleanup()
            } label: {
                Text(Localizable.string(.done))
            }
            .buttonStyle(StudioPrimaryButtonStyle(height: 52))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Permission Denied State

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.warning)

            Text(Localizable.string(.photoLibraryPermissionDenied))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(Localizable.string(.sharePermissionGuidance))
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    dismissWithCleanup()
                } label: {
                    Text(Localizable.string(.close))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioSecondaryCapsuleButtonStyle())

                Button {
                    Task {
                        await viewModel.exportSelectedFormat()
                    }
                } label: {
                    Text(Localizable.string(.shareSaveToPhotos))
                }
                .buttonStyle(StudioPrimaryButtonStyle(height: 48))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.danger)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()

            Button {
                dismissWithCleanup()
            } label: {
                Text(Localizable.string(.close))
            }
            .buttonStyle(StudioPrimaryButtonStyle(height: 52))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dismissWithCleanup() {
        viewModel.cleanupTemporaryFiles()
        onDismiss()
    }
}
