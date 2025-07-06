//
//  MotionPhotoConverterApp.swift
//  MotionPhotoConverter
//
//  Created by larry.shen on 2024/9/14.
//

import SwiftUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers
import Photos
import CoreServices
import CoreLocation
import PhotosUI
import ImageIO
import Foundation

// MARK: - Export Options Panel
struct ExportOptionsView: View {
    let fileName: String
    let fileSize: Int64
    let creationDate: Date?
    let videoDuration: Double
    let onExportVideo: () -> Void
    let onExportLivePhoto: () -> Void
    let onExportGIF: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    private var videoDurationString: String {
        String(format: "%.1fs", videoDuration)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // File information section
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("File Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("File Name:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(fileName)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("File Size:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(fileSizeString)
                                        .fontWeight(.medium)
                                }
                                
                                if let date = creationDate {
                                    HStack {
                                        Text("Creation Date:")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(date, style: .date)
                                            .fontWeight(.medium)
                                    }
                                }
                                
                                HStack {
                                    Text("Video Duration:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(videoDurationString)
                                        .fontWeight(.medium)
                                }
                            }
                            .font(.subheadline)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Divider()
                    .padding(.vertical, 20)
                
                // Export options section
                VStack(spacing: 0) {
                    Text("Choose Export Format")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.bottom, 16)
                    
                    VStack(spacing: 12) {
                        ExportOptionRow(
                            icon: "video.fill",
                            title: "Save as Video",
                            subtitle: "Export as MP4 video file",
                            action: {
                                dismiss()
                                onExportVideo()
                            }
                        )
                        
                        ExportOptionRow(
                            icon: "livephoto",
                            title: "Save as Live Photo",
                            subtitle: "Export as iOS Live Photo",
                            action: {
                                dismiss()
                                onExportLivePhoto()
                            }
                        )
                        
                        ExportOptionRow(
                            icon: "gift.fill",
                            title: "Save as GIF",
                            subtitle: "Export as animated GIF",
                            action: {
                                dismiss()
                                onExportGIF()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export Option Row
struct ExportOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@main
struct MotionPhotoConverterApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}


// Playback guide hint view
struct PlaybackHintView: View {
    let onDismiss: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Dynamic Live Photo icon
            Image(systemName: "livephoto.play")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Text hint
            Text("Hold to Play")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .onAppear {
            isAnimating = true
        }
        .onTapGesture {
            onDismiss()
        }
    }
}

// Add VideoPlayerObserver class definition at the top of the file
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
    @State var sourceURL: URL  // Make sourceURL a mutable property
    
    @State private var selectedImage: UIImage?
    @State private var videoPlayer: AVPlayer?
    @State private var isPlayingVideo = false
    @State private var originalImageData: Data?
    @State private var videoData: Data?
    @State private var isShowingPhotoPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    @State private var stillImageTime: Int = 0
    @State private var microVideoOffset: Int?
    @Environment(\.colorScheme) var colorScheme
    @State private var isExportingGIF = false
    @State private var isExportMenuPresented = false
    @State private var creationDate: Date?
    @StateObject private var videoPlayerObserver = VideoPlayerObserver()
    @State private var imageSize: CGSize = .zero
    @State private var videoDuration: Double = 0
    @State private var fileSize: Int64 = 0
    
    // User guidance related states
    @State private var showPlaybackHint = false
    @State private var hasUserPlayedVideo = UserDefaults.standard.bool(forKey: "hasUserPlayedMotionPhoto")
    
    // Haptic feedback generator
    private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let softImpactFeedback = UIImpactFeedbackGenerator(style: .soft)
    
    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        _selectedImage = State(initialValue: UIImage(contentsOfFile: sourceURL.path))
    }
    
    var body: some View {
        ZStack {
            // Main content area
            VStack(spacing: 0) {
                if let image = selectedImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                        
                        if let player = videoPlayer {
                            PlayerView(player: player)
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(isPlayingVideo ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: isPlayingVideo)
                                .clipped()
                        }
                        
                        // First-time use guidance hint
                        if showPlaybackHint {
                            PlaybackHintView {
                                hidePlaybackHint()
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startVideoPlaybackWithFeedback() }
                            .onEnded { _ in stopVideoPlaybackWithFeedback() }
                    )
                } else {
                    Text(Localizable.string(.pleaseSelectMotionPhoto))
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            
            // Bottom center floating share button
            VStack {
                Spacer()
                
                Button(action: { isExportMenuPresented = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(selectedImage == nil)
                .padding(.bottom, 34) // Adapt to bottom safe area
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.blue)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isShowingPhotoPicker = true
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $isExportMenuPresented) {
            ExportOptionsView(
                fileName: sourceURL.lastPathComponent,
                fileSize: fileSize,
                creationDate: creationDate,
                videoDuration: videoDuration,
                onExportVideo: { exportVideo() },
                onExportLivePhoto: { exportAsLivePhoto() },
                onExportGIF: { exportAsGIF() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(onImagePicked: { url, isMotionPhoto in
                Task {
                    if isMotionPhoto {
                        await self.extractVideoFromMotionPhoto(url: url)
                    } else {
                        await MainActor.run {
                            self.showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                        }
                    }
                }
            }, onNonMotionPhotoSelected: {
                self.showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
            }, onCancelled: {
                // User cancelled selection, no alert needed
            })
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(Localizable.string(.tip)), message: Text(alertMessage), dismissButton: .default(Text(Localizable.string(.ok))))
        }
        .onAppear {
            Task {
                await extractVideoFromMotionPhoto(url: sourceURL)
                
                // Check if first-time use guidance should be shown
                await MainActor.run {
                    if !hasUserPlayedVideo && selectedImage != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPlaybackHint = true
                            }
                        }
                    }
                }
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
    
    func startVideoPlaybackWithFeedback() {
        // Trigger light haptic feedback
        lightImpactFeedback.impactOccurred()
        
        // If first playback, hide guidance hint and record state
        if showPlaybackHint {
            hidePlaybackHint()
        }
        
        startVideoPlayback()
    }
    
    func stopVideoPlaybackWithFeedback() {
        // Trigger softer haptic feedback
        softImpactFeedback.impactOccurred()
        
        stopVideoPlayback()
    }
    
    func hidePlaybackHint() {
        withAnimation(.easeOut(duration: 0.3)) {
            showPlaybackHint = false
        }
        
        // Record that user has learned playback operation
        if !hasUserPlayedVideo {
            hasUserPlayedVideo = true
            UserDefaults.standard.set(true, forKey: "hasUserPlayedMotionPhoto")
        }
    }
    
    func extractVideoFromMotionPhoto(url: URL) async {
        print("Starting to process file: \(url.path)")
        
        guard let data = try? Data(contentsOf: url) else {
            await MainActor.run {
                print("Cannot read file: \(url.path)")
                showAlert(message: Localizable.string(.cannotReadFile))
            }
            return
        }
        
        print("File size: \(data.count) bytes")
        
        // Get file size
        await MainActor.run {
            self.fileSize = Int64(data.count)
        }
        
        // Try to extract and parse XMP data
        guard let xmpData = extractXMPData(from: data),
              let xmpInfo = parseXMP(data: xmpData) else {
            await MainActor.run {
                print("Cannot extract or parse XMP data")
                showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
            }
            return
        }
        
        print("XMPInfo: \(xmpInfo)")
        
        // Use new processor architecture
        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo) else {
            await MainActor.run {
                print("Unsupported motion photo format")
                showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
            }
            return
        }
        
        print("Detected \(processor.brand.displayName) motion photo")
        
        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        
        guard result.success, let motionPhotoData = result.data else {
            await MainActor.run {
                print("Failed to process motion photo: \(result.errorMessage ?? "Unknown error")")
                showAlert(message: result.errorMessage ?? Localizable.string(.selectedPhotoIsNotMotionPhoto))
            }
            return
        }
        
        // Update state variables
        self.originalImageData = motionPhotoData.imageData
        self.videoData = motionPhotoData.videoData
        self.microVideoOffset = motionPhotoData.videoOffset
        
        print("Extracted video data size: \(motionPhotoData.videoData.count) bytes")
        print("Extracted image data size: \(motionPhotoData.imageData.count) bytes")
        
        // Set image
        self.selectedImage = UIImage(data: motionPhotoData.imageData)
        
        // Process video
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
        do {
            try motionPhotoData.videoData.write(to: tempURL)
            let asset = AVAsset(url: tempURL)
            
            // Get video duration and frame rate
            let duration = try await asset.load(.duration)
            let videoDuration = CMTimeGetSeconds(duration)
            
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let frameRate = try await tracks.first?.load(.nominalFrameRate) ?? 30.0
            
            // Use processor to calculate stillImageTime
            self.stillImageTime = processor.calculateStillImageTime(
                videoDuration: videoDuration,
                presentationTimestamp: motionPhotoData.presentationTimestamp,
                frameRate: Double(frameRate)
            )
            
            print("Video duration: \(videoDuration) seconds")
            print("Video frame rate: \(frameRate) fps")
            if let timestamp = motionPhotoData.presentationTimestamp {
                print("Photo timestamp: \(timestamp) microseconds")
            }
            print("Calculated stillImageTime: \(self.stillImageTime)")
            
            // Save video duration
            self.videoDuration = videoDuration
            
            await MainActor.run {
                self.videoPlayer = AVPlayer(url: tempURL)
                self.videoPlayer?.actionAtItemEnd = .none
                
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.videoPlayer?.currentItem, queue: .main) { notification in
                    self.videoPlayer?.seek(to: .zero)
                    self.videoPlayer?.play()
                }
                
                // Set video player observer
                videoPlayerObserver.player = self.videoPlayer
            }
        } catch {
            print("Error processing video file: \(error)")
            print("Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error user info: \(nsError.userInfo)")
            }
            await MainActor.run {
                showAlert(message: Localizable.string(.errorProcessingVideoFile))
            }
        }
        
        // Get creation date
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let creationDate = attributes[.creationDate] as? Date {
            await MainActor.run {
                self.creationDate = creationDate
            }
        }
    }
    
    private func exportVideo() {
        guard let videoData = videoData else {
            showAlert(message: Localizable.string(.cannotGetVideoData))
            return
        }
        
        isProcessing = true
        
        let tempVideoURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
        do {
            try videoData.write(to: tempVideoURL)
            
            let asset = AVAsset(url: tempVideoURL)
            
            // Create export session
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                showAlert(message: Localizable.string(.cannotCreateExportSession))
                isProcessing = false
                return
            }
            
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("exported_video.mp4")
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    
                    switch exportSession.status {
                    case .completed:
                        self.saveVideoToPhotos(outputURL)
                    case .failed:
                        self.showAlert(message: Localizable.string(.videoExportFailed) + ": \(exportSession.error?.localizedDescription ?? Localizable.string(.unknownError))")
                    case .cancelled:
                        self.showAlert(message: Localizable.string(.videoExportCancelled))
                    default:
                        self.showAlert(message: Localizable.string(.videoExportUnknownError))
                    }
                    
                    // Clean up temporary files
                    try? FileManager.default.removeItem(at: tempVideoURL)
                }
            }
        } catch {
            isProcessing = false
            showAlert(message: Localizable.string(.failedToProcessVideoData) + ": \(error.localizedDescription)")
        }
    }
    
    private func saveVideoToPhotos(_ videoURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.showAlert(message: Localizable.string(.videoSaved))
                } else {
                    self.showAlert(message: Localizable.string(.savingVideoFailed) + ": \(error?.localizedDescription ?? Localizable.string(.unknownError))")
                }
                
                // Clean up exported video file
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
    }
    
    @MainActor
    func exportAsLivePhoto() {
        guard let imageData = originalImageData, let videoData = videoData else {
            showAlert(message: Localizable.string(.missingData))
            return
        }
        
        print("Starting to export Live Photo")
        print("Original data size: \(imageData.count) bytes")
        print("Video data size: \(videoData.count) bytes")
        print("Source file URL: \(sourceURL.path)")

        let sourceFileName = sourceURL.deletingPathExtension().lastPathComponent
        let uniqueID = UUID().uuidString
        let jpegURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).jpg")
        let mp4URL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).mp4")
        let movURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceFileName)-\(uniqueID).mov")
        
        do {
            // Get source file creation and modification dates
            let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            let creationDate = attributes[.creationDate] as? Date
            let modificationDate = attributes[.modificationDate] as? Date
            
            // Use processed pure image data
            // In the new architecture, originalImageData is already pure image data without video part
            let pureImageData = imageData
            
            // Write pure image data to JPEG file
            try pureImageData.write(to: jpegURL)
            print("Successfully wrote pure JPEG image data to: \(jpegURL.path)")
            
            try videoData.write(to: mp4URL)
            print("Successfully wrote video data to: \(mp4URL.path)")
            
            // Convert MP4 to MOV
            let asset = AVAsset(url: mp4URL)
            
            Task { @MainActor in
                do {
                    let exportResult = try await convertVideoToMOV(asset: asset, outputURL: movURL)
                    
                    switch exportResult.status {
                    case .completed:
                        print("Video conversion successful, output file: \(exportResult.outputURL.path)")
                        self.saveLivePhoto(imageURL: jpegURL, videoURL: exportResult.outputURL, creationDate: creationDate, modificationDate: modificationDate)
                    case .failed:
                        if let error = exportResult.error {
                            showAlert(message: Localizable.string(.videoConversionFailed) + ": \(error.localizedDescription)")
                            print("Error details: \(error)")
                        } else {
                            showAlert(message: Localizable.string(.videoConversionFailedNoErrorInfo))
                        }
                    case .cancelled:
                        showAlert(message: Localizable.string(.videoConversionCancelled))
                    default:
                        showAlert(message: Localizable.string(.videoConversionUnknownStatus) + ": \(exportResult.status.rawValue)")
                    }
                    
                    // Clean up temporary files
                    try FileManager.default.removeItem(at: jpegURL)
                    try FileManager.default.removeItem(at: mp4URL)
                    print("Successfully deleted temporary files")
                } catch {
                    showAlert(message: Localizable.string(.errorProcessingVideoFile) + ": \(error.localizedDescription)")
                }
            }
        } catch {
            showAlert(message: Localizable.string(.errorCreatingLivePhotoFile) + ": \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func convertVideoToMOV(asset: AVAsset, outputURL: URL) async throws -> ExportResult {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw NSError(domain: "AVAssetExportSession", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.cannotCreateExportSession)])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        await exportSession.export()
        
        return ExportResult(status: exportSession.status, error: exportSession.error, outputURL: outputURL)
    }
    
    @MainActor
    func saveLivePhoto(imageURL: URL, videoURL: URL, creationDate: Date?, modificationDate: Date?) {
        isProcessing = true
        print("Starting to save Live Photo")

        // Generate unique identifier
        let assetIdentifier = UUID().uuidString
        print("Generated asset identifier: \(assetIdentifier)")

        // Process image
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            showAlert(message: Localizable.string(.cannotCreateImageSource))
            isProcessing = false
            return
        }

        let imageData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(imageData, UTType.jpeg.identifier as CFString, 1, nil) else {
            showAlert(message: Localizable.string(.cannotCreateImageDestination))
            isProcessing = false
            return
        }

        guard var mutableImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            showAlert(message: Localizable.string(.cannotGetImageProperties))
            isProcessing = false
            return
        }

        // Add necessary Live Photo metadata
        if var makerAppleDict = mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] {
            makerAppleDict["17"] = assetIdentifier
            mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerAppleDict
        } else {
            mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] = ["17": assetIdentifier]
        }

        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, mutableImageProperties as CFDictionary)
        CGImageDestinationFinalize(imageDestination)

        // Process video
        let avAsset = AVAsset(url: videoURL)

        Task {
            do {
                let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough)
                guard let exporter = exportSession else {
                    await MainActor.run {
                        showAlert(message: Localizable.string(.cannotCreateVideoExportSession))
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
                        print("Video export successful")
                        self.performLivePhotoSave(imageData: imageData as Data, videoURL: exportURL, creationDate: creationDate, modificationDate: modificationDate)
                    } else {
                        showAlert(message: Localizable.string(.videoExportFailed) + ": \(exporter.error?.localizedDescription ?? Localizable.string(.unknownError))")
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    showAlert(message: Localizable.string(.errorProcessingVideoMetadata) + ": \(error.localizedDescription)")
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
            
            // Set modification date
            if let modificationDate = modificationDate {
                creationRequest.creationDate = modificationDate // Use creationDate to set modification date
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                if success {
                    print("Live Photo saved successfully")
                    self.showAlert(message: Localizable.string(.livePhotoSaved))
                } else {
                    print("Error saving Live Photo: \(error?.localizedDescription ?? Localizable.string(.unknownError))")
                    self.showAlert(message: Localizable.string(.savingLivePhotoFailed))
                }
                
                // Clean up temporary files
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



    func exportAsGIF() {
        isExportingGIF = true
        isProcessing = true
        
        guard let videoData = videoData else {
            showAlert(message: Localizable.string(.cannotGetVideoData))
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
                        showAlert(message: Localizable.string(.failedToCreateGIF) + ": \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            isProcessing = false
            isExportingGIF = false
            showAlert(message: Localizable.string(.failedToProcessVideoData) + ": \(error.localizedDescription)")
        }
    }
    
    func createGIF(from asset: AVAsset, duration: Double, outputURL: URL) async throws {
        let frameCount = 30 // Can adjust this value to change GIF frame count
        let frameInterval = duration / Double(frameCount)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let destProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            throw NSError(domain: "GIFCreationError", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.cannotCreateGIFDestination)])
        }
        
        CGImageDestinationSetProperties(destination, destProperties as CFDictionary)
        
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            
            let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameInterval]]
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "GIFCreationError", code: 1, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.cannotFinalizeGIFCreation)])
        }
    }
    
    @MainActor
    func saveGIFToPhotos(gifURL: URL) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: gifURL, options: nil)
            }
            showAlert(message: Localizable.string(.gifSavedToPhotos))
        } catch {
            showAlert(message: Localizable.string(.failedToSaveGIF) + ": \(error.localizedDescription)")
        }
        
        // Clean up temporary files
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
    let onNonMotionPhotoSelected: () -> Void
    let onCancelled: (() -> Void)?  // Callback for user cancellation
    
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
            
            guard let provider = results.first?.itemProvider else { 
                DispatchQueue.main.async {
                    self.parent.onCancelled?()
                }
                return 
            }
            
            let supportedTypes = [UTType.jpeg.identifier, UTType.heic.identifier]
            
            for type in supportedTypes {
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                        if let error = error {
                            print("Error loading file: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.parent.onNonMotionPhotoSelected()
                            }
                            return
                        }
                        
                        guard let url = url else {
                            print("No URL returned")
                            DispatchQueue.main.async {
                                self.parent.onNonMotionPhotoSelected()
                            }
                            return
                        }
                        
                        // Create a temporary file to save the selected image
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            
                            // Check if it's a Motion Photo
                            let isMotionPhoto = self.isMotionPhoto(url: tempURL)
                            
                            DispatchQueue.main.async {
                                if isMotionPhoto {
                                    self.parent.onImagePicked(tempURL, isMotionPhoto)
                                } else {
                                    self.parent.onNonMotionPhotoSelected()
                                }
                            }
                        } catch {
                            print("Error copying file: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.parent.onNonMotionPhotoSelected()
                            }
                        }
                    }
                    return
                }
            }
            
            // If no supported type is matched
            DispatchQueue.main.async {
                self.parent.onNonMotionPhotoSelected()
            }
        }
        
        func isMotionPhoto(url: URL) -> Bool {
            guard let data = try? Data(contentsOf: url) else {
                print("Unable to read file data")
                return false
            }
            
            let supportedExtensions = ["jpg", "jpeg", "heic", "avif"]
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                print("Unsupported file extension: \(url.pathExtension)")
                return false
            }
            
            if let xmpData = extractXMPData(from: data),
               let xmpInfo = parseXMP(data: xmpData) {
                print("XMP Info: \(xmpInfo)")
                // Check various Motion Photo identifiers
                if xmpInfo["GCamera:MicroVideoOffset"] != nil || 
                   xmpInfo["GContainer:ItemLength"] != nil || 
                   xmpInfo["GCamera:MotionPhoto"] == "1" ||
                   xmpInfo["Motion Photo"] == "1" ||
                   xmpInfo["Directory Item Length"] != nil {
                    return true
                } else {
                    print("XMP data does not contain required Motion Photo keys")
                    return false
                }
            } else {
                print("Unable to extract or parse XMP data")
                return false
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
        // No need to update here as we use custom UIView
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
    if let xmpStartRange = data.range(of: Data("<x:xmpmeta".utf8)),
       let xmpEndRange = data.range(of: Data("</x:xmpmeta>".utf8), in: xmpStartRange.lowerBound..<data.count) {
        print("Found <x:xmpmeta> tags.")
        // Ensure complete <x:xmpmeta> tag is included
        let fullXMPStart = xmpStartRange.lowerBound
        let fullXMPEnd = xmpEndRange.upperBound
        print("XMP Start: \(fullXMPStart), XMP End: \(fullXMPEnd)")
        return data[fullXMPStart..<fullXMPEnd]
    }

    // Fallback: try to find <?xpacket ... ?> tag (if main search fails)
    if let xpacketStartRange = data.range(of: Data("<?xpacket begin=".utf8)),
       let xpacketEndRange = data.range(of: Data("<?xpacket end=".utf8), in: xpacketStartRange.lowerBound..<data.count) {
        print("Found <?xpacket> tags as fallback.")
        let fullXpacketStart = xpacketStartRange.lowerBound
        let fullXpacketEnd = xpacketEndRange.upperBound
        print("Xpacket Start: \(fullXpacketStart), Xpacket End: \(fullXpacketEnd)")
        return data[fullXpacketStart..<fullXpacketEnd]
    }
    return nil
}

func parseXMP(data: Data) -> [String: String]? {
    // Try to clean data, remove BOM or invalid prefixes
    var cleanedData = data
    if let utf8String = String(data: data, encoding: .utf8) {
        // Try to find the first valid XML tag and extract content after it
        if let range = utf8String.range(of: "<x:") ?? utf8String.range(of: "<?xpacket") {
            let startIndex = range.lowerBound
            cleanedData = Data(utf8String[startIndex...].utf8)
        } else if let range = utf8String.range(of: "<", options: .caseInsensitive) {
            // Fallback: if no specific XMP/xpacket tag, find any opening tag
            let startIndex = range.lowerBound
            cleanedData = Data(utf8String[startIndex...].utf8)
        }
    }

    let parser = XMLParser(data: cleanedData)
    let delegate = XMPParserDelegate()
    parser.delegate = delegate
    
    if parser.parse() {
        return delegate.parsedData
    } else {
        print("XML parsing error: \(parser.parserError?.localizedDescription ?? Localizable.string(.unknownError))")
        print("Parsed XML data was: \(String(data: cleanedData, encoding: .utf8) ?? "Invalid UTF-8")") // Add debug print for cleaned data
        return nil
    }
}

class XMPParserDelegate: NSObject, XMLParserDelegate {
    var parsedData = [String: String]()
    var currentElement = ""
    var itemLengths: [String] = []
    var itemPaddings: [String] = []
    var itemMimes: [String] = []
    var itemSemantics: [String] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        // Process data in attributes
        for (key, value) in attributeDict {
            // Check all possible Motion Photo related fields
            if key.contains("MicroVideoOffset") || 
               key.contains("ItemLength") || 
               key.contains("PresentationTimestampUs") || 
               key.contains("MotionPhoto") ||
               key.contains("MicroVideo") ||
               key.contains("ItemPadding") ||
               key.contains("ItemMime") ||
               key.contains("ItemSemantic") {
                parsedData[key] = value
            }
            
            // Special handling for Container Item attributes
            if key == "Item:Length" {
                itemLengths.append(value)
            } else if key == "Item:Padding" {
                itemPaddings.append(value)
            } else if key == "Item:Mime" {
                itemMimes.append(value)
            } else if key == "Item:Semantic" {
                itemSemantics.append(value)
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedString.isEmpty {
            // Check if current element is a field we care about
            if currentElement.contains("MicroVideoOffset") ||
               currentElement.contains("ItemLength") ||
               currentElement.contains("PresentationTimestampUs") ||
               currentElement.contains("MotionPhoto") ||
               currentElement.contains("MicroVideo") ||
               currentElement.contains("ItemPadding") ||
               currentElement.contains("ItemMime") ||
               currentElement.contains("ItemSemantic") ||
               currentElement == "Motion Photo" ||
               currentElement == "Motion Photo Version" ||
               currentElement == "Motion Photo Presentation Timestamp Us" ||
               currentElement == "Directory Item Length" ||
               currentElement == "Directory Item Padding" ||
               currentElement == "Directory Item Mime" ||
               currentElement == "Directory Item Semantic" {
                parsedData[currentElement] = trimmedString
            }
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        // After parsing, combine collected Item attributes into standard format
        if !itemLengths.isEmpty {
            parsedData["Directory Item Length"] = itemLengths.joined(separator: ", ")
        }
        if !itemPaddings.isEmpty {
            parsedData["Directory Item Padding"] = itemPaddings.joined(separator: ", ")
        }
        if !itemMimes.isEmpty {
            parsedData["Directory Item Mime"] = itemMimes.joined(separator: ", ")
        }
        if !itemSemantics.isEmpty {
            parsedData["Directory Item Semantic"] = itemSemantics.joined(separator: ", ")
        }
        
        // While maintaining GContainer format compatibility
        if !itemLengths.isEmpty {
            parsedData["GContainer:ItemLength"] = itemLengths.joined(separator: ", ")
        }
    }
}

class MotionPhotoProcessor {
    static func extractVideo(from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let asset = AVURLAsset(url: url)
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                guard let videoTrack = videoTracks.first else {
                    throw NSError(domain: "MotionPhotoProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: Localizable.string(LocalizableKey.noVideoData)])
                }
                
                let composition = AVMutableComposition()
                let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                let duration = try await asset.load(.duration)
                try compositionTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: duration), of: videoTrack, at: .zero)
                
                let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                
                exportSession?.outputURL = outputURL
                exportSession?.outputFileType = .mov
                
                exportSession?.exportAsynchronously {
                    switch exportSession?.status {
                    case .completed:
                        completion(.success(outputURL))
                    case .failed:
                        completion(.failure(exportSession?.error ?? NSError(domain: "MotionPhotoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: Localizable.string(LocalizableKey.videoExportFailed)])))
                    default:
                        completion(.failure(NSError(domain: "MotionPhotoProcessor", code: 3, userInfo: [NSLocalizedDescriptionKey: Localizable.string(LocalizableKey.unknownError)])))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}
