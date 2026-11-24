//
//  BatchConvertView.swift
//  Motion2Live
//
//  Created for Motion2Live Batch Conversion Feature.
//

import SwiftUI
import Combine
import Photos
import AVFoundation
import ImageIO

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
        case .pending: return .secondary
        case .processing: return .blue
        case .success: return .green
        case .failed: return .red
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

// MARK: - Export Format
enum BatchExportFormat: String, CaseIterable, Identifiable {
    case livePhoto = "Live Photo"
    case video = "Video"
    case gif = "GIF"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .livePhoto: return Localizable.string(.livePhoto)
        case .video: return Localizable.string(.video)
        case .gif: return Localizable.string(.gif)
        }
    }
    
    var icon: String {
        switch self {
        case .livePhoto: return "livephoto"
        case .video: return "video.fill"
        case .gif: return "photo.on.rectangle.angled"
        }
    }
    
    var description: String {
        switch self {
        case .livePhoto: return Localizable.string(.livePhotoFormatDesc)
        case .video: return Localizable.string(.videoFormatDesc)
        case .gif: return Localizable.string(.gifFormatDesc)
        }
    }
}

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
            kCGImageSourceThumbnailMaxPixelSize: 160
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
}

// MARK: - Batch Convert View Model
@MainActor
final class BatchConvertViewModel: ObservableObject {
    @Published var items: [BatchPhotoItem] = []
    @Published var selectedFormat: BatchExportFormat = .livePhoto
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

    func startBatchConversion() {
        guard !isProcessing && !isTaskRunning else { return }
        isProcessing = true
        isTaskRunning = true
        isCancelled = false
        isFinished = false
        shouldCleanupOnFinish = false
        currentIndex = 0
        successCount = 0
        failureCount = 0

        // 批量转换期间保持屏幕常亮
        UIApplication.shared.isIdleTimerDisabled = true

        // 重置所有项目状态为待处理
        for i in 0..<items.count {
            items[i].status = .pending
            items[i].errorMessage = nil
        }

        let format = selectedFormat
        conversionTask = Task {
            for index in 0..<self.items.count {
                if Task.isCancelled || self.isCancelled {
                    break
                }

                self.currentIndex = index + 1
                self.items[index].status = .processing

                let itemURL = self.items[index].url
                do {
                    try await MotionPhotoBatchService.processSingleItem(url: itemURL, format: format)
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
            UIApplication.shared.isIdleTimerDisabled = false

            if self.shouldCleanupOnFinish {
                self.performTempFileCleanup()
            } else if !self.isCancelled {
                // 仅在正常完成时触发触感反馈
                if self.failureCount == 0 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }
    }

    func cancelConversion() {
        isCancelled = true
        conversionTask?.cancel()
        isProcessing = false
        UIApplication.shared.isIdleTimerDisabled = false
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
    @Namespace private var formatAnimation
    var onDismiss: (() -> Void)? = nil
    
    init(motionPhotoURLs: [URL], ignoredCount: Int, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: BatchConvertViewModel(urls: motionPhotoURLs, ignoredCount: ignoredCount))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部信息总览卡片
                headerSummaryCard
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                // 导出格式选择器
                formatSelectorSection
                    .padding(.horizontal)
                    .padding(.top, 14)
                
                // 照片卡片列表
                photosListView
                    .padding(.top, 12)
                
                // 底部常驻操作区
                bottomActionBar
            }
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle(Localizable.string(.batchConvert))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Localizable.string(.cancel)) {
                        if viewModel.isProcessing {
                            viewModel.cancelConversion()
                        }
                        viewModel.cleanupTempFiles()
                        onDismiss?()
                        dismiss()
                    }
                    .foregroundColor(viewModel.isProcessing ? .secondary : .primary)
                }
            }
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
        }
    }
    
    // MARK: - Header Summary Card
    private var headerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(Localizable.string(.batchMotionPhotoCount, viewModel.items.count))
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if viewModel.ignoredCount > 0 {
                        Text(Localizable.string(.batchIgnoredCount, viewModel.ignoredCount))
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text(Localizable.string(.batchPhotoCount, viewModel.items.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if viewModel.isFinished {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("\(viewModel.successCount)/\(viewModel.items.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Format Selector Section
    private var formatSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Localizable.string(.exportFormat))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            // 纯 SwiftUI 像素级对齐分段控制器 (避免 UIKit UISegmentedControl 图标文字错位问题)
            HStack(spacing: 0) {
                ForEach(BatchExportFormat.allCases) { format in
                    let isSelected = viewModel.selectedFormat == format
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedFormat = format
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: format.icon)
                                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            Text(format.displayName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                        }
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "formatSelectorHighlight", in: formatAnimation)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessing)
                }
            }
            .padding(3)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(9)
            
            // 格式简短说明
            Text(viewModel.selectedFormat.description)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 2)
        }
    }
    
    // MARK: - Photos List View
    private var photosListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.items) { item in
                    HStack(spacing: 12) {
                        // 缩略图
                        if let thumb = item.thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 52, height: 52)
                                .clipped()
                                .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 52, height: 52)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        // 文件信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.fileName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 状态指示器
                        statusIndicator(for: item)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Status Indicator
    @ViewBuilder
    private func statusIndicator(for item: BatchPhotoItem) -> some View {
        switch item.status {
        case .pending:
            HStack(spacing: 4) {
                Image(systemName: item.status.iconName)
                    .font(.footnote)
                    .foregroundColor(item.status.iconColor)
                Text(item.status.title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        case .processing:
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.7)
                Text(item.status.title)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: item.status.iconName)
                    .font(.subheadline)
                    .foregroundColor(item.status.iconColor)
            }
        case .failed:
            Button(action: {
                viewModel.selectedErrorItem = item
            }) {
                HStack(spacing: 4) {
                    Image(systemName: item.status.iconName)
                        .font(.subheadline)
                        .foregroundColor(item.status.iconColor)
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            Divider()
            
            if viewModel.isProcessing {
                // 正在处理状态
                VStack(spacing: 8) {
                    HStack {
                        Text(Localizable.string(.convertingItem, viewModel.currentIndex, viewModel.items.count))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: viewModel.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    Button(action: viewModel.cancelConversion) {
                        Text(Localizable.string(.cancelConversion))
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            } else if viewModel.isFinished {
                // 处理完成或已取消状态
                VStack(spacing: 10) {
                    if viewModel.isCancelled {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.orange)
                            Text(Localizable.string(.batchCancelledSummary, viewModel.successCount))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else if viewModel.failureCount == 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(Localizable.string(.batchCompletedAllSuccess, viewModel.successCount))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(Localizable.string(.batchCompletedPartial, viewModel.successCount, viewModel.failureCount))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Button(action: {
                        viewModel.cleanupTempFiles()
                        onDismiss?()
                        dismiss()
                    }) {
                        Text(Localizable.string(.done))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            } else {
                // 未开始状态
                Button(action: {
                    viewModel.startBatchConversion()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(Localizable.string(.startBatchConversion))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .background(
            Color(UIColor.systemBackground).opacity(0.9)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
}
