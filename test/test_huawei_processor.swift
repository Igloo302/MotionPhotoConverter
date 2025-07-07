#!/usr/bin/env swift

import Foundation

// Copy the necessary structures and classes for testing
struct MotionPhotoData {
    let imageData: Data
    let videoData: Data
    let stillImageTime: Int
    let brand: MotionPhotoBrand
    let videoOffset: Int
    let presentationTimestamp: Double?
}

struct MotionPhotoProcessingResult {
    let success: Bool
    let data: MotionPhotoData?
    let errorMessage: String?
}

enum MotionPhotoBrand: String, CaseIterable {
    case xiaomi = "Xiaomi"
    case android = "Android"
    case huawei = "Huawei"
    case unknown = "Unknown"
}

protocol MotionPhotoProcessorProtocol {
    var brand: MotionPhotoBrand { get }
    func canProcess(xmpInfo: [String: String]) -> Bool
    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult
}

class BaseMotionPhotoProcessor: MotionPhotoProcessorProtocol {
    let brand: MotionPhotoBrand
    
    init(brand: MotionPhotoBrand) {
        self.brand = brand
    }
    
    func canProcess(xmpInfo: [String: String]) -> Bool {
        return false
    }
    
    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "Not implemented")
    }
}

class HuaweiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    
    init() {
        super.init(brand: .huawei)
    }
    
    override func canProcess(xmpInfo: [String: String]) -> Bool {
        return xmpInfo["Make"] == "HUAWEI" || xmpInfo["Manufacturer"] == "HUAWEI"
    }
    
    func canProcessByFileTypeBox(data: Data) -> Bool {
        return findMP4VideoByFileTypeBox(data: data) != nil
    }
    
    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        guard let videoInfo = findMP4VideoByFileTypeBox(data: data) else {
            return MotionPhotoProcessingResult(
                success: false,
                data: nil,
                errorMessage: "No MP4 video found using File Type Box detection for Huawei motion photo"
            )
        }
        
        let videoStartOffset = videoInfo.offset
        let videoLength = videoInfo.length
        
        let imageData = data.prefix(videoStartOffset)
        let videoData = data.subdata(in: videoStartOffset..<(videoStartOffset + videoLength))
        
        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: .huawei,
            videoOffset: videoStartOffset,
            presentationTimestamp: nil
        )
        
        return MotionPhotoProcessingResult(
            success: true,
            data: motionPhotoData,
            errorMessage: nil
        )
    }
    
    private func findMP4VideoByFileTypeBox(data: Data) -> (offset: Int, length: Int)? {
        let ftypSignature = Data([0x66, 0x74, 0x79, 0x70]) // "ftyp"
        let mp4Brand = "mp4".data(using: .ascii)!
        
        var searchIndex = 0
        let dataCount = data.count
        
        while searchIndex < dataCount - 8 {
            if let ftypRange = data.range(of: ftypSignature, in: searchIndex..<dataCount) {
                let ftypStart = ftypRange.lowerBound
                
                if ftypStart >= 4 {
                    let boxSizeStart = ftypStart - 4
                    let boxSizeData = data.subdata(in: boxSizeStart..<ftypStart)
                    let boxSize = boxSizeData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                    
                    if boxSize >= 16 && boxSize <= 1024 {
                        let brandStart = ftypStart + 4
                        let brandEnd = min(brandStart + Int(boxSize) - 8, dataCount)
                        
                        if brandEnd > brandStart {
                            let brandData = data.subdata(in: brandStart..<brandEnd)
                            
                            if brandData.range(of: mp4Brand) != nil {
                                let mp4Length = dataCount - boxSizeStart
                                return (offset: boxSizeStart, length: mp4Length)
                            }
                        }
                    }
                }
                
                searchIndex = ftypRange.upperBound
            } else {
                break
            }
        }
        
        return nil
    }
}

// Test the Huawei processor
func testHuaweiProcessor() {
    print("Testing Huawei Motion Photo Processor...")
    
    let testFilePath = "/Users/larry.shen/Downloads/MotionPhotoConverter/samples/HUAWEI.jpeg"
    
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: testFilePath)) else {
        print("❌ Failed to load test file: \(testFilePath)")
        return
    }
    
    print("✅ Loaded test file: \(data.count) bytes")
    
    let processor = HuaweiMotionPhotoProcessor()
    
    // Test File Type Box detection
    let canProcess = processor.canProcessByFileTypeBox(data: data)
    print("File Type Box detection: \(canProcess ? "✅ Detected" : "❌ Not detected")")
    
    if canProcess {
        // Test processing
        let xmpInfo: [String: String] = [:] // Empty XMP for File Type Box detection
        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        
        if result.success, let motionPhotoData = result.data {
            print("✅ Processing successful!")
            print("   - Brand: \(motionPhotoData.brand.rawValue)")
            print("   - Image data size: \(motionPhotoData.imageData.count) bytes")
            print("   - Video data size: \(motionPhotoData.videoData.count) bytes")
            print("   - Video offset: \(motionPhotoData.videoOffset)")
            
            // Save extracted files for verification
            let imageURL = URL(fileURLWithPath: "/Users/larry.shen/Downloads/MotionPhotoConverter/test/huawei_extracted_image.jpg")
            let videoURL = URL(fileURLWithPath: "/Users/larry.shen/Downloads/MotionPhotoConverter/test/huawei_extracted_video.mp4")
            
            do {
                try motionPhotoData.imageData.write(to: imageURL)
                try motionPhotoData.videoData.write(to: videoURL)
                print("✅ Extracted files saved:")
                print("   - Image: \(imageURL.path)")
                print("   - Video: \(videoURL.path)")
            } catch {
                print("❌ Failed to save extracted files: \(error)")
            }
        } else {
            print("❌ Processing failed: \(result.errorMessage ?? "Unknown error")")
        }
    }
    
    // Test with Huawei EXIF data
    let huaweiXmpInfo = ["Make": "HUAWEI"]
    let canProcessWithExif = processor.canProcess(xmpInfo: huaweiXmpInfo)
    print("EXIF-based detection: \(canProcessWithExif ? "✅ Detected" : "❌ Not detected")")
}

// Run the test
testHuaweiProcessor()
print("\n🎉 Huawei processor test completed!")