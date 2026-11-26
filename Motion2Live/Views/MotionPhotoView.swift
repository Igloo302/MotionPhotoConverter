//
//  MotionPhotoView.swift
//  Motion2Live
//
//  Full-Bleed Immersive Motion Photo Inspector with Apple HIG Liquid Glass floating controls.
//  Adaptive across iPhone, iPhone Duo, and iPad.
//

import SwiftUI
import AVKit

@MainActor
struct MotionPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var sourceURL: URL

    @State private var selectedImage: UIImage?
    @State private var originalPreviewImage: UIImage?
    @State private var customCoverImageData: Data?
    @State private var videoPlayer: AVPlayer?
    @State private var isPlayingVideo = false
    @State private var motionPhotoData: MotionPhotoData?
    @State private var detectedBrand: MotionPhotoBrand = .unknown

    @State private var videoDuration: Double = 0
    @State private var videoFrameRate: Double = 30.0
    @State private var stillImageTime: Int = 0
    @State private var defaultStillImageTime: Int = 0
    @State private var selectedCoverSeconds: Double = 0

    @State private var selectedExportFormat: BatchExportFormat = .livePhoto
    @State private var isShowingPhotoPicker = false
    @State private var isShowingKeyframePicker = false
    @State private var isShowingMetadataInspector = false
    @State private var inspectionReport: MotionPhotoInspectionReport?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isPermissionDeniedAlert = false
    @State private var isProcessing = false
    @State private var creationDate: Date?

    @Namespace private var formatNamespace

    // 资源生命周期追踪
    @State private var previewVideoURL: URL?
    @State private var playerEndObserver: NSObjectProtocol?
    @State private var hingeState: HingeStateSnapshot = .unavailable
    @State private var lastMetrics = AdaptiveLayoutMetrics(
        containerSize: CGSize(width: 390, height: 844),
        horizontalSizeClass: nil,
        verticalSizeClass: nil
    )

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd HHmm")
        return formatter
    }()

    init(sourceURL: URL) {
        _sourceURL = State(initialValue: sourceURL)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveLayoutMetrics(
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                horizontalSizeClass: horizontalSizeClass,
                verticalSizeClass: verticalSizeClass,
                hinge: hingeState
            )
            let isSplitStudioMode = metrics.layoutMode == .hingeFlexSplit
                || (metrics.isWideSplit && metrics.isCompactShortScreen)

            let stageLayout: AnyLayout = {
                if !isSplitStudioMode {
                    return AnyLayout(ZStackLayout())
                }
                return metrics.prefersHorizontalSplitAxis
                    ? AnyLayout(HStackLayout(alignment: .center, spacing: metrics.hingeAvoidanceGap))
                    : AnyLayout(VStackLayout(spacing: metrics.hingeAvoidanceGap))
            }()

            ZStack {
                // 1. 柔和环境模糊衬底（始终保留在底层，避免切换布局时重建）
                ambientBackdrop(size: proxy.size)

                // 2. 上下光学渐变护航层（仅全屏叠层模式启用，分屏模式下淡出）
                opticalGradients
                    .opacity(isSplitStudioMode ? 0 : 1)

                // 3. 单一视图树：预览舞台 + 悬浮控制区（通过 AnyLayout 在全屏叠层 / 左右分栏 / 上下折屏间无损切换）
                stageLayout {
                    interactiveMediaStage(isSplitStudioMode: isSplitStudioMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    inspectorControlsPanel(metrics: metrics, isSplitStudioMode: isSplitStudioMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAdaptiveChange(of: metrics) { newMetrics in
                lastMetrics = newMetrics
            }
            .onAppear {
                lastMetrics = metrics
            }
        }
        .observeDeviceHinge($hingeState)
        .immersiveToolbarVerticalBehaviorDisabled()
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(onImagePicked: { url, isMotionPhoto in
                Task {
                    if isMotionPhoto {
                        let oldURL = sourceURL
                        sourceURL = url
                        MediaExportService.removeIfInTemporaryDirectory(oldURL)
                        await extractVideoFromMotionPhoto(url: url)
                    } else {
                        MediaExportService.removeIfInTemporaryDirectory(url)
                        showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                    }
                }
            }, onNonMotionPhotoSelected: {
                showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
            })
        }
        .sheet(isPresented: $isShowingKeyframePicker) {
            if let videoURL = previewVideoURL, videoDuration > 0 {
                keyframeSheet(videoURL: videoURL)
            }
        }
        .sheet(isPresented: $isShowingMetadataInspector) {
            if let report = inspectionReport {
                metadataInspectorSheet(report: report)
            }
        }
        .alert(Localizable.string(.tip), isPresented: $showAlert) {
            if isPermissionDeniedAlert {
                Button(Localizable.string(.openSettings)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button(Localizable.string(.ok), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .task {
            await extractVideoFromMotionPhoto(url: sourceURL)
        }
        .onDisappear {
            cleanupPlaybackResources()
            MediaExportService.removeIfInTemporaryDirectory(sourceURL)
        }
    }

    @ViewBuilder
    private func keyframeSheet(videoURL: URL) -> some View {
        let sheet = KeyframePickerSheet(
            videoURL: videoURL,
            videoDuration: videoDuration,
            initialSeconds: selectedCoverSeconds,
            hasCustomCover: customCoverImageData != nil,
            onConfirm: { seconds in
                Task {
                    await applyCustomCoverFrame(at: seconds)
                }
            },
            onRestoreOriginal: {
                restoreOriginalCoverFrame()
            }
        )
        .presentationDetents(lastMetrics.preferredKeyframeDetents)
        .presentationDragIndicator(.visible)

        if #available(iOS 16.4, *) {
            sheet.presentationCornerRadius(AppTheme.Radius.sheet)
        } else {
            sheet
        }
    }

    @ViewBuilder
    private func metadataInspectorSheet(report: MotionPhotoInspectionReport) -> some View {
        let sheet = MetadataInspectorSheet(report: report)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        if #available(iOS 16.4, *) {
            sheet.presentationCornerRadius(AppTheme.Radius.sheet)
        } else {
            sheet
        }
    }

    // MARK: - Full-Bleed Photo & Video Stage

    private func ambientBackdrop(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.063, green: 0.075, blue: 0.086)
                .ignoresSafeArea()

            if let image = selectedImage {
                // 柔和环境模糊衬底（在 iPad / Duo 宽屏下让留白边缘自然过渡）
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .blur(radius: 36)
                    .overlay(Color.black.opacity(0.45))
                    .clipped()
                    .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
    }

    private var opticalGradients: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(red: 0.020, green: 0.031, blue: 0.051).opacity(0.56),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 170)

            Spacer()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.031, green: 0.039, blue: 0.051).opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 250)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func interactiveMediaStage(isSplitStudioMode: Bool) -> some View {
        if let image = selectedImage {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let player = videoPlayer {
                    PlayerView(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isPlayingVideo ? 1 : 0)
                        .animation(.easeInOut(duration: 0.18), value: isPlayingVideo)
                }
            }
            .padding(isSplitStudioMode ? 12 : 0)
            .clipShape(RoundedRectangle(cornerRadius: isSplitStudioMode ? 20 : 0, style: .continuous))
            .ignoresSafeArea(edges: isSplitStudioMode ? [] : .all)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startVideoPlayback() }
                    .onEnded { _ in stopVideoPlayback() }
            )
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.accent)
                Text(Localizable.string(.processing))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }

    private func inspectorControlsPanel(metrics: AdaptiveLayoutMetrics, isSplitStudioMode: Bool) -> some View {
        VStack(spacing: 0) {
            floatingTopBar(metrics: metrics)

            quietMetadataRow(metrics: metrics)
                .padding(.top, 8)

            Spacer(minLength: isSplitStudioMode ? 12 : 0)

            if !isPlayingVideo && videoPlayer != nil {
                Text(Localizable.string(.holdToPlayHint))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .quietPhotoBadge(cornerRadius: 14)
                    .padding(.bottom, metrics.isCompactShortScreen ? 8 : 12)
                    .transition(.opacity)
            }

            floatingBottomDock(metrics: metrics)
        }
    }

    // MARK: - Floating Top Navigation Bar

    private func floatingTopBar(metrics: AdaptiveLayoutMetrics) -> some View {
        HStack {
            // 左上角：纯排版时间戳标题（严格遵循 HIG，不包玻璃胶囊）
            if let date = creationDate {
                Text(Self.timestampFormatter.string(from: date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.96))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .padding(.leading, 4)
            }

            Spacer()

            // 右上角：成组液态玻璃工具胶囊（切换照片 | 关闭）
            LiquidGlassGroup(spacing: 0) {
                HStack(spacing: 0) {
                    Button {
                        AppHaptics.lightImpact()
                        isShowingPhotoPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Localizable.string(.selectMotionPhoto))

                    Rectangle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 0.8, height: 16)

                    Button {
                        AppHaptics.lightImpact()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Localizable.string(.cancel))
                }
                .liquidGlassControl(in: Capsule(), interactive: true, overDarkMedia: true)
            }
        }
        .frame(height: 48)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - Quiet Metadata Row (Content Layer — No Liquid Glass)

    private func quietMetadataRow(metrics: AdaptiveLayoutMetrics) -> some View {
        HStack(spacing: 8) {
            Button {
                guard inspectionReport != nil else { return }
                AppHaptics.lightImpact()
                isShowingMetadataInspector = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isPlayingVideo ? .white : Color(red: 0.220, green: 0.737, blue: 0.878))

                    Text(metadataLabelText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)

                    if inspectionReport != nil {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
                .padding(.leading, 11)
                .padding(.trailing, 12)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isPlayingVideo ? AppTheme.accent.opacity(0.85) : AppTheme.quietPhotoBadgeFill)
                )
                .animation(.easeInOut(duration: 0.18), value: isPlayingVideo)
            }
            .buttonStyle(.plain)
            .disabled(inspectionReport == nil)
            .accessibilityLabel(metadataLabelText)
            .accessibilityHint(Localizable.string(.fileStructureAccessibilityHint))

            if customCoverImageData != nil {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.290, green: 0.871, blue: 0.502))
                    Text(Localizable.string(.customCoverBadge))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.722, green: 0.980, blue: 0.800))
                        .lineLimit(1)
                }
                .padding(.leading, 10)
                .padding(.trailing, 11)
                .frame(height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(red: 0.141, green: 0.722, blue: 0.341).opacity(0.24))
                )
            }

            Spacer()
        }
        .padding(.horizontal, metrics.horizontalPadding)
    }

    private var metadataLabelText: String {
        if videoDuration > 0 {
            return String(format: "LIVE · %@ · %.2fs", detectedBrand.displayName, videoDuration)
        }
        return "LIVE · \(detectedBrand.displayName)"
    }

    // MARK: - Floating Liquid Glass Bottom Dock

    private func floatingBottomDock(metrics: AdaptiveLayoutMetrics) -> some View {
        VStack(spacing: 12) {
            LiquidGlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    // 悬浮液态玻璃分段格式切换器
                    HStack(spacing: 0) {
                        ForEach(BatchExportFormat.allCases) { format in
                            let isSelected = selectedExportFormat == format
                            Button {
                                AppHaptics.selection()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    selectedExportFormat = format
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: format.icon)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                    Text(format.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .foregroundColor(isSelected ? .white : .white.opacity(0.68))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .contentShape(Capsule())
                                .background {
                                    if isSelected {
                                        Capsule(style: .continuous)
                                            .fill(Color.white.opacity(0.22))
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.75)
                                            )
                                            .matchedGeometryEffect(id: "singleFormatPill", in: formatNamespace)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)
                        }
                    }
                    .padding(3)
                    .frame(height: 44)
                    .liquidGlassControl(in: Capsule(), interactive: true, overDarkMedia: true)

                    // 悬浮液态玻璃封面帧按钮（仅在实况照片模式显示）
                    if selectedExportFormat == .livePhoto {
                        Button {
                            AppHaptics.lightImpact()
                            isShowingKeyframePicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(previewVideoURL == nil ? .white.opacity(0.35) : Color(red: 0.220, green: 0.737, blue: 0.878))
                                Text(Localizable.string(.inspectorCoverShort))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(previewVideoURL == nil ? .white.opacity(0.4) : .white.opacity(0.96))
                                    .lineLimit(1)
                            }
                            .padding(.leading, 14)
                            .padding(.trailing, 15)
                            .frame(height: 44)
                            .contentShape(Capsule())
                            .liquidGlassControl(in: Capsule(), interactive: true, overDarkMedia: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(previewVideoURL == nil || isProcessing)
                    }
                }
            }

            // 主导出行动按钮（.glassProminent）
            Button(action: performPrimaryExport) {
                HStack(spacing: 9) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: selectedExportFormat.icon)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text(primaryCTATitle)
                }
            }
            .buttonStyle(StudioPrimaryButtonStyle(isDisabled: selectedImage == nil || isProcessing, height: 54))
            .disabled(selectedImage == nil || isProcessing)
        }
        .frame(maxWidth: metrics.floatingDockMaxWidth)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.bottom, metrics.dockBottomPadding)
    }

    private var primaryCTATitle: String {
        switch selectedExportFormat {
        case .livePhoto:
            return Localizable.string(.exportLivePhotoCTA)
        case .video:
            return "\(Localizable.string(.export)) \(Localizable.string(.video))"
        case .gif:
            return "\(Localizable.string(.export)) \(Localizable.string(.gif))"
        }
    }

    // MARK: - Playback & Keyframe Controls

    private func startVideoPlayback() {
        guard !isPlayingVideo, videoPlayer != nil else { return }
        AppHaptics.lightImpact()
        isPlayingVideo = true
        videoPlayer?.seek(to: .zero)
        videoPlayer?.play()
    }

    private func stopVideoPlayback() {
        guard isPlayingVideo else { return }
        isPlayingVideo = false
        videoPlayer?.pause()
        videoPlayer?.seek(to: .zero)
    }

    private func cleanupPlaybackResources() {
        videoPlayer?.pause()
        if let observer = playerEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerEndObserver = nil
        }
        videoPlayer = nil
        MediaExportService.removeIfInTemporaryDirectory(previewVideoURL)
        previewVideoURL = nil
    }

    private func applyCustomCoverFrame(at seconds: Double) async {
        guard let videoURL = previewVideoURL, let extracted = motionPhotoData else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let newCoverData = try await MediaExportService.extractCoverFrameData(
                from: videoURL,
                at: seconds,
                preservingMetadataFrom: extracted.imageData
            )
            self.customCoverImageData = newCoverData
            self.selectedCoverSeconds = seconds
            self.stillImageTime = max(0, min(127, Int(round(seconds * videoFrameRate))))
            if let uiImage = UIImage(data: newCoverData) {
                self.selectedImage = uiImage
            }
            AppHaptics.success()
        } catch {
            AppHaptics.error()
            showAlert(message: error.localizedDescription)
        }
    }

    private func restoreOriginalCoverFrame() {
        self.customCoverImageData = nil
        self.selectedImage = originalPreviewImage
        self.stillImageTime = defaultStillImageTime
        if videoFrameRate > 0 {
            self.selectedCoverSeconds = Double(defaultStillImageTime) / videoFrameRate
        }
    }

    // MARK: - Off-Main-Thread Loading

    private struct LoadedMotionPhoto: Sendable {
        let extracted: MotionPhotoData
        let processor: MotionPhotoProcessorProtocol
        let previewImage: UIImage?
        let tempVideoURL: URL
        let creationDate: Date?
        let inspectionReport: MotionPhotoInspectionReport
    }

    private enum LoadError: Error {
        case unreadableFile
        case notMotionPhoto
        case processingFailed(String?)
        case videoWriteFailed(Error)
    }

    private nonisolated static func loadMotionPhotoOffMainThread(url: URL) throws -> LoadedMotionPhoto {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw LoadError.unreadableFile
        }

        let xmpInfo = XMPParser.extractAndParse(from: data)
        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) else {
            throw LoadError.notMotionPhoto
        }

        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard result.success, let extracted = result.data else {
            throw LoadError.processingFailed(result.errorMessage)
        }

        let previewImage = UIImage(data: extracted.imageData)
        let creationDate = MediaExportService.resolveCreationDate(originalData: data, fallbackURL: url)
        let inspectionReport = MotionPhotoStructureAnalyzer.analyze(
            data: data,
            xmpInfo: xmpInfo,
            extracted: extracted
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview_\(UUID().uuidString).mp4")
        do {
            try extracted.videoData.write(to: tempURL)
        } catch {
            MediaExportService.removeIfInTemporaryDirectory(tempURL)
            throw LoadError.videoWriteFailed(error)
        }

        return LoadedMotionPhoto(
            extracted: extracted,
            processor: processor,
            previewImage: previewImage,
            tempVideoURL: tempURL,
            creationDate: creationDate,
            inspectionReport: inspectionReport
        )
    }

    func extractVideoFromMotionPhoto(url: URL) async {
        cleanupPlaybackResources()
        customCoverImageData = nil
        inspectionReport = nil
        AppLogger.parser.info("Loading motion photo: \(url.lastPathComponent, privacy: .public)")

        let loaded: LoadedMotionPhoto
        do {
            loaded = try await Task.detached(priority: .userInitiated) {
                try Self.loadMotionPhotoOffMainThread(url: url)
            }.value
        } catch LoadError.unreadableFile {
            showAlert(message: Localizable.string(.cannotReadFile))
            return
        } catch LoadError.notMotionPhoto {
            showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
            return
        } catch LoadError.processingFailed(let message) {
            showAlert(message: message ?? Localizable.string(.selectedPhotoIsNotMotionPhoto))
            return
        } catch {
            AppLogger.parser.error("Failed to prepare preview video: \(error.localizedDescription, privacy: .public)")
            showAlert(message: Localizable.string(.errorProcessingVideoFile))
            return
        }

        self.motionPhotoData = loaded.extracted
        self.detectedBrand = loaded.extracted.brand
        self.originalPreviewImage = loaded.previewImage
        self.selectedImage = loaded.previewImage
        self.previewVideoURL = loaded.tempVideoURL
        self.inspectionReport = loaded.inspectionReport
        if let resolvedDate = loaded.creationDate {
            self.creationDate = resolvedDate
        }

        do {
            let asset = AVAsset(url: loaded.tempVideoURL)
            let duration = try await asset.load(.duration)
            let durationSec = CMTimeGetSeconds(duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let fps = Double(try await tracks.first?.load(.nominalFrameRate) ?? 30.0)
            let specs = await MotionPhotoStructureAnalyzer.extractVideoSpecs(from: asset)

            self.videoDuration = durationSec.isFinite ? durationSec : 0
            self.videoFrameRate = fps > 0 ? fps : 30.0
            self.inspectionReport?.videoSpecs = specs ?? MotionPhotoVideoSpecs(
                codecName: "—",
                width: 0,
                height: 0,
                frameRate: self.videoFrameRate,
                durationSeconds: self.videoDuration
            )

            let computedStillTime = loaded.processor.calculateStillImageTime(
                videoDuration: self.videoDuration,
                presentationTimestamp: loaded.extracted.presentationTimestamp,
                frameRate: self.videoFrameRate
            )
            self.stillImageTime = computedStillTime
            self.defaultStillImageTime = computedStillTime
            self.selectedCoverSeconds = min(self.videoDuration, Double(computedStillTime) / self.videoFrameRate)

            let player = AVPlayer(url: loaded.tempVideoURL)
            player.actionAtItemEnd = .none
            self.videoPlayer = player

            self.playerEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                guard let player, player.rate > 0 else { return }
                player.seek(to: .zero)
                player.play()
            }
        } catch {
            AppLogger.parser.error("Failed to prepare preview video: \(error.localizedDescription, privacy: .public)")
            MediaExportService.removeIfInTemporaryDirectory(loaded.tempVideoURL)
            self.previewVideoURL = nil
            showAlert(message: Localizable.string(.errorProcessingVideoFile))
        }
    }

    // MARK: - Export Actions

    private func performPrimaryExport() {
        AppHaptics.mediumImpact()
        switch selectedExportFormat {
        case .livePhoto:
            exportAsLivePhoto()
        case .video:
            exportVideo()
        case .gif:
            exportAsGIF()
        }
    }

    private func exportVideo() {
        guard let extracted = motionPhotoData else {
            showAlert(message: Localizable.string(.cannotGetVideoData))
            return
        }

        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await MediaExportService.exportVideo(
                    videoData: extracted.videoData,
                    fallbackURL: sourceURL,
                    preferredDate: creationDate
                )
                AppHaptics.success()
                showAlert(message: Localizable.string(.videoSaved))
            } catch {
                AppHaptics.error()
                handleExportError(error, prefix: Localizable.string(.savingVideoFailed))
            }
        }
    }

    private func exportAsLivePhoto() {
        guard let extracted = motionPhotoData else {
            showAlert(message: Localizable.string(.missingData))
            return
        }

        let effectiveData: MotionPhotoData
        if let customCover = customCoverImageData {
            effectiveData = MotionPhotoData(
                imageData: customCover,
                videoData: extracted.videoData,
                stillImageTime: stillImageTime,
                brand: extracted.brand,
                videoOffset: extracted.videoOffset,
                presentationTimestamp: extracted.presentationTimestamp
            )
        } else {
            effectiveData = extracted
        }

        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await MediaExportService.exportLivePhoto(
                    motionPhotoData: effectiveData,
                    fallbackURL: sourceURL,
                    preferredDate: creationDate,
                    stillImageTime: stillImageTime
                )
                AppHaptics.success()
                showAlert(message: Localizable.string(.livePhotoSaved))
            } catch {
                AppHaptics.error()
                handleExportError(error, prefix: Localizable.string(.savingLivePhotoFailed))
            }
        }
    }

    private func exportAsGIF() {
        guard let extracted = motionPhotoData else {
            showAlert(message: Localizable.string(.cannotGetVideoData))
            return
        }

        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await MediaExportService.exportGIF(
                    videoData: extracted.videoData,
                    fallbackURL: sourceURL,
                    preferredDate: creationDate
                )
                AppHaptics.success()
                showAlert(message: Localizable.string(.gifSavedToPhotos))
            } catch {
                AppHaptics.error()
                handleExportError(error, prefix: Localizable.string(.failedToCreateGIF))
            }
        }
    }

    private func handleExportError(_ error: Error, prefix: String) {
        if let exportError = error as? MediaExportError, case .photoLibraryPermissionDenied = exportError {
            showAlert(message: exportError.localizedDescription, isPermissionDenied: true)
        } else {
            showAlert(message: "\(prefix): \(error.localizedDescription)")
        }
    }

    private func showAlert(message: String, isPermissionDenied: Bool = false) {
        self.alertMessage = message
        self.isPermissionDeniedAlert = isPermissionDenied
        self.showAlert = true
    }
}
