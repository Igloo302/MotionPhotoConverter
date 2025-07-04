//
//  MotionPhotoProcessor.swift
//  MotionPhotoConverter
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import UIKit

// MARK: - Motion Photo Brand Enum
enum MotionPhotoBrand: String, CaseIterable {
    case xiaomi = "Xiaomi"
    case pixel = "Pixel"
    case samsung = "Samsung"
    case unknown = "Unknown"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Motion Photo Data Structure
struct MotionPhotoData {
    let imageData: Data
    let videoData: Data
    let stillImageTime: Int
    let brand: MotionPhotoBrand
    let videoOffset: Int?
    let presentationTimestamp: Double?
}

// MARK: - Motion Photo Processing Result
struct MotionPhotoProcessingResult {
    let success: Bool
    let data: MotionPhotoData?
    let errorMessage: String?
}

// MARK: - Motion Photo Processor Protocol
protocol MotionPhotoProcessorProtocol {
    var brand: MotionPhotoBrand { get }
    
    /// 检测是否为该品牌的动态照片
    func canProcess(xmpInfo: [String: String]) -> Bool
    
    /// 处理动态照片数据
    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult
    
    /// 计算静态图片时间
    func calculateStillImageTime(videoDuration: Double, presentationTimestamp: Double?, frameRate: Double) -> Int
}

// MARK: - Base Motion Photo Processor
class BaseMotionPhotoProcessor: MotionPhotoProcessorProtocol {
    let brand: MotionPhotoBrand
    
    init(brand: MotionPhotoBrand) {
        self.brand = brand
    }
    
    func canProcess(xmpInfo: [String: String]) -> Bool {
        // 子类需要重写此方法
        return false
    }
    
    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // 子类需要重写此方法
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "Not implemented")
    }
    
    func calculateStillImageTime(videoDuration: Double, presentationTimestamp: Double?, frameRate: Double) -> Int {
        guard let timestamp = presentationTimestamp else {
            return Int(videoDuration * frameRate / 2) // 默认取中间帧
        }
        
        let photoTime = timestamp / 1_000_000.0 // 转换为秒
        let frameTime = 1.0 / frameRate
        let frameNumber = Int(photoTime / frameTime)
        
        return max(0, min(frameNumber, Int(videoDuration * frameRate) - 1))
    }
}

// MARK: - Xiaomi Motion Photo Processor
class XiaomiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    
    init() {
        super.init(brand: .xiaomi)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        return xmpInfo["GCamera:MicroVideoOffset"] != nil
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        guard let microVideoOffsetString = xmpInfo["GCamera:MicroVideoOffset"],
              let microVideoOffset = Int(microVideoOffsetString) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "无法解析小米动态照片的视频偏移量"
            )
        }
        
        // 提取时间戳
        let timestampString = xmpInfo["GCamera:MicroVideoPresentationTimestampUs"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }
        
        // 计算视频开始位置
        let videoStartOffset = data.count - microVideoOffset
        
        // 提取图片和视频数据
        let imageData = data.prefix(videoStartOffset)
        let videoData = data.suffix(microVideoOffset)
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0, // 将在后续计算
            brand: .xiaomi,
            videoOffset: videoStartOffset,
            presentationTimestamp: presentationTimestamp
        )
        
        return MotionPhotoProcessingResult(
            success: true,
            data: motionPhotoData,
            errorMessage: nil
        )
    }
}

// MARK: - Pixel Motion Photo Processor
class PixelMotionPhotoProcessor: BaseMotionPhotoProcessor {
    
    init() {
        super.init(brand: .pixel)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        // Pixel 通常使用 GContainer:ItemLength 且没有 Directory Item Padding
        return xmpInfo["GContainer:ItemLength"] != nil && xmpInfo["Directory Item Padding"] == nil
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // TODO: 实现 Pixel 动态照片处理逻辑
        return MotionPhotoProcessingResult(
            success: false,
            data: nil,
            errorMessage: "Pixel 动态照片处理功能尚未实现"
        )
    }
}

// MARK: - Samsung Motion Photo Processor
class SamsungMotionPhotoProcessor: BaseMotionPhotoProcessor {
    
    init() {
        super.init(brand: .samsung)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        // Samsung 通常使用 GContainer:ItemLength 且有 Directory Item Padding
        return xmpInfo["GContainer:ItemLength"] != nil && xmpInfo["Directory Item Padding"] != nil
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // TODO: 实现三星动态照片处理逻辑
        return MotionPhotoProcessingResult(
            success: false,
            data: nil,
            errorMessage: "三星动态照片处理功能尚未实现"
        )
    }
}

// MARK: - Motion Photo Processor Factory
class MotionPhotoProcessorFactory {
    private static let processors: [MotionPhotoProcessorProtocol] = [
        XiaomiMotionPhotoProcessor(),
        PixelMotionPhotoProcessor(),
        SamsungMotionPhotoProcessor()
    ]
    
    static func getProcessor(for xmpInfo: [String: String]) -> MotionPhotoProcessorProtocol? {
        return processors.first { $0.canProcess(xmpInfo: xmpInfo) }
    }
    
    static func getAllSupportedBrands() -> [MotionPhotoBrand] {
        return processors.map { $0.brand }
    }
}