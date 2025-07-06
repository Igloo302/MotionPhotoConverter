import Foundation
import AVFoundation

struct MotionPhoto {
    let imageData: Data
    let videoData: Data
    let sourceURL: URL
    let creationDate: Date?
    let modificationDate: Date?
    let stillImageTime: Int8
    
    init?(sourceURL: URL) {
        self.sourceURL = sourceURL
        
        guard let data = try? Data(contentsOf: sourceURL),
              let xmpData = extractXMPData(from: data),
              let xmpInfo = parseXMP(data: xmpData) else {
            return nil
        }
        
        // Check if it's a motion photo
        guard (xmpInfo["GCamera:MotionPhoto"] == "1" || xmpInfo["GCamera:MicroVideo"] == "1" || xmpInfo["Motion Photo"] == "1") else {
            return nil
        }
        
        // Use processor factory to get appropriate processor
        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo) else {
            print("Unsupported motion photo format")
            return nil
        }
        
        // Process motion photo data
        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard result.success, let motionPhotoData = result.data else {
            print("Failed to process motion photo: \(result.errorMessage ?? "Unknown error")")
            return nil
        }
        
        self.imageData = motionPhotoData.imageData
        self.videoData = motionPhotoData.videoData
        
        // Calculate stillImageTime
        if let presentationTimestamp = motionPhotoData.presentationTimestamp {
            let photoTime = presentationTimestamp / 1_000_000.0
            self.stillImageTime = Self.calculateStillImageTime(videoData: videoData, photoTime: photoTime)
        } else {
            self.stillImageTime = 0
        }
        
        // Get creation date
        if let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path) {
            self.creationDate = attributes[.creationDate] as? Date
            self.modificationDate = attributes[.modificationDate] as? Date
        } else {
            self.creationDate = nil
            self.modificationDate = nil
        }
    }
    
    private static func calculateStillImageTime(videoData: Data, photoTime: Double) -> Int8 {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video_calc.mp4")
        do {
            try videoData.write(to: tempURL)
            let asset = AVAsset(url: tempURL)
            
            // Synchronously get video duration and frame rate
            let duration = try asset.load(.duration)
            let videoDuration = CMTimeGetSeconds(duration)
            
            let tracks = try asset.loadTracks(withMediaType: .video)
            let frameRate = try tracks.first?.load(.nominalFrameRate) ?? 30.0
            
            // Calculate total video frames
            let totalFrames = Int(videoDuration * Double(frameRate))
            
            // Calculate frame number where photo is located
            let photoFrame = Int(photoTime * Double(frameRate))
            
            // Ensure photoFrame doesn't exceed total frames
            let clampedPhotoFrame = min(max(photoFrame, 0), totalFrames - 1)
            
            // Calculate ratio
            let ratio = Double(clampedPhotoFrame) / Double(totalFrames - 1)
            
            // Convert ratio to integer in 0-255 range
            let stillImageTime = Int(round(ratio * 255))
            
            // Clean up temporary files
            try? FileManager.default.removeItem(at: tempURL)
            
            // Ensure result is within 0-255 range
            return Int8(min(max(stillImageTime, 0), 255))
        } catch {
            return 0
        }
    }
}