#!/usr/bin/env swift

import Foundation

// MARK: - Test Unknown Motion Photo Processor

// 复制我们实现的UnknownMotionPhotoProcessor逻辑
class TestUnknownProcessor {
    
    /// 查找MP4视频通过File Type Box检测
    static func findMP4VideoByFileTypeBox(in data: Data) -> (videoData: Data, offset: Int)? {
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
                                let videoData = data.subdata(in: boxSizeStart..<dataCount)
                                return (videoData: videoData, offset: boxSizeStart)
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
    
    /// 模拟UnknownMotionPhotoProcessor的processMotionPhoto方法
    static func processMotionPhoto(data: Data) -> (success: Bool, imageData: Data?, videoData: Data?, stillImageTime: Int) {
        // 尝试通过File Type Box检测找到MP4视频
        if let result = findMP4VideoByFileTypeBox(in: data) {
            let imageData = data.subdata(in: 0..<result.offset)
            
            // 验证图像数据是否为有效JPEG
            let isValidJPEG = imageData.count >= 2 && imageData[0] == 0xFF && imageData[1] == 0xD8
            
            if isValidJPEG {
                // 计算stillImageTime（假设为视频时长的一半，这里简化为0）
                let stillImageTime = 0
                
                return (success: true, imageData: imageData, videoData: result.videoData, stillImageTime: stillImageTime)
            }
        }
        
        return (success: false, imageData: nil, videoData: nil, stillImageTime: 0)
    }
    
    /// 测试处理器
    static func testProcessor(filePath: String) {
        print("🧪 测试UnknownMotionPhotoProcessor")
        print("📁 文件: \(filePath)")
        
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("❌ 无法读取文件")
            return
        }
        
        print("📊 文件大小: \(fileData.count) bytes")
        
        let result = processMotionPhoto(data: fileData)
        
        if result.success {
            print("✅ 处理成功！")
            
            if let imageData = result.imageData {
                print("📸 图像数据: \(imageData.count) bytes")
                
                // 验证JPEG头
                let isValidJPEG = imageData.count >= 2 && imageData[0] == 0xFF && imageData[1] == 0xD8
                print("   有效JPEG: \(isValidJPEG ? "✅" : "❌")")
            }
            
            if let videoData = result.videoData {
                print("🎬 视频数据: \(videoData.count) bytes")
                
                // 验证MP4标识
                let ftypSignature = Data([0x66, 0x74, 0x79, 0x70])
                let hasMP4Signature = videoData.range(of: ftypSignature) != nil
                print("   包含ftyp: \(hasMP4Signature ? "✅" : "❌")")
            }
            
            print("⏱️ stillImageTime: \(result.stillImageTime)")
            
            // 保存测试结果
            let outputDir = URL(fileURLWithPath: filePath).deletingLastPathComponent()
            
            if let imageData = result.imageData {
                let imageOutputPath = outputDir.appendingPathComponent("test_extracted_image.jpg")
                try? imageData.write(to: imageOutputPath)
                print("💾 测试图像保存到: \(imageOutputPath.path)")
            }
            
            if let videoData = result.videoData {
                let videoOutputPath = outputDir.appendingPathComponent("test_extracted_video.mp4")
                try? videoData.write(to: videoOutputPath)
                print("💾 测试视频保存到: \(videoOutputPath.path)")
            }
            
        } else {
            print("❌ 处理失败")
        }
    }
}

// MARK: - Main Execution

func main() {
    let arguments = CommandLine.arguments
    
    if arguments.count < 2 {
        print("使用方法: swift test_unknown_processor.swift <文件路径>")
        return
    }
    
    let filePath = arguments[1]
    TestUnknownProcessor.testProcessor(filePath: filePath)
}

main()