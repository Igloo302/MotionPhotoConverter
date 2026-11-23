//
//  MotionPhotoProcessor.swift
//  Motion2Live
//
//  Multi-Brand Motion Photo Processing Architecture.
//  Supports Xiaomi, Google Pixel, Samsung Galaxy, Huawei/Honor, OPPO/OnePlus/Realme, vivo/iQOO, and Universal Android Motion Photos.
//

import Foundation
import UIKit
import ImageIO

// MARK: - Motion Photo Brand Enum
enum MotionPhotoBrand: String, CaseIterable {
    case xiaomi = "Xiaomi"
    case pixel = "Pixel"
    case samsung = "Samsung"
    case huawei = "华为 / 荣耀"
    case oppo = "OPPO / 一加"
    case vivo = "vivo / iQOO"
    case universal = "通用动态照片"
    case unknown = "未知格式"

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

// MARK: - Pre-parsed Probe Context (Avoids repeated EXIF & binary scans)
final class MotionPhotoProbeContext {
    let xmpInfo: [String: String]
    let data: Data?

    private var cachedMakeAndModel: (make: String, model: String)?
    private var hasComputedMP4Offset = false
    private var cachedMP4Offset: Int?
    private var hasComputedSamsungSEF = false
    private var cachedSamsungSEF = false

    init(xmpInfo: [String: String], data: Data?) {
        self.xmpInfo = xmpInfo
        self.data = data
    }

    var exifMakeAndModel: (make: String, model: String) {
        if let cached = cachedMakeAndModel {
            return cached
        }
        let result: (make: String, model: String)
        if let data = data {
            result = ISOBMFFHelper.extractExifMakeAndModel(from: data)
        } else {
            result = ("", "")
        }
        cachedMakeAndModel = result
        return result
    }

    var exifMake: String { exifMakeAndModel.make }
    var exifModel: String { exifMakeAndModel.model }

    var mp4Offset: Int? {
        if hasComputedMP4Offset {
            return cachedMP4Offset
        }
        hasComputedMP4Offset = true
        if let data = data {
            cachedMP4Offset = ISOBMFFHelper.findMP4Offset(in: data)
        }
        return cachedMP4Offset
    }

    var hasSamsungSEFMarker: Bool {
        if hasComputedSamsungSEF {
            return cachedSamsungSEF
        }
        hasComputedSamsungSEF = true
        if let data = data {
            cachedSamsungSEF = data.range(of: ISOBMFFHelper.samsungSEFSignature) != nil
        }
        return cachedSamsungSEF
    }
}

// MARK: - Motion Photo Processor Protocol
protocol MotionPhotoProcessorProtocol {
    var brand: MotionPhotoBrand { get }

    /// 检测是否为该品牌的动态照片 (兼顾仅传 XMP 的旧签名)
    func canProcess(xmpInfo: [String: String]) -> Bool

    /// 检测是否为该品牌的动态照片 (同时结合二进制数据与 EXIF)
    func canProcess(xmpInfo: [String: String], data: Data?) -> Bool

    /// 使用预解析上下文检测，避免重复 EXIF 与全文件扫描
    func canProcess(context: MotionPhotoProbeContext) -> Bool

    /// 处理动态照片数据
    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult

    /// 计算静态图片时间
    func calculateStillImageTime(videoDuration: Double, presentationTimestamp: Double?, frameRate: Double) -> Int
}

// MARK: - ISOBMFF Helper
struct ISOBMFFHelper {
    static let ftypSignature = Data("ftyp".utf8)
    static let samsungSEFSignature = Data("MotionPhoto_Data".utf8)

    private static let exifDateFormatterLock = NSLock()
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    private static let exifDateWithOffsetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// 检查给定偏移处是否为合法的 MP4 `ftyp` Box
    static func hasFtypSignature(in data: Data, at videoStart: Int) -> Bool {
        guard videoStart >= 0, videoStart + 8 <= data.count else { return false }
        return data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return false }
            let ptr = base.advanced(by: videoStart + 4).assumingMemoryBound(to: UInt8.self)
            return ptr[0] == 0x66 && ptr[1] == 0x74 && ptr[2] == 0x79 && ptr[3] == 0x70 // "ftyp"
        }
    }

    /// 在二进制数据中扫描 MP4/MOV 容器起始偏移量 (4字节长度 + "ftyp")
    static func findMP4Offset(in data: Data) -> Int? {
        let totalCount = data.count
        guard totalCount > 10240 else { return nil }

        // 从文件前 5% 或 16KB 开始搜索，避开图片头部 EXIF/XMP 区域
        let startSearch = min(16384, totalCount / 20)
        var searchRange = startSearch..<totalCount
        var candidateOffsets: [Int] = []

        data.withUnsafeBytes { rawBuffer in
            while let range = data.range(of: ftypSignature, in: searchRange) {
                let boxStart = range.lowerBound - 4
                if boxStart >= 0 && boxStart + 12 <= totalCount {
                    let boxSize = rawBuffer.loadUnaligned(fromByteOffset: boxStart, as: UInt32.self).bigEndian
                    let brandStart = range.upperBound
                    var isPrintableBrand = true
                    for offset in 0..<4 {
                        let byte = rawBuffer[brandStart + offset]
                        if byte < 0x20 || byte > 0x7E {
                            isPrintableBrand = false
                            break
                        }
                    }

                    if boxSize >= 16 && boxSize <= 4096 && isPrintableBrand {
                        let videoLen = totalCount - boxStart
                        if videoLen >= 10000 {
                            candidateOffsets.append(boxStart)
                        }
                    }
                }

                let nextSearchStart = range.upperBound
                if nextSearchStart >= totalCount { break }
                searchRange = nextSearchStart..<totalCount
            }
        }

        // 返回最靠近文件主体视频流的偏移（通常是最后一个有效 MP4 容器）
        return candidateOffsets.last
    }

    /// 从图片数据中提取 EXIF 设备制造厂商与机型 (TIFF Make & Model)
    static func extractExifMakeAndModel(from data: Data) -> (make: String, model: String) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return ("", "")
        }
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let make = (tiff?[kCGImagePropertyTIFFMake as String] as? String)?.lowercased() ?? ""
        let model = (tiff?[kCGImagePropertyTIFFModel as String] as? String)?.lowercased() ?? ""
        return (make, model)
    }

    /// 从图片数据中提取拍摄原始时间 (EXIF DateTimeOriginal，兼容 OffsetTimeOriginal 时区)
    static func extractExifCreationDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }

        let offsetString = exif[kCGImagePropertyExifOffsetTimeOriginal as String] as? String

        exifDateFormatterLock.lock()
        defer { exifDateFormatterLock.unlock() }

        if let offsetString = offsetString, !offsetString.isEmpty,
           let dateWithOffset = exifDateWithOffsetFormatter.date(from: dateString + offsetString) {
            return dateWithOffset
        }
        return exifDateFormatter.date(from: dateString)
    }

    /// 测量从指定起始偏移开始的纯净 ISOBMFF/MP4 容器长度 (自动剥离末尾厂商私有 Trailer，如三星 SEF/SEFT)
    static func measurePureMP4Length(in data: Data, startingAt start: Int) -> Int? {
        let totalCount = data.count
        guard start >= 0 && start + 8 <= totalCount else { return nil }

        var pos = start
        var validBoxFound = false

        data.withUnsafeBytes { rawBuffer in
            while pos + 8 <= totalCount {
                let boxSize32 = rawBuffer.loadUnaligned(fromByteOffset: pos, as: UInt32.self).bigEndian

                // 验证 box 类型是否为合法的 4 字节 ASCII 标识 (如 ftyp, mdat, moov, free, meta 等)
                var isAlphaNumericType = true
                for offset in 4..<8 {
                    let b = rawBuffer[pos + offset]
                    let valid = (b >= 0x61 && b <= 0x7A) || (b >= 0x41 && b <= 0x5A) || (b >= 0x30 && b <= 0x39) || b == 0x5F || b == 0x20
                    if !valid {
                        isAlphaNumericType = false
                        break
                    }
                }
                guard isAlphaNumericType else { break }

                var boxTotalSize: Int = 0
                if boxSize32 == 1 {
                    // 64 位超大 Box
                    guard pos + 16 <= totalCount else { break }
                    let boxSize64 = rawBuffer.loadUnaligned(fromByteOffset: pos + 8, as: UInt64.self).bigEndian
                    guard boxSize64 >= 16 && boxSize64 <= UInt64(totalCount - pos) else { break }
                    boxTotalSize = Int(boxSize64)
                } else if boxSize32 == 0 {
                    // Box 一路延伸至文件结尾
                    validBoxFound = true
                    pos = totalCount
                    break
                } else {
                    guard boxSize32 >= 8 else { break }
                    boxTotalSize = Int(boxSize32)
                }

                guard pos + boxTotalSize <= totalCount else { break }
                validBoxFound = true
                pos += boxTotalSize
            }
        }

        guard validBoxFound else { return nil }
        let measuredLength = pos - start
        return measuredLength >= 10000 ? measuredLength : nil
    }
}

// MARK: - Base Motion Photo Processor
class BaseMotionPhotoProcessor: MotionPhotoProcessorProtocol {
    let brand: MotionPhotoBrand

    init(brand: MotionPhotoBrand) {
        self.brand = brand
    }

    func canProcess(xmpInfo: [String: String]) -> Bool {
        return canProcess(xmpInfo: xmpInfo, data: nil)
    }

    func canProcess(xmpInfo: [String: String], data: Data?) -> Bool {
        return canProcess(context: MotionPhotoProbeContext(xmpInfo: xmpInfo, data: data))
    }

    func canProcess(context: MotionPhotoProbeContext) -> Bool {
        return false
    }

    func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "Not implemented")
    }

    func calculateStillImageTime(videoDuration: Double, presentationTimestamp: Double?, frameRate: Double) -> Int {
        guard videoDuration.isFinite, videoDuration > 0 else { return 0 }
        let photoTime: Double
        if let timestamp = presentationTimestamp, timestamp.isFinite, timestamp > 0 {
            photoTime = timestamp / 1_000_000.0
        } else {
            // 默认取视频中间帧 (适用于华为/vivo/OPPO等未硬编码时间戳的实况照片)
            photoTime = videoDuration / 2.0
        }
        let frameRateVal = (frameRate.isFinite && frameRate > 0) ? frameRate : 30.0
        let frameTime = 1.0 / frameRateVal
        let frameNumber = Int(round(photoTime / frameTime))
        let totalFrames = Int(round(videoDuration * frameRateVal))
        // 限制在 0...127，防止 QuickTime still-image-time (int8) 产生溢出
        return max(0, min(127, min(frameNumber, max(0, totalFrames - 1))))
    }

    /// 统一构建切分好的数据包
    func createResult(data: Data, videoStartOffset: Int, presentationTimestamp: Double?) -> MotionPhotoProcessingResult {
        guard videoStartOffset > 0 && videoStartOffset < data.count else {
            return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "无效的视频起始偏移量")
        }
        let imageData = data.prefix(videoStartOffset)
        let pureLength = ISOBMFFHelper.measurePureMP4Length(in: data, startingAt: videoStartOffset) ?? (data.count - videoStartOffset)
        let videoData = data.subdata(in: videoStartOffset..<(videoStartOffset + pureLength))

        guard videoData.count >= 10000 else {
            return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "提取的视频数据长度不足")
        }

        let motionPhotoData = MotionPhotoData(
            imageData: imageData,
            videoData: videoData,
            stillImageTime: 0,
            brand: self.brand,
            videoOffset: videoStartOffset,
            presentationTimestamp: presentationTimestamp
        )
        return MotionPhotoProcessingResult(success: true, data: motionPhotoData, errorMessage: nil)
    }
}

// MARK: - Xiaomi Motion Photo Processor
class XiaomiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() { super.init(brand: .xiaomi) }

    override func canProcess(context: MotionPhotoProbeContext) -> Bool {
        if context.xmpInfo["GCamera:MicroVideoOffset"] != nil || context.xmpInfo["GCamera:MicroVideo"] == "1" {
            return true
        }
        let make = context.exifMake
        if (make.contains("xiaomi") || make.contains("redmi") || make.contains("poco")) && context.mp4Offset != nil {
            return true
        }
        return false
    }

    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        let timestampString = xmpInfo["GCamera:MicroVideoPresentationTimestampUs"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }

        // 优先根据 MicroVideoOffset 计算并校验 ftyp
        if let microVideoOffsetString = xmpInfo["GCamera:MicroVideoOffset"],
           let offset = Int(microVideoOffsetString), offset > 0, offset < data.count {
            let videoStart = data.count - offset
            if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
            }
        }

        // Fallback: 二进制扫描 MP4 头 (Ultra HDR 多图层混排兼容)
        if let videoStart = ISOBMFFHelper.findMP4Offset(in: data) {
            return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
        }

        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "无法解析小米动态照片的视频偏移量")
    }
}

// MARK: - Samsung Motion Photo Processor
class SamsungMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() { super.init(brand: .samsung) }

    override func canProcess(context: MotionPhotoProbeContext) -> Bool {
        // 1. 三星专有的 SEF 尾部标识 (MotionPhoto_Data)
        if context.hasSamsungSEFMarker {
            return true
        }

        // 2. 三星非零 padding (如 "138, 0" 或 Item:Padding="138")
        if let padding = context.xmpInfo["Directory Item Padding"], padding != "0, 0" && padding != "0" {
            return true
        }
        if let itemPadding = context.xmpInfo["Item:Padding"], itemPadding != "0" {
            return true
        }

        // 3. EXIF 制造商 / 型号识别
        let make = context.exifMake
        if (make.contains("samsung") || make.contains("sec")) && context.mp4Offset != nil {
            return true
        }
        return false
    }

    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        let timestampString = xmpInfo["Motion Photo Presentation Timestamp Us"] ?? xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }

        // 1. 处理 Directory Item Length (格式: "0, 5421673" 或 "imageLen, videoLen")
        if let lengthString = xmpInfo["Directory Item Length"] {
            let parts = lengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, let videoLength = Int(parts[1]), videoLength > 0, videoLength < data.count {
                let videoStart = data.count - videoLength
                if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                    return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
                }
            }
        }

        // 2. 处理 Item:Length
        if let itemLengthStr = xmpInfo["Item:Length"] ?? xmpInfo["GContainer:ItemLength"],
           let videoLength = Int(itemLengthStr), videoLength > 0, videoLength < data.count {
            let videoStart = data.count - videoLength
            if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
            }
        }

        // 3. Fallback: 二进制查找 MP4 头
        if let videoStart = ISOBMFFHelper.findMP4Offset(in: data) {
            return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
        }

        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "无法在三星动态照片中找到视频数据")
    }
}

// MARK: - Pixel Motion Photo Processor
class PixelMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() { super.init(brand: .pixel) }

    override func canProcess(context: MotionPhotoProbeContext) -> Bool {
        // 排除三星专有标识
        if context.hasSamsungSEFMarker {
            return false
        }
        let make = context.exifMake
        if make.contains("samsung") || make.contains("sec") {
            return false
        }
        if make.contains("google") && context.mp4Offset != nil {
            return true
        }

        if let padding = context.xmpInfo["Directory Item Padding"], padding != "0, 0" && padding != "0" {
            return false
        }

        // Pixel v1 & v2 XMP markers
        if context.xmpInfo["GCamera:MotionPhoto"] == "1" || context.xmpInfo["GContainer:ItemLength"] != nil || context.xmpInfo["GCamera:MicroVideoOffset"] != nil {
            return true
        }
        return false
    }

    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"] ?? xmpInfo["Motion Photo Presentation Timestamp Us"] ?? xmpInfo["GCamera:MicroVideoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }

        // 1. Directory Item Length (Pixel v2 规范: "0, 1619843")
        if let lengthString = xmpInfo["Directory Item Length"] {
            let parts = lengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, let videoLength = Int(parts[1]), videoLength > 0, videoLength < data.count {
                let videoStart = data.count - videoLength
                if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                    return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
                }
            }
        }

        // 2. GContainer:ItemLength / Item:Length
        if let lengthString = xmpInfo["GContainer:ItemLength"] ?? xmpInfo["Item:Length"],
           let videoLength = Int(lengthString), videoLength > 0, videoLength < data.count {
            let videoStart = data.count - videoLength
            if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
            }
        }

        // 3. GCamera:MicroVideoOffset (Pixel v1 规范)
        if let offsetStr = xmpInfo["GCamera:MicroVideoOffset"],
           let offset = Int(offsetStr), offset > 0, offset < data.count {
            let videoStart = data.count - offset
            if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
            }
        }

        // 4. Fallback: 二进制扫描 MP4 头
        if let videoStart = ISOBMFFHelper.findMP4Offset(in: data) {
            return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
        }

        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "无法解析 Pixel 动态照片的视频数据")
    }
}

// MARK: - Huawei / Honor Motion Photo Processor
class HuaweiMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() { super.init(brand: .huawei) }

    override func canProcess(context: MotionPhotoProbeContext) -> Bool {
        if context.xmpInfo["HwCamera:MovingPicture"] == "1" || context.xmpInfo["v6_f"] != nil || context.xmpInfo["MovingPhoto"] != nil {
            return true
        }
        let make = context.exifMake
        if (make.contains("huawei") || make.contains("honor")) && context.mp4Offset != nil {
            return true
        }
        return false
    }

    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        // 华为/荣耀实况照片通常为 JPEG 尾部紧跟 MP4 容器结构
        if let videoStart = ISOBMFFHelper.findMP4Offset(in: data) {
            return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: nil)
        }
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "无法提取华为/荣耀实况照片中的视频流")
    }
}

// MARK: - OPPO / OnePlus / Realme Motion Photo Processor
class OppoMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() { super.init(brand: .oppo) }

    override func canProcess(context: MotionPhotoProbeContext) -> Bool {
        if context.xmpInfo["OPPO:LivePhoto"] != nil || context.xmpInfo["O-Live"] != nil {
            return true
        }
        let make = context.exifMake
        if (make.contains("oppo") || make.contains("oneplus") || make.contains("realme")) && context.mp4Offset != nil {
            return true
        }
        return false
    }

    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"] ?? xmpInfo["GCamera:MicroVideoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }

        if let offsetStr = xmpInfo["GCamera:MicroVideoOffset"], let offset = Int(offsetStr), offset > 0, offset < data.count {
            let videoStart = data.count - offset
            if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
            }
        }

        if let lengthString = xmpInfo["Directory Item Length"] {
            let parts = lengthString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, let videoLength = Int(parts[1]), videoLength > 0, videoLength < data.count {
                let videoStart = data.count - videoLength
                if ISOBMFFHelper.hasFtypSignature(in: data, at: videoStart) {
                    return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
                }
            }
        }

        if let videoStart = ISOBMFFHelper.findMP4Offset(in: data) {
            return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
        }
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "无法提取 OPPO/一加实况照片中的视频流")
    }
}

// MARK: - vivo / iQOO Motion Photo Processor
class VivoMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() { super.init(brand: .vivo) }

    override func canProcess(context: MotionPhotoProbeContext) -> Bool {
        if context.xmpInfo["vivo:LivePhoto"] != nil || context.xmpInfo["LivePhoto"] != nil {
            return true
        }
        let make = context.exifMake
        if (make.contains("vivo") || make.contains("iqoo")) && context.mp4Offset != nil {
            return true
        }
        return false
    }

    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }

        if let videoStart = ISOBMFFHelper.findMP4Offset(in: data) {
            return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
        }
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "无法提取 vivo/iQOO 实况照片中的视频流")
    }
}

// MARK: - Universal Android Motion Photo Processor (Fallback)
class UniversalMotionPhotoProcessor: BaseMotionPhotoProcessor {
    init() { super.init(brand: .universal) }

    override func canProcess(context: MotionPhotoProbeContext) -> Bool {
        return context.mp4Offset != nil
    }

    override func processMotionPhoto(data: Data, xmpInfo: [String: String]) -> MotionPhotoProcessingResult {
        let timestampString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"] ?? xmpInfo["GCamera:MicroVideoPresentationTimestampUs"]
        let presentationTimestamp = timestampString.flatMap { Double($0) }

        if let videoStart = ISOBMFFHelper.findMP4Offset(in: data) {
            return createResult(data: data, videoStartOffset: videoStart, presentationTimestamp: presentationTimestamp)
        }
        return MotionPhotoProcessingResult(success: false, data: nil, errorMessage: "未能在照片数据中定位内嵌视频")
    }
}

// MARK: - Motion Photo Processor Factory
class MotionPhotoProcessorFactory {
    private static let brandProcessors: [BaseMotionPhotoProcessor] = [
        XiaomiMotionPhotoProcessor(),
        SamsungMotionPhotoProcessor(),
        PixelMotionPhotoProcessor(),
        HuaweiMotionPhotoProcessor(),
        OppoMotionPhotoProcessor(),
        VivoMotionPhotoProcessor()
    ]
    private static let universalProcessor = UniversalMotionPhotoProcessor()

    static func getProcessor(for xmpInfo: [String: String], data: Data? = nil) -> MotionPhotoProcessorProtocol? {
        let context = MotionPhotoProbeContext(xmpInfo: xmpInfo, data: data)

        // 1. 优先匹配厂商专用处理器（共享单次解析的 EXIF 与 MP4 偏移上下文）
        if let matched = brandProcessors.first(where: { $0.canProcess(context: context) }) {
            return matched
        }
        // 2. 通用兜底：任何包含有效内嵌 MP4 视频流的照片
        if universalProcessor.canProcess(context: context) {
            return universalProcessor
        }
        return nil
    }

    static func getProcessor(for data: Data, xmpInfo: [String: String] = [:]) -> MotionPhotoProcessorProtocol? {
        return getProcessor(for: xmpInfo, data: data)
    }

    static func getAllSupportedBrands() -> [MotionPhotoBrand] {
        return [
            .xiaomi,
            .pixel,
            .samsung,
            .huawei,
            .oppo,
            .vivo,
            .universal
        ]
    }
}
