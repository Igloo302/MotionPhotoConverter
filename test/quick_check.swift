#!/usr/bin/env swift

import Foundation

// MARK: - Quick File Check

class QuickFileCheck {
    
    /// 快速检查文件是否包含视频数据
    static func quickCheck(filePath: String) {
        print("🔍 快速检查文件: \(filePath)")
        
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("❌ 无法读取文件")
            return
        }
        
        print("📊 文件大小: \(fileData.count) bytes")
        
        // 检查JPEG结束标记
        let jpegEndMarker = Data([0xFF, 0xD9])
        if let range = fileData.range(of: jpegEndMarker) {
            let jpegEnd = range.upperBound
            let remainingSize = fileData.count - jpegEnd
            
            print("✅ JPEG结束位置: \(jpegEnd)")
            print("📊 JPEG后剩余数据: \(remainingSize) bytes")
            
            if remainingSize > 100 { // 如果有超过100字节的剩余数据，可能包含视频
                print("🎬 可能包含视频数据")
                
                // 检查常见的视频格式标识
                let remainingData = fileData.subdata(in: jpegEnd..<fileData.count)
                
                let signatures = [
                    ("ftyp", Data([0x66, 0x74, 0x79, 0x70])),
                    ("moov", Data([0x6D, 0x6F, 0x6F, 0x76])),
                    ("mdat", Data([0x6D, 0x64, 0x61, 0x74])),
                ]
                
                for (name, signature) in signatures {
                    if remainingData.range(of: signature) != nil {
                        print("   ✅ 找到\(name)标识")
                    }
                }
                
                // 显示剩余数据的前64字节
                let previewSize = min(64, remainingSize)
                let previewData = remainingData.prefix(previewSize)
                
                print("\n📋 剩余数据预览(前\(previewSize)字节):")
                var hexString = ""
                for byte in previewData {
                    hexString += String(format: "%02X ", byte)
                }
                print("   \(hexString)")
                
            } else {
                print("❌ 没有足够的剩余数据，可能不包含视频")
            }
        } else {
            print("❌ 未找到JPEG结束标记")
        }
    }
}

// MARK: - Main Execution

func main() {
    let arguments = CommandLine.arguments
    
    if arguments.count < 2 {
        print("使用方法: swift quick_check.swift <文件路径>")
        return
    }
    
    let filePath = arguments[1]
    QuickFileCheck.quickCheck(filePath: filePath)
}

main()