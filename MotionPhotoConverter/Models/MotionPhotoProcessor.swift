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
        // Pixel 使用 GContainer:ItemLength 或 Directory Item Length 格式
        // 但优先级高于Samsung，所以先检查Pixel特有的标识
        let hasGContainer = xmpInfo["GContainer:ItemLength"] != nil
        let hasDirectoryItem = xmpInfo["Directory Item Length"] != nil && xmpInfo["Directory Item Padding"] != nil
        let hasGCamera = xmpInfo["GCamera:MotionPhoto"] != nil
        
        // 如果有GContainer，肯定是Pixel
        if hasGContainer {
            return true
        }
        
        // 如果有Directory Item和GCamera，也可能是Pixel（需要进一步区分）
        if hasDirectoryItem && hasGCamera {
            // 这里可以添加更多的区分逻辑，暂时返回true让Pixel优先处理
            return true
        }
        
        return false
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // Pixel 动态照片处理逻辑 - 支持两种格式
        
        // 优先尝试 GContainer:ItemLength 格式
        if let itemLengthString = xmpInfo["GContainer:ItemLength"] {
            return processGContainerFormat(data: data, xmpInfo: xmpInfo, itemLengthString: itemLengthString)
        }
        
        // 尝试 Directory Item Length 格式
        if let directoryItemLengthString = xmpInfo["Directory Item Length"] {
            return processDirectoryItemFormat(data: data, xmpInfo: xmpInfo, lengthString: directoryItemLengthString)
        }
        
        return MotionPhotoProcessingResult(
            success: false,
            data: nil,
            errorMessage: "缺少 Pixel 动态照片的长度信息"
        )
    }
    
    private func processGContainerFormat(data: Data, xmpInfo: [String: String], itemLengthString: String) -> MotionPhotoProcessingResult {
        // 解析长度信息，格式通常为 "0, 1234567"
        let lengthComponents = itemLengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard lengthComponents.count >= 2,
              let imageLength = Int(lengthComponents[0]),
              let videoLength = Int(lengthComponents[1]) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "无法解析 Pixel 动态照片的 GContainer 长度信息"
            )
        }
        
        // 提取时间戳
        let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }
        
        // 计算视频数据的起始位置
        let videoStartOffset = data.count - videoLength
        
        // 提取图片和视频数据
        let imageData = data.prefix(videoStartOffset)
        let videoData = data.suffix(videoLength)
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: .pixel,
            videoOffset: videoStartOffset,
            presentationTimestamp: presentationTimestamp
        )
        
        return MotionPhotoProcessingResult(
            success: true,
            data: motionPhotoData,
            errorMessage: nil
        )
    }
    
    private func processDirectoryItemFormat(data: Data, xmpInfo: [String: String], lengthString: String) -> MotionPhotoProcessingResult {
        // 解析长度信息 "0, 1619843" -> [0, 1619843]
        let lengthComponents = lengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard lengthComponents.count >= 2,
              let imageLength = Int(lengthComponents[0]),
              let videoLength = Int(lengthComponents[1]) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "无法解析 Pixel 动态照片的 Directory Item 长度信息"
            )
        }
        
        // 提取时间戳
        let timestampString = xmpInfo["Motion Photo Presentation Timestamp Us"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }
        
        // 计算视频数据的起始位置（简单模式：视频在文件末尾）
        let videoStartOffset = data.count - videoLength
        
        // 提取图片和视频数据
        let imageData = data.prefix(videoStartOffset)
        let videoData = data.suffix(videoLength)
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: .pixel,
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

// MARK: - Samsung Motion Photo Processor
class SamsungMotionPhotoProcessor: BaseMotionPhotoProcessor {
    
    init() {
        super.init(brand: .samsung)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        // Samsung 处理器只处理Pixel处理器无法处理的情况
        // 确保Pixel优先级更高
        let hasDirectoryFormat = xmpInfo["Directory Item Length"] != nil && xmpInfo["Directory Item Padding"] != nil
        let hasGCameraFormat = xmpInfo["GCamera:MotionPhoto"] != nil && xmpInfo["GCamera:MotionPhotoVersion"] != nil
        let hasGContainer = xmpInfo["GContainer:ItemLength"] != nil
        
        // 如果有GContainer，让Pixel处理器处理
        if hasGContainer {
            return false
        }
        
        // 只有在没有GContainer的情况下才处理Directory Item或GCamera格式
        return hasDirectoryFormat || hasGCameraFormat
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // 检查是否为Directory Item格式
        if let directoryItemLengthString = xmpInfo["Directory Item Length"],
           let directoryItemPaddingString = xmpInfo["Directory Item Padding"] {
            return processDirectoryItemFormat(data: data, xmpInfo: xmpInfo, lengthString: directoryItemLengthString, paddingString: directoryItemPaddingString)
        }
        
        // 检查是否为GCamera格式
        if xmpInfo["GCamera:MotionPhoto"] != nil {
            return processGCameraFormat(data: data, xmpInfo: xmpInfo)
        }
        
        return MotionPhotoProcessingResult(
            success: false,
            data: nil,
            errorMessage: "无法识别三星动态照片格式"
        )
    }
    
    private func processDirectoryItemFormat(data: Data, xmpInfo: [String: String], lengthString: String, paddingString: String) -> MotionPhotoProcessingResult {
        // 解析长度信息 "0, 5421673" -> [0, 5421673]
        let lengthComponents = lengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let paddingComponents = paddingString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard lengthComponents.count >= 2,
              paddingComponents.count >= 2,
              let imageLength = Int(lengthComponents[0]),
              let videoLength = Int(lengthComponents[1]),
              let imagePadding = Int(paddingComponents[0]),
              let videoPadding = Int(paddingComponents[1]) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "无法解析三星动态照片的长度和填充信息"
            )
        }
        
        // 提取时间戳
        let timestampString = xmpInfo["Motion Photo Presentation Timestamp Us"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }
        
        // 计算实际的图片和视频数据位置
        let imageEndOffset = data.count - videoLength - videoPadding
        let videoStartOffset = imageEndOffset + imagePadding
        
        // 提取图片和视频数据
        let imageData = data.prefix(imageEndOffset)
        let videoData = data.subdata(in: videoStartOffset..<(videoStartOffset + videoLength))
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: .samsung,
            videoOffset: videoStartOffset,
            presentationTimestamp: presentationTimestamp
        )
        
        return MotionPhotoProcessingResult(
            success: true,
            data: motionPhotoData,
            errorMessage: nil
        )
    }
    
    private func processGCameraFormat(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // GCamera格式的三星照片需要通过XMP信息来找到视频数据
        // 查找Directory Item Length信息
        if let lengthInfo = xmpInfo["Directory Item Length"] {
            let lengths = lengthInfo.components(separatedBy: ", ")
            if lengths.count >= 2, let videoLength = Int(lengths[1]), videoLength > 0 {
                // 视频数据位于文件末尾，起始位置 = 文件总长度 - 视频长度
                let videoStartOffset = data.count - videoLength
                
                if videoStartOffset > 0 && videoStartOffset < data.count {
                    // 提取时间戳
                    let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
                    let presentationTimestamp = timestampString.flatMap { Double($0) }
                    
                    // 提取图片和视频数据
                    let imageData = data.prefix(videoStartOffset)
                    let videoData = data.suffix(from: videoStartOffset)
                    
                    let motionPhotoData = MotionPhotoData(
                        imageData: imageData,
                        videoData: videoData,
                        stillImageTime: 0,
                        brand: .samsung,
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
        }
        
        return MotionPhotoProcessingResult(
            success: false,
            data: nil,
            errorMessage: "无法在GCamera格式的三星照片中找到视频数据长度信息"
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