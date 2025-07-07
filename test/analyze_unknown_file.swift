#!/usr/bin/env swift

import Foundation

// MARK: - File Analysis Demo

class FileAnalysisDemo {
    
    /// 分析文件的十六进制内容
    /// - Parameters:
    ///   - data: 文件数据
    ///   - start: 开始位置
    ///   - length: 分析长度
    static func analyzeHexContent(data: Data, start: Int, length: Int = 64) {
        let end = min(start + length, data.count)
        let subdata = data.subdata(in: start..<end)
        
        print("Offset \(String(format: "%08X", start)):")
        
        // 十六进制显示
        var hexString = ""
        var asciiString = ""
        
        for (index, byte) in subdata.enumerated() {
            if index % 16 == 0 && index > 0 {
                print("  \(hexString) | \(asciiString)")
                hexString = ""
                asciiString = ""
            }
            
            hexString += String(format: "%02X ", byte)
            
            if byte >= 32 && byte <= 126 {
                asciiString += String(format: "%c", byte)
            } else {
                asciiString += "."
            }
        }
        
        // 打印最后一行
        if !hexString.isEmpty {
            let padding = String(repeating: "   ", count: 16 - (subdata.count % 16))
            print("  \(hexString)\(padding) | \(asciiString)")
        }
        print()
    }
    
    /// 查找所有可能的视频格式标识
    static func findVideoSignatures(in data: Data) {
        let signatures = [
            ("ftyp (MP4)", Data([0x66, 0x74, 0x79, 0x70])),
            ("moov (QuickTime)", Data([0x6D, 0x6F, 0x6F, 0x76])),
            ("mdat (Media Data)", Data([0x6D, 0x64, 0x61, 0x74])),
            ("AVI RIFF", Data([0x52, 0x49, 0x46, 0x46])),
            ("MP4 brand", "mp4".data(using: .ascii)!),
            ("isom brand", "isom".data(using: .ascii)!),
            ("M4V brand", "M4V".data(using: .ascii)!),
            ("HEIC brand", "heic".data(using: .ascii)!),
        ]
        
        print("🔍 搜索视频格式标识:")
        
        for (name, signature) in signatures {
            var searchStart = 0
            var foundCount = 0
            
            while searchStart < data.count {
                if let range = data.range(of: signature, in: searchStart..<data.count) {
                    print("   ✅ \(name) found at offset: \(String(format: "%08X", range.lowerBound)) (\(range.lowerBound))")
                    foundCount += 1
                    searchStart = range.upperBound
                    
                    // 显示周围的内容
                    let contextStart = max(0, range.lowerBound - 16)
                    let contextEnd = min(data.count, range.upperBound + 16)
                    let contextData = data.subdata(in: contextStart..<contextEnd)
                    
                    print("      Context:")
                    analyzeHexContent(data: contextData, start: contextStart, length: contextEnd - contextStart)
                    
                    if foundCount >= 3 { // 限制每种类型最多显示3个
                        break
                    }
                } else {
                    break
                }
            }
            
            if foundCount == 0 {
                print("   ❌ \(name) not found")
            }
        }
    }
    
    /// 查找JPEG结束标记
    static func findJPEGEnd(in data: Data) -> Int? {
        let jpegEndMarker = Data([0xFF, 0xD9])
        
        if let range = data.range(of: jpegEndMarker) {
            return range.upperBound
        }
        return nil
    }
    
    /// 分析文件结构
    static func analyzeFileStructure(filePath: String) {
        print("📁 分析文件: \(filePath)")
        
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("❌ 无法读取文件")
            return
        }
        
        print("📊 文件大小: \(fileData.count) bytes (\(String(format: "%.2f", Double(fileData.count) / 1024.0 / 1024.0)) MB)")
        
        // 分析文件头
        print("\n📋 文件头分析:")
        analyzeHexContent(data: fileData, start: 0, length: 128)
        
        // 检查JPEG标记
        if fileData.count >= 2 && fileData[0] == 0xFF && fileData[1] == 0xD8 {
            print("✅ 检测到JPEG文件头")
            
            // 查找JPEG结束位置
            if let jpegEnd = findJPEGEnd(in: fileData) {
                print("✅ JPEG结束位置: \(jpegEnd) (\(String(format: "%08X", jpegEnd)))")
                
                let remainingSize = fileData.count - jpegEnd
                print("📊 JPEG后剩余数据: \(remainingSize) bytes")
                
                if remainingSize > 0 {
                    print("\n📋 JPEG后数据分析:")
                    analyzeHexContent(data: fileData, start: jpegEnd, length: min(128, remainingSize))
                    
                    // 分析剩余数据中的视频标识
                    let remainingData = fileData.subdata(in: jpegEnd..<fileData.count)
                    findVideoSignatures(in: remainingData)
                }
            } else {
                print("❌ 未找到JPEG结束标记")
            }
        } else {
            print("❌ 不是有效的JPEG文件")
        }
        
        // 在整个文件中搜索视频标识
        print("\n🔍 在整个文件中搜索视频标识:")
        findVideoSignatures(in: fileData)
        
        // 分析文件尾部
        print("\n📋 文件尾部分析:")
        let tailStart = max(0, fileData.count - 128)
        analyzeHexContent(data: fileData, start: tailStart, length: fileData.count - tailStart)
    }
}

// MARK: - Main Execution

func main() {
    let arguments = CommandLine.arguments
    
    if arguments.count < 2 {
        print("使用方法: swift analyze_unknown_file.swift <文件路径>")
        return
    }
    
    let filePath = arguments[1]
    FileAnalysisDemo.analyzeFileStructure(filePath: filePath)
}

main()