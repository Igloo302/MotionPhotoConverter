//
//  MotionPhotoConverterApp.swift
//  MotionPhotoConverter
//
//  Created by larry.shen on 2024/9/14.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers
import Photos
import CoreServices
import CoreLocation
import PhotosUI
import ImageIO
import MobileCoreServices

@main
struct MotionPhotoConverterApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

struct HomeView: View {
    @State private var isShowingPhotoPicker = false
    @State private var selectedImageURL: URL?
    @State private var randomEmojis: [String] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Emoji 布局
                ZStack {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(randomEmojis, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 40))
                        }
                    }
                    .padding(.top, 40)
                    
                    Text("📷")
                        .font(.system(size: 80))
                        .offset(y: 20)
                }
                .frame(height: UIScreen.main.bounds.height * 0.35)
                .background(Color.gray.opacity(0.1))
                
                VStack(spacing: 30) {
                    // 应用名称
                    Text("Motion Photo Converter")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    // 应用介绍
                    Text("Transform your Motion Photos into Live Photos or GIFs with ease. Capture the magic of movement and share your memories in dynamic formats.")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 选择按钮
                    Button(action: {
                        isShowingPhotoPicker = true
                    }) {
                        Text("Select Motion Photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
                .padding(.top, 40)
            }
            .edgesIgnoringSafeArea(.top)
            .sheet(isPresented: $isShowingPhotoPicker) {
                PhotoPicker(onImagePicked: { url, isMotionPhoto in
                    if isMotionPhoto {
                        self.selectedImageURL = url
                    } else {
                        self.showAlert = true
                        self.alertMessage = "所选照片不是 Motion Photo"
                    }
                })
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedImageURL != nil },
                set: { if !$0 { selectedImageURL = nil } }
            )) {
                if let url = selectedImageURL {
                    MotionPhotoView(sourceURL: url)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
            }
        }
        .onAppear {
            randomEmojis = generateRandomEmojis()
        }
    }
    
    func generateRandomEmojis() -> [String] {
        let natureEmojis = ["🌳", "🌲", "🌴", "🌵", "🌿", "🍀", "🍁", "🍂", "🍃", "🌺", "🌸", "🌼", "🌻", "🌞", "⛅️", "🌤", "🌈", "🦋", "🐝", "🐞"]
        return Array(natureEmojis.shuffled().prefix(12))
    }
}

// 在文件顶部添加 VideoPlayerObserver 类的定义
class VideoPlayerObserver: NSObject, ObservableObject {
    @Published var isVideoReady = false
    var player: AVPlayer? {
        didSet {
            if let player = player {
                player.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                if playerItem.status == .readyToPlay {
                    DispatchQueue.main.async {
                        self.isVideoReady = true
                    }
                }
            }
        }
    }
    
    deinit {
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
    }
}

struct MotionPhotoView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var sourceURL: URL  // 将 sourceURL 改为可变属性
    
    @State private var selectedImage: UIImage?
    @State private var videoPlayer: AVPlayer?
    @State private var isPlayingVideo = false
    @State private var originalImageData: Data?
    @State private var videoData: Data?
    @State private var isShowingPhotoPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    @State private var stillImageTime: Int8 = 0
    @Environment(\.colorScheme) var colorScheme
    @State private var isExportingGIF = false
    @State private var isExportMenuPresented = false
    @State private var creationDate: Date?
    @StateObject private var videoPlayerObserver = VideoPlayerObserver()
    @State private var imageSize: CGSize = .zero
    
    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        _selectedImage = State(initialValue: UIImage(contentsOfFile: sourceURL.path))
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                if let image = selectedImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .edgesIgnoringSafeArea(.horizontal)
                        
                        if let player = videoPlayer {
                            PlayerView(player: player)
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .edgesIgnoringSafeArea(.horizontal)
                                .opacity(isPlayingVideo ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: isPlayingVideo)
                                .clipped()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startVideoPlayback() }
                            .onEnded { _ in stopVideoPlayback() }
                    )
                } else {
                    Text("请选择 Motion Photo")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 优化后的导出按钮
                Button(action: { isExportMenuPresented = true }) {
                    Text("Export")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .disabled(selectedImage == nil)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)  // 添加这一行来隐藏返回按钮
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let date = creationDate {
                    VStack(alignment: .leading) {
                        Text(date, style: .date)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(date, style: .time)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        isShowingPhotoPicker = true
                    }) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .actionSheet(isPresented: $isExportMenuPresented) {
            ActionSheet(title: Text("选择导出格式"), buttons: [
                .default(Text("Live Photo")) { exportAsLivePhoto() },
                .default(Text("GIF")) { exportAsGIF() },
                .cancel()
            ])
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(onImagePicked: { url, isMotionPhoto in
                Task {
                    if isMotionPhoto {
                        await self.extractVideoFromMotionPhoto(url: url)
                    } else {
                        await MainActor.run {
                            self.showAlert(message: "所选照片不是 Motion Photo")
                        }
                    }
                }
            })
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
        .onAppear {
            Task {
                await extractVideoFromMotionPhoto(url: sourceURL)
            }
        }
    }
    
    func startVideoPlayback() {
        isPlayingVideo = true
        videoPlayer?.seek(to: .zero)
        videoPlayer?.play()
    }
    
    func stopVideoPlayback() {
        isPlayingVideo = false
        videoPlayer?.pause()
        videoPlayer?.seek(to: .zero)
    }
    
    func extractVideoFromMotionPhoto(url: URL) async {
        print("开始处理文件: \(url.path)")
        
        guard let data = try? Data(contentsOf: url) else {
            await MainActor.run {
                print("无法读取文件: \(url.path)")
                showAlert(message: "无法读取文件")
            }
            return
        }
        
        print("文件大小: \(data.count) bytes")
        
        // 尝试提取和解析 XMP 数据
        if let xmpData = extractXMPData(from: data),
           let xmpInfo = parseXMP(data: xmpData) {
            print("XMP 元数据: \(xmpInfo)")
            
            if let offset = xmpInfo["GCamera:MicroVideoOffset"] ?? xmpInfo["GContainer:ItemLength"],
               let offsetValue = Int(offset),
               let timestampString = xmpInfo["GCamera:MicroVideoPresentationTimestampUs"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"],
               let timestamp = Double(timestampString) {
                
                print("视频偏移量: \(offsetValue)")
                print("视频时间戳: \(timestamp) 微秒")
                
                // 提取视频数据
                self.videoData = data.suffix(offsetValue)
                print("提取的视频数据大小: \(self.videoData?.count ?? 0) bytes")
                
                // 处理图像
                self.selectedImage = UIImage(contentsOfFile: url.path)
                self.originalImageData = data
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
                do {
                    try videoData?.write(to: tempURL)
                    let asset = AVAsset(url: tempURL)
                    
                    // 获取视频时长
                    let duration = try await asset.load(.duration)
                    let videoDuration = CMTimeGetSeconds(duration)
                    
                    // 获取视频帧率（使用新的 API）
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    let frameRate = try await tracks.first?.load(.nominalFrameRate) ?? 30.0
                    
                    // 使用 MicroVideoPresentationTimestampUs 作为照片时间（转换为秒）
                    let photoTime = timestamp / 1_000_000.0
                    
                    // 计算 stillImageTime
                    self.stillImageTime = Int8(calculateStillImageTime(videoDuration: videoDuration, photoTime: photoTime, frameRate: Double(frameRate)))
                    
                    print("视频时长: \(videoDuration) 秒")
                    print("视频帧率: \(frameRate) fps")
                    print("照片时间: \(photoTime) 秒")
                    print("计算得到的 stillImageTime: \(self.stillImageTime)")
                    
                    await MainActor.run {
                        self.videoPlayer = AVPlayer(url: tempURL)
                        self.videoPlayer?.actionAtItemEnd = .none
                        
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.videoPlayer?.currentItem, queue: .main) { notification in
                            self.videoPlayer?.seek(to: .zero)
                            self.videoPlayer?.play()
                        }
                        
                        // 设置视频播放器观察者
                        videoPlayerObserver.player = self.videoPlayer
                    }
                } catch {
                    print("处理视频文件时出错: \(error)")
                    print("错误详情: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("错误域: \(nsError.domain)")
                        print("错误代码: \(nsError.code)")
                        print("错误用户信息: \(nsError.userInfo)")
                    }
                    await MainActor.run {
                        showAlert(message: "处理视频文件时出错，请查看控制台日志以获取详细信息。")
                    }
                }
                
                // 获取创建日期
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let creationDate = attributes[.creationDate] as? Date {
                    await MainActor.run {
                        self.creationDate = creationDate
                    }
                }
                
                return
            }
        }
        
        await MainActor.run {
            print("无法提取视频数据")
            showAlert(message: "这不是一个有效的 Motion Photo 或格式不受支持")
        }
    }
    
    @MainActor
    func exportAsLivePhoto() {
        guard let imageData = originalImageData, let videoData = videoData else {
            showAlert(message: "缺少必要数据")
            return
        }
        
        print("开始导出 Live Photo")
        print("原始数据大小: \(imageData.count) bytes")
        print("视频数据大小: \(videoData.count) bytes")
        print("源文件 URL: \(sourceURL.path)")

        let sourceFileName = sourceURL.deletingPathExtension().lastPathComponent
        let uniqueID = UUID().uuidString
        let jpegURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).jpg")
        let mp4URL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).mp4")
        let movURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).mov")
        
        do {
            // 获取源文件的创建日期和修改日期
            let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            let creationDate = attributes[.creationDate] as? Date
            let modificationDate = attributes[.modificationDate] as? Date
            
            // 从原始数据中剔除视频数据
            let pureImageData = imageData.prefix(imageData.count - videoData.count)
            
            // 将纯图像数据写入 JPEG 文件
            try pureImageData.write(to: jpegURL)
            print("成功写入纯 JPEG 图片数据到: \(jpegURL.path)")
            
            try videoData.write(to: mp4URL)
            print("成功写入视频据到: \(mp4URL.path)")
            
            // 将 MP4 转换为 MOV
            let asset = AVAsset(url: mp4URL)
            
            Task { @MainActor in
                do {
                    let exportResult = try await convertVideoToMOV(asset: asset, outputURL: movURL)
                    
                    switch exportResult.status {
                    case .completed:
                        print("视频转换成功，输出文件：\(exportResult.outputURL.path)")
                        self.saveLivePhoto(imageURL: jpegURL, videoURL: exportResult.outputURL, creationDate: creationDate, modificationDate: modificationDate)
                    case .failed:
                        if let error = exportResult.error {
                            showAlert(message: "视频转换失败: \(error.localizedDescription)")
                            print("错误详情: \(error)")
                        } else {
                            showAlert(message: "视频转换失败，但没有错误信息")
                        }
                    case .cancelled:
                        showAlert(message: "视频转换被取消")
                    default:
                        showAlert(message: "视频转换出未知状态: \(exportResult.status.rawValue)")
                    }
                    
                    // 清理临时文件
                    try FileManager.default.removeItem(at: jpegURL)
                    try FileManager.default.removeItem(at: mp4URL)
                    print("成功删除临时文件")
                } catch {
                    showAlert(message: "处理视频时出错: \(error.localizedDescription)")
                }
            }
        } catch {
            showAlert(message: "建 Live Photo 文件时出错: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func convertVideoToMOV(asset: AVAsset, outputURL: URL) async throws -> ExportResult {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw NSError(domain: "AVAssetExportSession", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        await exportSession.export()
        
        return ExportResult(status: exportSession.status, error: exportSession.error, outputURL: outputURL)
    }
    
    @MainActor
    func saveLivePhoto(imageURL: URL, videoURL: URL, creationDate: Date?, modificationDate: Date?) {
        isProcessing = true
        print("开始保存 Live Photo")

        // 生成唯一的标识符
        let assetIdentifier = UUID().uuidString
        print("生成的资产标识符: \(assetIdentifier)")

        // 处理图像
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            showAlert(message: "无法创建图像源")
            isProcessing = false
            return
        }

        let imageData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(imageData, UTType.jpeg.identifier as CFString, 1, nil) else {
            showAlert(message: "无法创建图像目标")
            isProcessing = false
            return
        }

        guard var mutableImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            showAlert(message: "无法获取图像属性")
            isProcessing = false
            return
        }

        // 添加 Live Photo 必要的元数据
        if var makerAppleDict = mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] {
            makerAppleDict["17"] = assetIdentifier
            mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerAppleDict
        } else {
            mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] = ["17": assetIdentifier]
        }

        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, mutableImageProperties as CFDictionary)
        CGImageDestinationFinalize(imageDestination)

        // 处理视频
        let avAsset = AVAsset(url: videoURL)

        Task {
            do {
                let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough)
                guard let exporter = exportSession else {
                    await MainActor.run {
                        showAlert(message: "无法创建视频导出会话")
                        isProcessing = false
                    }
                    return
                }

                let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
                exporter.outputURL = exportURL
                exporter.outputFileType = .mov

                let originalMetadata = try await avAsset.load(.metadata)
                let livePhotoMetadata: [AVMetadataItem] = [
                    {
                        let item = AVMutableMetadataItem()
                        item.key = "com.apple.quicktime.content.identifier" as NSString
                        item.keySpace = AVMetadataKeySpace.quickTimeMetadata
                        item.value = assetIdentifier as NSString
                        item.dataType = "com.apple.metadata.datatype.UTF-8"
                        return item
                    }(),
                    {
                        let item = AVMutableMetadataItem()
                        item.key = "com.apple.quicktime.still-image-time" as NSString
                        item.keySpace = AVMetadataKeySpace(rawValue: "mdta")
                        item.value = self.stillImageTime as NSNumber
                        item.dataType = "com.apple.metadata.datatype.int8"
                        return item
                    }()
                ]
                exporter.metadata = originalMetadata + livePhotoMetadata

                await exporter.export()

                await MainActor.run {
                    if exporter.status == .completed {
                        print("视频导出成功")
                        self.performLivePhotoSave(imageData: imageData as Data, videoURL: exportURL, creationDate: creationDate, modificationDate: modificationDate)
                    } else {
                        showAlert(message: "视频导出失败: \(exporter.error?.localizedDescription ?? "未知错误")")
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    showAlert(message: "处理视频元数据时出: \(error.localizedDescription)")
                    isProcessing = false
                }
            }
        }
    }

    func performLivePhotoSave(imageData: Data, videoURL: URL, creationDate: Date?, modificationDate: Date?) {
        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
            creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
            
            if let creationDate = creationDate {
                creationRequest.creationDate = creationDate
            }
            
            // 设置修改日期
            if let modificationDate = modificationDate {
                creationRequest.creationDate = modificationDate // 使用 creationDate 来设置修改日期
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                if success {
                    print("Live Photo 保存成功")
                    self.showAlert(message: "Live Photo 已成功保存相册")
                } else {
                    print("保存 Live Photo 时出错: \(error?.localizedDescription ?? "未知错误")")
                    self.showAlert(message: "保存 Live Photo 时出错: \(error?.localizedDescription ?? "未知错误")")
                }
                
                // 清理临时文件
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
    }

    @MainActor
    func showAlert(message: String) {
        self.alertMessage = message
        self.showAlert = true
    }

    struct ExportResult {
        let status: AVAssetExportSession.Status
        let error: Error?
        let outputURL: URL
    }

    func calculateStillImageTime(videoDuration: Double, photoTime: Double, frameRate: Double) -> Int {
        // 计算视频总帧数
        let totalFrames = Int(videoDuration * frameRate)
        
        // 计算照片所在的帧数
        let photoFrame = Int(photoTime * frameRate)
        
        // 确保 photoFrame 不超过总帧数
        let clampedPhotoFrame = min(max(photoFrame, 0), totalFrames - 1)
        
        // 计算比例
        let ratio = Double(clampedPhotoFrame) / Double(totalFrames - 1)
        
        // 将比例转换为 0-255 范围的整数
        let stillImageTime = Int(round(ratio * 255))
        
        // 确保结果在 0-255 范围内
        return min(max(stillImageTime, 0), 255)
    }

    func exportAsGIF() {
        isExportingGIF = true
        isProcessing = true
        
        guard let videoData = videoData else {
            showAlert(message: "无法获取视频数据")
            isProcessing = false
            return
        }
        
        let tempVideoURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
        do {
            try videoData.write(to: tempVideoURL)
            
            let asset = AVAsset(url: tempVideoURL)
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    let durationSeconds = CMTimeGetSeconds(duration)
                    
                    let gifURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.gif")
                    
                    try await createGIF(from: asset, duration: durationSeconds, outputURL: gifURL)
                    await MainActor.run {
                        isProcessing = false
                        isExportingGIF = false
                        Task {
                            await saveGIFToPhotos(gifURL: gifURL)
                        }
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        isExportingGIF = false
                        showAlert(message: "创建 GIF 失败: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            isProcessing = false
            isExportingGIF = false
            showAlert(message: "处理视频数据失败: \(error.localizedDescription)")
        }
    }
    
    func createGIF(from asset: AVAsset, duration: Double, outputURL: URL) async throws {
        let frameCount = 30 // 可以调整这个值来改变 GIF 的帧数
        let frameInterval = duration / Double(frameCount)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let destProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, kUTTypeGIF, frameCount, nil) else {
            throw NSError(domain: "GIFCreationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法创建 GIF 目标"])
        }
        
        CGImageDestinationSetProperties(destination, destProperties as CFDictionary)
        
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            
            let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameInterval]]
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "GIFCreationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法完成 GIF 创建"])
        }
    }
    
    @MainActor
    func saveGIFToPhotos(gifURL: URL) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: gifURL, options: nil)
            }
            await showAlert(message: "GIF 已成功保存到相册")
        } catch {
            await showAlert(message: "保存 GIF 失败: \(error.localizedDescription)")
        }
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: gifURL)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    let onImagePicked: (URL, Bool) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            let supportedTypes = [UTType.jpeg.identifier, UTType.heic.identifier]
            
            for type in supportedTypes {
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                        if let error = error {
                            print("Error loading file: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let url = url else {
                            print("No URL returned")
                            return
                        }
                        
                        // 创建一个临时文件来保存选中的图片
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            
                            // 检查是否为 Motion Photo
                            let isMotionPhoto = self.isMotionPhoto(url: tempURL)
                            
                            DispatchQueue.main.async {
                                self.parent.onImagePicked(tempURL, isMotionPhoto)
                            }
                        } catch {
                            print("Error copying file: \(error.localizedDescription)")
                        }
                    }
                    return
                }
            }
            
            // 如果没有匹配到支持的类型
            DispatchQueue.main.async {
                self.parent.onImagePicked(URL(fileURLWithPath: ""), false)
            }
        }
        
        func isMotionPhoto(url: URL) -> Bool {
            guard let data = try? Data(contentsOf: url) else {
                return false
            }
            
            let supportedExtensions = ["jpg", "jpeg", "heic", "avif"]
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                return false
            }
            
            if let xmpData = extractXMPData(from: data),
               let xmpInfo = parseXMP(data: xmpData) {
                if xmpInfo["GCamera:MicroVideoOffset"] != nil || xmpInfo["GContainer:ItemLength"] != nil {
                    return true
                }
            }
            
            return false
        }
    }
}

struct PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        return PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 不需要在这里更新，为我们使用了自定义的 UIView
    }
}

class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    
    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

func extractXMPData(from data: Data) -> Data? {
    guard let xmpStartRange = data.range(of: Data("<x:xmpmeta".utf8), options: .backwards),
          let xmpEndRange = data.range(of: Data("</x:xmpmeta>".utf8), options: .backwards) else {
        return nil
    }
    return data[xmpStartRange.lowerBound...xmpEndRange.upperBound]
}

func parseXMP(data: Data) -> [String: String]? {
    let parser = XMLParser(data: data)
    let delegate = XMPParserDelegate()
    parser.delegate = delegate
    
    if parser.parse() {
        return delegate.parsedData
    } else {
        print("XML 解析错误: \(parser.parserError?.localizedDescription ?? "未知错误")")
        return nil
    }
}

class XMPParserDelegate: NSObject, XMLParserDelegate {
    var parsedData = [String: String]()
    var currentElement = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        for (key, value) in attributeDict {
            if key.contains("MicroVideoOffset") || key.contains("ItemLength") || key.contains("PresentationTimestampUs") {
                parsedData[key] = value
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedString.isEmpty {
            parsedData[currentElement] = trimmedString
        }
    }
}

