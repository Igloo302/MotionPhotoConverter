#!/usr/bin/env swift

import Foundation

// MARK: - File Type Box Detection Demo

class FtypDetectionDemo {
    
    /// 查找MP4视频通过File Type Box检测
    /// - Parameter data: 文件数据
    /// - Returns: 视频数据和偏移位置的元组，如果未找到则返回nil
    static func findMP4VideoByFileTypeBox(in data: Data) -> (videoData: Data, offset: Int)? {
        let ftypSignature = Data([0x66, 0x74, 0x79, 0x70]) // "ftyp"
        let mp4Brand = "mp4".data(using: .ascii)!
        
        var searchIndex = 0
        let dataCount = data.count
        
        while searchIndex < dataCount - 8 {
            // 查找ftyp签名
            if let ftypRange = data.range(of: ftypSignature, in: searchIndex..<dataCount) {
                let ftypStart = ftypRange.lowerBound
                
                // 检查ftyp box的大小（前4字节）
                if ftypStart >= 4 {
                    let boxSizeStart = ftypStart - 4
                    let boxSizeData = data.subdata(in: boxSizeStart..<ftypStart)
                    let boxSize = boxSizeData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                    
                    // 验证box大小的合理性
                    if boxSize >= 16 && boxSize <= 1024 {
                        let brandStart = ftypStart + 4
                        let brandEnd = min(brandStart + Int(boxSize) - 8, dataCount)
                        
                        if brandEnd > brandStart {
                            let brandData = data.subdata(in: brandStart..<brandEnd)
                            
                            // 检查是否包含mp4品牌
                            if brandData.range(of: mp4Brand) != nil {
                                print("✅ 找到MP4 File Type Box at offset: \(boxSizeStart)")
                                print("📦 Box size: \(boxSize) bytes")
                                
                                // 从ftyp box开始提取视频数据
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
    
    /// 提取图像数据（JPEG部分）
    /// - Parameters:
    ///   - data: 完整文件数据
    ///   - videoOffset: 视频数据的偏移位置
    /// - Returns: 图像数据
    static func extractImageData(from data: Data, videoOffset: Int) -> Data {
        return data.subdata(in: 0..<videoOffset)
    }
    
    /// 验证JPEG文件头
    /// - Parameter data: 数据
    /// - Returns: 是否为有效的JPEG
    static func isValidJPEG(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        return data[0] == 0xFF && data[1] == 0xD8
    }
    
    /// 验证MP4文件
    /// - Parameter data: 数据
    /// - Returns: 是否包含MP4特征
    static func isValidMP4(_ data: Data) -> Bool {
        let ftypSignature = Data([0x66, 0x74, 0x79, 0x70]) // "ftyp"
        return data.range(of: ftypSignature) != nil
    }
    
    /// 主验证函数
    /// - Parameter filePath: 文件路径
    static func verifyFtypDetection(filePath: String) {
        print("🔍 开始验证File Type Box检测方案...")
        print("📁 文件路径: \(filePath)")
        
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("❌ 无法读取文件")
            return
        }
        
        print("📊 文件大小: \(fileData.count) bytes")
        
        // 尝试通过ftyp检测找到MP4视频
        if let result = findMP4VideoByFileTypeBox(in: fileData) {
            let imageData = extractImageData(from: fileData, videoOffset: result.offset)
            
            print("\n📸 图像数据分析:")
            print("   大小: \(imageData.count) bytes")
            print("   有效JPEG: \(isValidJPEG(imageData) ? "✅" : "❌")")
            
            print("\n🎬 视频数据分析:")
            print("   大小: \(result.videoData.count) bytes")
            print("   偏移位置: \(result.offset)")
            print("   有效MP4: \(isValidMP4(result.videoData) ? "✅" : "❌")")
            
            // 保存分离的文件用于验证
            let outputDir = URL(fileURLWithPath: filePath).deletingLastPathComponent()
            
            let imageOutputPath = outputDir.appendingPathComponent("extracted_image.jpg")
            let videoOutputPath = outputDir.appendingPathComponent("extracted_video.mp4")
            
            do {
                try imageData.write(to: imageOutputPath)
                try result.videoData.write(to: videoOutputPath)
                
                print("\n💾 文件保存成功:")
                print("   图像: \(imageOutputPath.path)")
                print("   视频: \(videoOutputPath.path)")
                
                print("\n🎉 File Type Box检测方案验证成功！")
            } catch {
                print("❌ 保存文件时出错: \(error)")
            }
            
        } else {
            print("❌ 未能通过File Type Box检测找到MP4视频")
            
            // 尝试查找其他可能的视频格式标识
            print("\n🔍 尝试查找其他视频格式标识...")
            let possibleSignatures = [
                ("MP4", Data([0x66, 0x74, 0x79, 0x70])), // ftyp
                ("MOV", Data([0x6D, 0x6F, 0x6F, 0x76])), // moov
                ("AVI", Data([0x41, 0x56, 0x49, 0x20])), // AVI 
            ]
            
            for (format, signature) in possibleSignatures {
                if let range = fileData.range(of: signature) {
                    print("   找到\(format)标识 at offset: \(range.lowerBound)")
                }
            }
        }
    }
}

// MARK: - Main Execution

func main() {
    let arguments = CommandLine.arguments
    
    if arguments.count < 2 {
        print("使用方法: swift verify_ftyp_detection.swift <文件路径>")
        print("示例: swift verify_ftyp_detection.swift /path/to/Unknown.jpg")
        return
    }
    
    let filePath = arguments[1]
    FtypDetectionDemo.verifyFtypDetection(filePath: filePath)
}

main()