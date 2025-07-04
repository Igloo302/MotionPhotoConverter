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
        
        // 检查是否为动态照片
        guard (xmpInfo["GCamera:MotionPhoto"] == "1" || xmpInfo["GCamera:MicroVideo"] == "1" || xmpInfo["Motion Photo"] == "1") else {
            return nil
        }
        
        // 使用处理器工厂获取合适的处理器
        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo) else {
            print("不支持的动态照片格式")
            return nil
        }
        
        // 处理动态照片数据
        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard result.success, let motionPhotoData = result.data else {
            print("处理动态照片失败: \(result.errorMessage ?? "未知错误")")
            return nil
        }
        
        self.imageData = motionPhotoData.imageData
        self.videoData = motionPhotoData.videoData
        
        // 计算 stillImageTime
        if let presentationTimestamp = motionPhotoData.presentationTimestamp {
            let photoTime = presentationTimestamp / 1_000_000.0
            self.stillImageTime = Self.calculateStillImageTime(videoData: videoData, photoTime: photoTime)
        } else {
            self.stillImageTime = 0
        }
        
        // 获取创建日期
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
            
            // 同步获取视频时长和帧率
            let duration = try asset.load(.duration)
            let videoDuration = CMTimeGetSeconds(duration)
            
            let tracks = try asset.loadTracks(withMediaType: .video)
            let frameRate = try tracks.first?.load(.nominalFrameRate) ?? 30.0
            
            // 计算视频总帧数
            let totalFrames = Int(videoDuration * Double(frameRate))
            
            // 计算照片所在的帧数
            let photoFrame = Int(photoTime * Double(frameRate))
            
            // 确保 photoFrame 不超过总帧数
            let clampedPhotoFrame = min(max(photoFrame, 0), totalFrames - 1)
            
            // 计算比例
            let ratio = Double(clampedPhotoFrame) / Double(totalFrames - 1)
            
            // 将比例转换为 0-255 范围的整数
            let stillImageTime = Int(round(ratio * 255))
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempURL)
            
            // 确保结果在 0-255 范围内
            return Int8(min(max(stillImageTime, 0), 255))
        } catch {
            return 0
        }
    }
}