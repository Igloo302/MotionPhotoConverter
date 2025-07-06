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
    case android = "Android"
    case unknown = "Unknown"
    
    var displayName: String {
        switch self {
        case .android:
            return "Android (Pixel/Samsung)"
        default:
            return self.rawValue
        }
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
    
    /// Detect if it's a motion photo of this brand
    func canProcess(xmpInfo: [String: String]) -> Bool
    
    /// Process motion photo data
    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult
    
    /// Calculate still image time
    func calculateStillImageTime(videoDuration: Double, presentationTimestamp: Double?, frameRate: Double) -> Int
}

// MARK: - Base Motion Photo Processor
class BaseMotionPhotoProcessor: MotionPhotoProcessorProtocol {
    let brand: MotionPhotoBrand
    
    init(brand: MotionPhotoBrand) {
        self.brand = brand
    }
    
    func canProcess(xmpInfo: [String: String]) -> Bool {
        // Subclasses need to override this method
        return false
    }
    
    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // Subclasses need to override this method
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "Not implemented")
    }
    
    func calculateStillImageTime(videoDuration: Double, presentationTimestamp: Double?, frameRate: Double) -> Int {
        guard let timestamp = presentationTimestamp else {
            return Int(videoDuration * frameRate / 2) // Default to middle frame
        }
        
        let photoTime = timestamp / 1_000_000.0 // Convert to seconds
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
                errorMessage: "Unable to parse video offset for Xiaomi motion photo"
            )
        }
        
        // Extract timestamp
        let timestampString = xmpInfo["GCamera:MicroVideoPresentationTimestampUs"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }
        
        // Calculate video start position
        let videoStartOffset = data.count - microVideoOffset
        
        // Extract image and video data
        let imageData = data.prefix(videoStartOffset)
        let videoData = data.suffix(microVideoOffset)
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0, // Will be calculated later
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

// MARK: - Android Motion Photo Processor (Pixel/Samsung)
class AndroidMotionPhotoProcessor: BaseMotionPhotoProcessor {
    
    init() {
        super.init(brand: .android)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        // Android motion photos support multiple formats:
        // 1. GContainer:ItemLength format (mainly Pixel)
        // 2. Directory Item Length + Directory Item Padding format (Pixel/Samsung)
        // 3. GCamera:MotionPhoto format (some Samsung)
        
        let hasGContainer = xmpInfo["GContainer:ItemLength"] != nil
        let hasDirectoryItem = xmpInfo["Directory Item Length"] != nil
        let hasGCamera = xmpInfo["GCamera:MotionPhoto"] != nil
        
        return hasGContainer || hasDirectoryItem || hasGCamera
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // Try GContainer:ItemLength format first
        if let itemLengthString = xmpInfo["GContainer:ItemLength"] {
            return processGContainerFormat(data: data, xmpInfo: xmpInfo, itemLengthString: itemLengthString)
        }
        
        // Try Directory Item Length format
        if let directoryItemLengthString = xmpInfo["Directory Item Length"] {
            return processDirectoryItemFormat(data: data, xmpInfo: xmpInfo, lengthString: directoryItemLengthString)
        }
        
        // Try GCamera format
        if xmpInfo["GCamera:MotionPhoto"] != nil {
            return processGCameraFormat(data: data, xmpInfo: xmpInfo)
        }
        
        return MotionPhotoProcessingResult(
            success: false,
            data: nil,
            errorMessage: "Missing length information for Android motion photo"
        )
    }
    
    private func processGContainerFormat(data: Data, xmpInfo: [String: String], itemLengthString: String) -> MotionPhotoProcessingResult {
        // Parse length information, format is usually "0, 1234567"
        let lengthComponents = itemLengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard lengthComponents.count >= 2,
              let imageLength = Int(lengthComponents[0]),
              let videoLength = Int(lengthComponents[1]) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "Unable to parse GContainer length information for Android motion photo"
            )
        }
        
        // Extract timestamp
        let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }
        
        // Calculate video data start position
        let videoStartOffset = data.count - videoLength
        
        // Extract image and video data
        let imageData = data.prefix(videoStartOffset)
        let videoData = data.suffix(videoLength)
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: .android,
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
        // Parse length information "0, 1619843" -> [0, 1619843]
        let lengthComponents = lengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard lengthComponents.count >= 2,
              let imageLength = Int(lengthComponents[0]),
              let videoLength = Int(lengthComponents[1]) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "Unable to parse Directory Item length information for Android motion photo"
            )
        }
        
        // Extract timestamp
        let timestampString = xmpInfo["Motion Photo Presentation Timestamp Us"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }
        
        // Check if there's padding information (some Samsung devices)
        if let paddingString = xmpInfo["Directory Item Padding"] {
            return processWithPadding(data: data, lengthComponents: lengthComponents, paddingString: paddingString, presentationTimestamp: presentationTimestamp)
        } else {
            // Simple mode: video at end of file (most Pixel devices)
            return processWithoutPadding(data: data, videoLength: videoLength, presentationTimestamp: presentationTimestamp)
        }
    }
    
    private func processWithPadding(data: Data, lengthComponents: [String], paddingString: String, presentationTimestamp: Double?) -> MotionPhotoProcessingResult {
        let paddingComponents = paddingString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard paddingComponents.count >= 2,
              let imageLength = Int(lengthComponents[0]),
              let videoLength = Int(lengthComponents[1]),
              let imagePadding = Int(paddingComponents[0]),
              let videoPadding = Int(paddingComponents[1]) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "Unable to parse padding information for Android motion photo"
            )
        }
        
        // Calculate actual image and video data positions (considering padding)
        let imageEndOffset = data.count - videoLength - videoPadding
        let videoStartOffset = imageEndOffset + imagePadding
        
        // Extract image and video data
        let imageData = data.prefix(imageEndOffset)
        let videoData = data.subdata(in: videoStartOffset..<(videoStartOffset + videoLength))
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: .android,
            videoOffset: videoStartOffset,
            presentationTimestamp: presentationTimestamp
        )
        
        return MotionPhotoProcessingResult(
            success: true,
            data: motionPhotoData,
            errorMessage: nil
        )
    }
    
    private func processWithoutPadding(data: Data, videoLength: Int, presentationTimestamp: Double?) -> MotionPhotoProcessingResult {
        // Simple mode: video at end of file
        let videoStartOffset = data.count - videoLength
        
        // Extract image and video data
        let imageData = data.prefix(videoStartOffset)
        let videoData = data.suffix(videoLength)
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: .android,
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
        // GCamera format needs to find video data through XMP information
        // Look for Directory Item Length information
        if let lengthInfo = xmpInfo["Directory Item Length"] {
            let lengths = lengthInfo.components(separatedBy: ", ")
            if lengths.count >= 2, let videoLength = Int(lengths[1]), videoLength > 0 {
                // Video data is at end of file, start position = total file length - video length
                let videoStartOffset = data.count - videoLength
                
                if videoStartOffset > 0 && videoStartOffset < data.count {
                    // Extract timestamp
                    let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
                    let presentationTimestamp = timestampString.flatMap { Double($0) }
                    
                    // Extract image and video data
                    let imageData = data.prefix(videoStartOffset)
                    let videoData = data.suffix(from: videoStartOffset)
                    
                    let motionPhotoData = MotionPhotoData(
                        imageData: imageData,
                        videoData: videoData,
                        stillImageTime: 0,
                        brand: .android,
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
            errorMessage: "Unable to find video data length information in GCamera format Android motion photo"
        )
    }
}

// MARK: - Motion Photo Processor Factory
class MotionPhotoProcessorFactory {
    private static let processors: [MotionPhotoProcessorProtocol] = [
        XiaomiMotionPhotoProcessor(),
        AndroidMotionPhotoProcessor()
    ]
    
    static func getProcessor(for xmpInfo: [String: String]) -> MotionPhotoProcessorProtocol? {
        return processors.first { $0.canProcess(xmpInfo: xmpInfo) }
    }
    
    static func getAllSupportedBrands() -> [MotionPhotoBrand] {
        return processors.map { $0.brand }
    }
}