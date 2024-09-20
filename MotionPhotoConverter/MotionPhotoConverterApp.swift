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

@main
struct MotionPhotoConverterApp: App {
    var body: some Scene {
        WindowGroup {
            MotionPhotoView()
        }
    }
}

struct MotionPhotoView: View {
    @State private var selectedImage: UIImage?
    @State private var videoPlayer: AVPlayer?
    @State private var isPlayingVideo = false
    @State private var originalImageData: Data?
    @State private var videoData: Data?
    @State private var sourceURL: URL?
    @State private var isShowingPhotoPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 300)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        
                        if let player = videoPlayer {
                            PlayerView(player: player)
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 300)
                                .cornerRadius(12)
                                .opacity(isPlayingVideo ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: isPlayingVideo)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startVideoPlayback() }
                            .onEnded { _ in stopVideoPlayback() }
                    )
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .foregroundColor(.gray)
                }
                
                Button(action: { isShowingPhotoPicker = true }) {
                    Label("选择 Motion Photo", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                if selectedImage != nil {
                    Button(action: exportAsLivePhoto) {
                        Label("导出为 Live Photo", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(originalImageData == nil || videoData == nil)
                }
                
                if isProcessing {
                    ProgressView("正在处理...")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Motion Photo 转换器")
            .sheet(isPresented: $isShowingPhotoPicker) {
                PhotoPicker(onImagePicked: { url in
                    self.extractVideoFromMotionPhoto(url: url)
                })
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
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
    
    func extractVideoFromMotionPhoto(url: URL) {
        self.sourceURL = url  // 保存源文件 URL
        
        guard let data = try? Data(contentsOf: url) else {
            showAlert(message: "无法读取文件")
            return
        }
        
        // 查找 XMP 元数据
        guard let xmpRange = data.range(of: Data("<x:xmpmeta".utf8), options: .backwards),
              let xmpEndRange = data.range(of: Data("</x:xmpmeta>".utf8), options: .backwards) else {
            showAlert(message: "这不是一个有效的 Motion Photo")
            return
        }
        
        let xmpData = data[xmpRange.lowerBound..<xmpEndRange.upperBound]
        let xmpString = String(data: xmpData, encoding: .utf8) ?? ""
        
        // 查找 MicroVideoOffset
        guard let offsetRange = xmpString.range(of: "GCamera:MicroVideoOffset=\""),
              let endRange = xmpString[offsetRange.upperBound...].firstIndex(of: "\"") else {
            showAlert(message: "这不是一个有效的 Motion Photo")
            return
        }
        
        let offsetString = xmpString[offsetRange.upperBound..<endRange]
        guard let offset = Int(offsetString) else {
            showAlert(message: "无法解析 Motion Photo 数据")
            return
        }
        
        // 提取视据
        self.videoData = data.suffix(offset)
        
        // 处理图像
        self.selectedImage = UIImage(contentsOfFile: url.path)
        
        self.originalImageData = data
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
        do {
            try videoData?.write(to: tempURL)
            self.videoPlayer = AVPlayer(url: tempURL)
            self.videoPlayer?.actionAtItemEnd = .none
            
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.videoPlayer?.currentItem, queue: .main) { notification in
                self.videoPlayer?.seek(to: .zero)
                self.videoPlayer?.play()
            }
        } catch {
            showAlert(message: "保存视频文件时出错: \(error)")
        }
    }
    
    @MainActor
    func exportAsLivePhoto() {
        guard let imageData = originalImageData, let videoData = videoData, let sourceURL = sourceURL else {
            showAlert(message: "缺少必要数据")
            return
        }
        
        print("开始导出 Live Photo")
        print("原始图片数据大小: \(imageData.count) bytes")
        print("原始视频数据大小: \(videoData.count) bytes")
        print("源文件 URL: \(sourceURL.path)")

        let sourceFileName = sourceURL.deletingPathExtension().lastPathComponent
        let uniqueID = UUID().uuidString
        let jpegURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).jpg")
        let heicURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).heic")
        let mp4URL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).mp4")
        let movURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).mov")
        
        do {
            // 获取源文件的创建日期和修改日期
            let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            let creationDate = attributes[.creationDate] as? Date
            let modificationDate = attributes[.modificationDate] as? Date
            
            try imageData.write(to: jpegURL)
            print("成功写入 JPEG 图片数据到: \(jpegURL.path)")
            
            // 将 JPEG 转换为 HEIC
            if let heicData = convertJPEGToHEIC(jpegURL: jpegURL) {
                try heicData.write(to: heicURL)
                print("成功转换并写入 HEIC 图片数据到: \(heicURL.path)")
            } else {
                throw NSError(domain: "HEICConversionError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法将 JPEG 转换为 HEIC"])
            }
            
            try videoData.write(to: mp4URL)
            print("成功写入视频数据到: \(mp4URL.path)")
            
            // 将 MP4 转换为 MOV
            let asset = AVAsset(url: mp4URL)
            
            Task { @MainActor in
                do {
                    let exportResult = try await convertVideoToMOV(asset: asset, outputURL: movURL)
                    
                    switch exportResult.status {
                    case .completed:
                        print("视频转换成功，输出文件：\(exportResult.outputURL.path)")
                        self.saveLivePhoto(imageURL: heicURL, videoURL: exportResult.outputURL, creationDate: creationDate, modificationDate: modificationDate)
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
                        showAlert(message: "视频转换出现未知状态: \(exportResult.status.rawValue)")
                    }
                    
                    // 清理临时文件
                    try FileManager.default.removeItem(at: jpegURL)
                    try FileManager.default.removeItem(at: heicURL)
                    try FileManager.default.removeItem(at: mp4URL)
                    print("成功删除临时文件")
                } catch {
                    showAlert(message: "处理视频时出错: \(error.localizedDescription)")
                }
            }
        } catch {
            showAlert(message: "创建 Live Photo 文件时出错: \(error.localizedDescription)")
        }
    }
    
    func convertJPEGToHEIC(jpegURL: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(jpegURL as CFURL, nil) else {
            print("无法创建图片源")
            return nil
        }
        
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, AVFileType.heic as CFString, 1, nil) else {
            print("无法创建 HEIC 目标")
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8,
            kCGImageDestinationBackgroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ]
        
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            print("无法完成 HEIC 转换")
            return nil
        }
        
        return data as Data
    }
    
    // 在 saveLivePhoto 函数中添加更多日志
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
        guard let imageDestination = CGImageDestinationCreateWithData(imageData, UTType.heic.identifier as CFString, 1, nil) else {
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

        Task { @MainActor in
            do {
                let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough)
                guard let exporter = exportSession else {
                    showAlert(message: "无法创建视频导出会话")
                    isProcessing = false
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
                        return item
                    }(),
                    {
                        let item = AVMutableMetadataItem()
                        item.key = "com.apple.quicktime.live-photo.still-image-time" as NSString
                        item.keySpace = AVMetadataKeySpace.quickTimeMetadata
                        item.value = 0 as NSNumber
                        return item
                    }(),
                    {
                        let item = AVMutableMetadataItem()
                        item.key = "com.apple.quicktime.still-image-time" as NSString
                        item.keySpace = AVMetadataKeySpace.quickTimeMetadata
                        item.value = 0 as NSNumber
                        return item
                    }()
                ]
                exporter.metadata = originalMetadata + livePhotoMetadata

                await exporter.export()

                if exporter.status == .completed {
                    print("视频导出成功")
                    self.performLivePhotoSave(imageData: imageData as Data, videoURL: exportURL, creationDate: creationDate, modificationDate: modificationDate)
                } else {
                    showAlert(message: "视频导出失败: \(exporter.error?.localizedDescription ?? "未知错误")")
                    isProcessing = false
                }
            } catch {
                showAlert(message: "处理视频元数据时出错: \(error.localizedDescription)")
                isProcessing = false
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
            
            if let location = self.getLocationFromImageMetadata(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_image.heic")) {
                creationRequest.location = location
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                if success {
                    print("Live Photo 保存成功")
                    self.showAlert(message: "Live Photo 已成功保存到相册")
                    
                    // 如果需要设置修改日期，可以在这里添加额外的代码
                    if let modificationDate = modificationDate {
                        self.updateAssetModificationDate(modificationDate: modificationDate)
                    }
                } else {
                    print("保存 Live Photo 时出错: \(error?.localizedDescription ?? "未知错误")")
                    self.showAlert(message: "保存 Live Photo 时出错: \(error?.localizedDescription ?? "未知错误")")
                }
                
                // 清理临时文件
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
    }

    // 修改 updateAssetModificationDate 方法
    func updateAssetModificationDate(modificationDate: Date) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        if let lastAsset = fetchResult.firstObject {
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: lastAsset)
                let contentEditingOutput = PHContentEditingOutput()
                contentEditingOutput.adjustmentData = PHAdjustmentData(formatIdentifier: "com.yourapp.livePhoto",
                                                                       formatVersion: "1.0",
                                                                       data: try! JSONEncoder().encode(["modificationDate": modificationDate]))
                request.contentEditingOutput = contentEditingOutput
            } completionHandler: { success, error in
                if success {
                    print("成功更新资产的修改日期")
                } else {
                    print("更新资产修改日期时出错: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }

    // 在 getLocationFromImageMetadata 函数中添加日志
    func getLocationFromImageMetadata(url: URL) -> CLLocation? {
        print("开始从图片元数据获取位置信息")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("无法创建图片源")
            return nil
        }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            print("无法获取图片元数据")
            return nil
        }
        guard let gpsInfo = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            print("无法获取 GPS 信息")
            return nil
        }
        
        guard let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double else {
            print("无法获取经纬度信息")
            return nil
        }
        
        let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
        let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
        
        let lat = latitudeRef == "N" ? latitude : -latitude
        let lon = longitudeRef == "E" ? longitude : -longitude
        
        print("成功获取位置信息: 纬度 \(lat), 经度 \(lon)")
        return CLLocation(latitude: lat, longitude: lon)
    }

    func showAlert(message: String) {
        self.alertMessage = message
        self.showAlert = true
    }

    struct ExportResult {
        let status: AVAssetExportSession.Status
        let error: Error?
        let outputURL: URL
    }

    @MainActor
func convertVideoToMOV(asset: AVAsset, outputURL: URL) async throws -> ExportResult {
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
        throw NSError(domain: "AVAssetExportSession", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mov
    
    return await withCheckedContinuation { continuation in
        exportSession.exportAsynchronously {
            let result = ExportResult(status: exportSession.status, error: exportSession.error, outputURL: outputURL)
            continuation.resume(returning: result)
        }
    }
}
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    let onImagePicked: (URL) -> Void
    
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
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.jpeg.identifier) { url, error in
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
                        DispatchQueue.main.async {
                            self.parent.onImagePicked(tempURL)
                        }
                    } catch {
                        print("Error copying file: \(error.localizedDescription)")
                    }
                }
            }
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
