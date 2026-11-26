//
//  BatchConvertView.swift
//  Motion2Live
//
//  Batch Motion Photo Conversion with Adaptive Photo Grid & Apple HIG Liquid Glass controls.
//

import SwiftUI
import Combine
import Photos
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum BatchExportDestination: String, CaseIterable, Identifiable {
    case photos
    case folder

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .photos: return Localizable.string(.batchExportDestinationPhotos)
        case .folder: return Localizable.string(.batchExportDestinationFolder)
        }
    }

    var icon: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .folder: return "folder"
        }
    }
}

// MARK: - Batch Item Status
enum BatchItemStatus: Equatable {
    case pending
    case processing
    case success
    case failed(String)

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .pending: return AppTheme.textTertiary
        case .processing: return AppTheme.accent
        case .success: return AppTheme.success
        case .failed: return AppTheme.danger
        }
    }

    var title: String {
        switch self {
        case .pending: return Localizable.string(.statusPending)
        case .processing: return Localizable.string(.statusProcessing)
        case .success: return Localizable.string(.statusSuccess)
        case .failed: return Localizable.string(.statusFailed)
        }
    }
}

// BatchExportFormat moved to Motion2Live/Models/ExportFormat.swift

// MARK: - Batch Photo Item
struct BatchPhotoItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    var fileSize: Int64 = 0
    var thumbnail: UIImage? = nil
    var status: BatchItemStatus = .pending
    var errorMessage: String? = nil

    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent
    }

    static func loadMetadata(from url: URL) -> (fileSize: Int64, thumbnail: UIImage?) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let thumb = createThumbnail(from: url)
        return (size, thumb)
    }

    private static func createThumbnail(from url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 320
        ]
        guard let imageRef = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: imageRef)
    }
}

// MARK: - Batch Conversion Service
enum MotionPhotoBatchService {
    static func processSingleItem(url: URL, format: BatchExportFormat) async throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let xmpInfo = XMPParser.extractAndParse(from: data)
        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) else {
            throw NSError(domain: "BatchConvert", code: 1, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.invalidMotionPhotoOrUnsupportedFormat)])
        }

        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard result.success, let motionPhotoData = result.data else {
            throw NSError(domain: "BatchConvert", code: 2, userInfo: [NSLocalizedDescriptionKey: result.errorMessage ?? Localizable.string(.conversionFailed)])
        }

        switch format {
        case .video:
            try await MediaExportService.exportVideo(
                videoData: motionPhotoData.videoData,
                originalData: data,
                fallbackURL: url
            )
        case .livePhoto:
            try await MediaExportService.exportLivePhoto(
                motionPhotoData: motionPhotoData,
                originalData: data,
                fallbackURL: url,
                processor: processor
            )
        case .gif:
            try await MediaExportService.exportGIF(
                videoData: motionPhotoData.videoData,
                originalData: data,
                fallbackURL: url
            )
        }
    }

    static func processSingleItemToFolder(url: URL, format: BatchExportFormat, folderURL: URL) async throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let xmpInfo = XMPParser.extractAndParse(from: data)
        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) else {
            throw NSError(domain: "BatchConvert", code: 1, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.invalidMotionPhotoOrUnsupportedFormat)])
        }

        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard result.success, let motionPhotoData = result.data else {
            throw NSError(domain: "BatchConvert", code: 2, userInfo: [NSLocalizedDescriptionKey: result.errorMessage ?? Localizable.string(.conversionFailed)])
        }

        let rawBase = url.deletingPathExtension().lastPathComponent
        let baseName = rawBase.isEmpty ? "Motion2Live" : rawBase

        switch format {
        case .video:
            let destURL = uniqueDestinationURL(in: folderURL, baseName: baseName, ext: "mp4")
            try motionPhotoData.videoData.write(to: destURL, options: .atomic)
        case .gif:
            let tempMP4 = FileManager.default.temporaryDirectory
                .appendingPathComponent("batch_gif_\(UUID().uuidString).mp4")
            let tempGIF = FileManager.default.temporaryDirectory
                .appendingPathComponent("batch_gif_\(UUID().uuidString).gif")
            defer {
                MediaExportService.removeIfInTemporaryDirectory(tempMP4)
                MediaExportService.removeIfInTemporaryDirectory(tempGIF)
            }
            try motionPhotoData.videoData.write(to: tempMP4, options: .atomic)
            let asset = AVAsset(url: tempMP4)
            try await MediaExportService.createGIFFile(from: asset, outputURL: tempGIF)
            let destURL = uniqueDestinationURL(in: folderURL, baseName: baseName, ext: "gif")
            try FileManager.default.copyItem(at: tempGIF, to: destURL)
        case .livePhoto:
            try await MediaExportService.exportLivePhoto(
                motionPhotoData: motionPhotoData,
                originalData: data,
                fallbackURL: url,
                processor: processor
            )
        }
    }

    private static func uniqueDestinationURL(in folderURL: URL, baseName: String, ext: String) -> URL {
        var candidate = folderURL.appendingPathComponent("\(baseName).\(ext)")
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(baseName)_\(suffix).\(ext)")
            suffix += 1
        }
        return candidate
    }
}

// MARK: - Batch Convert View Model
@MainActor
final class BatchConvertViewModel: ObservableObject {
    @Published var items: [BatchPhotoItem] = []
    @Published var selectedFormat: BatchExportFormat = .livePhoto
    @Published var exportDestination: BatchExportDestination = .photos
    @Published var isShowingFolderImporter = false
    @Published var isProcessing = false
    @Published var currentIndex = 0
    @Published var isCancelled = false
    @Published var isFinished = false
    @Published var successCount = 0
    @Published var failureCount = 0
    @Published var selectedErrorItem: BatchPhotoItem? = nil

    let ignoredCount: Int
    private var conversionTask: Task<Void, Never>? = nil
    private var isTaskRunning = false
    private var shouldCleanupOnFinish = false

    init(urls: [URL], ignoredCount: Int) {
        self.ignoredCount = ignoredCount
        self.items = urls.map { BatchPhotoItem(url: $0) }
    }

    var progress: Double {
        guard !items.isEmpty else { return 0.0 }
        return Double(currentIndex) / Double(items.count)
    }

    func loadThumbnails() async {
        let targets = items.map { ($0.id, $0.url) }
        for (id, url) in targets {
            if Task.isCancelled { break }
            let metadata = await Task.detached(priority: .userInitiated) {
                BatchPhotoItem.loadMetadata(from: url)
            }.value
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].fileSize = metadata.fileSize
                items[idx].thumbnail = metadata.thumbnail
            }
        }
    }

    func startBatchConversion(toFolder folderURL: URL? = nil) {
        guard !isProcessing && !isTaskRunning else { return }
        isProcessing = true
        isTaskRunning = true
        isCancelled = false
        isFinished = false
        shouldCleanupOnFinish = false
        currentIndex = 0
        successCount = 0
        failureCount = 0

        #if !targetEnvironment(macCatalyst)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        for i in 0..<items.count {
            items[i].status = .pending
            items[i].errorMessage = nil
        }

        let format = selectedFormat
        conversionTask = Task {
            let accessedFolder = folderURL?.startAccessingSecurityScopedResource() ?? false
            defer {
                if accessedFolder {
                    folderURL?.stopAccessingSecurityScopedResource()
                }
            }

            for index in 0..<self.items.count {
                if Task.isCancelled || self.isCancelled {
                    break
                }

                self.currentIndex = index + 1
                self.items[index].status = .processing

                let itemURL = self.items[index].url
                do {
                    if let folderURL, format != .livePhoto {
                        try await MotionPhotoBatchService.processSingleItemToFolder(
                            url: itemURL,
                            format: format,
                            folderURL: folderURL
                        )
                    } else {
                        try await MotionPhotoBatchService.processSingleItem(url: itemURL, format: format)
                    }
                    self.items[index].status = .success
                    self.successCount += 1
                } catch is CancellationError {
                    self.items[index].status = .pending
                    self.isCancelled = true
                    break
                } catch {
                    if Task.isCancelled || self.isCancelled {
                        self.items[index].status = .pending
                        break
                    }
                    self.items[index].status = .failed(error.localizedDescription)
                    self.items[index].errorMessage = error.localizedDescription
                    self.failureCount += 1
                }
            }

            self.isTaskRunning = false
            self.isProcessing = false
            self.isFinished = true
            #if !targetEnvironment(macCatalyst)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif

            if self.shouldCleanupOnFinish {
                self.performTempFileCleanup()
            } else if !self.isCancelled {
                if self.failureCount == 0 {
                    AppHaptics.success()
                } else {
                    AppHaptics.warning()
                }
            }
        }
    }

    func cancelConversion() {
        isCancelled = true
        conversionTask?.cancel()
        isProcessing = false
        #if !targetEnvironment(macCatalyst)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    func cleanupTempFiles() {
        if isTaskRunning {
            shouldCleanupOnFinish = true
        } else {
            performTempFileCleanup()
        }
    }

    private func performTempFileCleanup() {
        shouldCleanupOnFinish = false
        for item in items {
            MediaExportService.removeIfInTemporaryDirectory(item.url)
        }
    }
}

// MARK: - Batch Convert View
struct BatchConvertView: View {
    @StateObject private var viewModel: BatchConvertViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var formatAnimation
    @State private var folderErrorMessage: String?
    var onDismiss: (() -> Void)? = nil

    init(motionPhotoURLs: [URL], ignoredCount: Int, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: BatchConvertViewModel(urls: motionPhotoURLs, ignoredCount: ignoredCount))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
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
                        // 顶部悬浮液态玻璃导航栏
                        topNavigationBar(metrics: metrics)

                        // 内容区：标准 iOS 分段格式控制器（无玻璃特效）
                        formatSelectorSection(metrics: metrics)
                            .padding(.top, metrics.isCompactShortScreen ? 6 : 10)

                        // 自适应照片小图网格（iPhone 3 列 / Duo 4-5 列 / iPad 5-6 列）
                        photoThumbnailGrid(metrics: metrics)
                            .padding(.top, metrics.isCompactShortScreen ? 10 : 14)

                        // 底部悬浮液态玻璃操作/进度区
                        bottomFloatingDock(metrics: metrics)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .interactiveDismissDisabled(viewModel.isProcessing)
            .task {
                await viewModel.loadThumbnails()
            }
            .onDisappear {
                viewModel.cleanupTempFiles()
            }
            .alert(item: $viewModel.selectedErrorItem) { item in
                Alert(
                    title: Text(item.fileName),
                    message: Text(item.errorMessage ?? Localizable.string(.unknownError)),
                    dismissButton: .default(Text(Localizable.string(.ok)))
                )
            }
            .fileImporter(
                isPresented: $viewModel.isShowingFolderImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let folderURL = urls.first {
                        viewModel.startBatchConversion(toFolder: folderURL)
                    }
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError {
                        folderErrorMessage = error.localizedDescription
                    }
                }
            }
            .alert(Localizable.string(.error), isPresented: Binding(
                get: { folderErrorMessage != nil },
                set: { if !$0 { folderErrorMessage = nil } }
            )) {
                Button(Localizable.string(.ok), role: .cancel) {}
            } message: {
                Text(folderErrorMessage ?? "")
            }
        }
    }

    // MARK: - Top Floating Navigation Bar

    private func topNavigationBar(metrics: AdaptiveLayoutMetrics) -> some View {
        ZStack {
            // 中央双行标题
            VStack(spacing: 1) {
                Text(Localizable.string(.batchTitleWithCount, viewModel.items.count))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                if viewModel.ignoredCount > 0 {
                    Text(Localizable.string(.batchIgnoredCount, viewModel.ignoredCount))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            HStack {
                StudioIconCircleButton(
                    systemName: "xmark",
                    accessibilityLabel: Localizable.string(.cancel),
                    size: 38
                ) {
                    if viewModel.isProcessing {
                        viewModel.cancelConversion()
                    }
                    viewModel.cleanupTempFiles()
                    onDismiss?()
                    dismiss()
                }

                Spacer()

                if viewModel.isFinished {
                    let isSuccess = !viewModel.isCancelled && viewModel.failureCount == 0
                    let badgeColor = isSuccess ? AppTheme.success : AppTheme.warning
                    HStack(spacing: 4) {
                        Image(systemName: isSuccess ? "checkmark" : "exclamationmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(viewModel.successCount)/\(viewModel.items.count)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(badgeColor)
                    .padding(.leading, 10)
                    .padding(.trailing, 11)
                    .frame(height: 34)
                    .background(
                        Capsule(style: .continuous)
                            .fill(badgeColor.opacity(0.16))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(badgeColor.opacity(0.35), lineWidth: 0.8)
                            )
                    )
                }
            }
        }
        .frame(height: 54)
        .padding(.horizontal, max(16, metrics.horizontalPadding - 2))
        .padding(.top, 4)
    }

    // MARK: - Standard Content-Layer Format Segmented Control (No Glass per HIG)

    private func formatSelectorSection(metrics: AdaptiveLayoutMetrics) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(BatchExportFormat.allCases) { format in
                    let isSelected = viewModel.selectedFormat == format
                    Button {
                        AppHaptics.selection()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            viewModel.selectedFormat = format
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: format.icon)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            Text(format.displayName)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Capsule())
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(AppTheme.surface0)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.6)
                                    )
                                    .shadow(
                                        color: Color.black.opacity(colorScheme == .light ? 0.06 : 0),
                                        radius: 3,
                                        y: 1
                                    )
                                    .matchedGeometryEffect(id: "formatSelectorHighlight", in: formatAnimation)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessing)
                }
            }
            .padding(3)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.surface1)
            )

            Text(viewModel.selectedFormat.description)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if viewModel.selectedFormat != .livePhoto {
                HStack(spacing: 6) {
                    ForEach(BatchExportDestination.allCases) { destination in
                        let isSelected = viewModel.exportDestination == destination
                        Button {
                            AppHaptics.selection()
                            viewModel.exportDestination = destination
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: destination.icon)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                Text(destination.displayName)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            }
                            .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? AppTheme.accent.opacity(0.14) : AppTheme.surface1)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(isSelected ? AppTheme.accent.opacity(0.45) : AppTheme.borderSubtle, lineWidth: 0.7)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isProcessing)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: metrics.isExpandedCanvas ? 520 : .infinity)
        .padding(.horizontal, max(16, metrics.horizontalPadding - 4))
    }

    // MARK: - Adaptive Photo Thumbnail Grid

    private func photoThumbnailGrid(metrics: AdaptiveLayoutMetrics) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: metrics.batchGridColumns
        )

        return ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.items) { item in
                    BatchPhotoGridTile(
                        item: item,
                        isBatchRunning: viewModel.isProcessing,
                        onTapError: {
                            viewModel.selectedErrorItem = item
                        }
                    )
                }
            }
            .frame(maxWidth: metrics.batchGridMaxWidth)
            .padding(.horizontal, max(16, metrics.horizontalPadding - 4))
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bottom Floating Liquid Glass Dock

    private func bottomFloatingDock(metrics: AdaptiveLayoutMetrics) -> some View {
        VStack(spacing: 10) {
            if viewModel.isProcessing {
                LiquidGlassGroup(spacing: 10) {
                    HStack(spacing: 10) {
                        // 悬浮液态玻璃进度胶囊
                        VStack(spacing: 6) {
                            HStack {
                                Text(Localizable.string(.convertingItem, viewModel.currentIndex, viewModel.items.count))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(Int(viewModel.progress * 100))%")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(AppTheme.accent)
                            }

                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    Capsule(style: .continuous)
                                        .fill(AppTheme.surface2)
                                    Capsule(style: .continuous)
                                        .fill(AppTheme.accent)
                                        .frame(width: max(8, barGeo.size.width * CGFloat(viewModel.progress)))
                                        .animation(.easeOut(duration: 0.25), value: viewModel.progress)
                                }
                            }
                            .frame(height: 5)
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .liquidGlassControl(in: Capsule(), interactive: false)

                        // 独立悬浮液态玻璃取消圆形按钮
                        Button {
                            AppHaptics.warning()
                            viewModel.cancelConversion()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 54, height: 54)
                                .contentShape(Circle())
                                .liquidGlassControl(in: Circle(), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Localizable.string(.cancelConversion))
                    }
                }
            } else if viewModel.isFinished {
                VStack(spacing: 10) {
                    completionSummaryLine

                    Button {
                        viewModel.cleanupTempFiles()
                        onDismiss?()
                        dismiss()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                            Text(Localizable.string(.done))
                        }
                    }
                    .buttonStyle(StudioPrimaryButtonStyle(height: 54))
                }
            } else {
                Button {
                    AppHaptics.mediumImpact()
                    if viewModel.selectedFormat != .livePhoto && viewModel.exportDestination == .folder {
                        viewModel.isShowingFolderImporter = true
                    } else {
                        viewModel.startBatchConversion()
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: viewModel.selectedFormat != .livePhoto && viewModel.exportDestination == .folder ? "folder" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .semibold))
                        Text(viewModel.selectedFormat != .livePhoto && viewModel.exportDestination == .folder
                             ? Localizable.string(.chooseExportFolder)
                             : Localizable.string(.startBatchConversionWithCount, viewModel.items.count))
                    }
                }
                .buttonStyle(StudioPrimaryButtonStyle(height: 54))
            }
        }
        .frame(maxWidth: metrics.floatingDockMaxWidth)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, metrics.dockBottomPadding)
        .frame(maxWidth: .infinity)
        .background(
            AppTheme.canvas.opacity(0.94)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var completionSummaryLine: some View {
        if viewModel.isCancelled {
            HStack(spacing: 5) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.warning)
                Text(Localizable.string(.batchCancelledSummary, viewModel.successCount))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.warning)
            }
        } else if viewModel.failureCount == 0 {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.success)
                Text(Localizable.string(.batchCompletedAllSuccess, viewModel.successCount))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.success)
            }
        } else {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.warning)
                Text(Localizable.string(.batchCompletedPartial, viewModel.successCount, viewModel.failureCount))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.warning)
            }
        }
    }
}

// MARK: - Individual Grid Tile
private struct BatchPhotoGridTile: View {
    let item: BatchPhotoItem
    let isBatchRunning: Bool
    let onTapError: () -> Void

    private var isProcessingItem: Bool {
        item.status == .processing
    }

    private var isDimmedPending: Bool {
        isBatchRunning && item.status == .pending
    }

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width

            ZStack {
                // Thumbnail
                if let thumb = item.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side, height: side)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(AppTheme.surface1)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(AppTheme.textTertiary)
                        )
                }

                // Dim pending tiles while batch is actively converting
                if isDimmedPending {
                    Color.black.opacity(0.42)
                }

                // Ready state: subtle bottom vignette + quiet LIVE badge
                if !isBatchRunning && item.status == .pending {
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: side * 0.38)
                    }

                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 3) {
                                Image(systemName: "livephoto")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(red: 0.220, green: 0.737, blue: 0.878))
                                Text("LIVE")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.95))
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 7)
                            .frame(height: 20)
                            .quietPhotoBadge(cornerRadius: 9)

                            Spacer()
                        }
                        .padding(7)
                    }
                }

                // Processing state: centered dark circle + cyan spinner (no glass border per HIG)
                if isProcessingItem {
                    Color.black.opacity(0.28)
                    Circle()
                        .fill(Color(red: 0.039, green: 0.051, blue: 0.071).opacity(0.68))
                        .frame(width: 46, height: 46)
                        .overlay(
                            ProgressView()
                                .tint(AppTheme.accent)
                                .scaleEffect(1.05)
                        )
                }

                // Success / Failed top-trailing badge
                if case .success = item.status {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(AppTheme.success)
                                .frame(width: 23, height: 23)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        Spacer()
                    }
                    .padding(7)
                } else if case .failed = item.status {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onTapError) {
                                Circle()
                                    .fill(AppTheme.danger)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "exclamationmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(7)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.tile, style: .continuous)
                    .strokeBorder(
                        isProcessingItem ? AppTheme.accent : AppTheme.borderSubtle,
                        lineWidth: isProcessingItem ? 2.2 : 0.6
                    )
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
