//
//  MotionPhotoStructureAnalyzer.swift
//  Motion2Live
//
//  Read-only byte-level container analyzer and metadata report builder for Motion Photos.
//  Strictly validates all slice boundaries and never mutates or persists source media.
//

import Foundation
import AVFoundation
import CoreMedia
import ImageIO

// MARK: - Data Models

enum MotionPhotoSegmentKind: String, CaseIterable, Sendable {
    case primaryImage   // JPEG / HEIC
    case gainMap        // Ultra HDR GainMap JPEG
    case video          // ISOBMFF MP4
    case sefTrailer     // Samsung SEF / SEFT
    case unknownTrailer // 其他尾部填充或私有块
}

struct MotionPhotoByteSegment: Identifiable, Equatable, Sendable {
    let id: String
    let kind: MotionPhotoSegmentKind
    let label: String           // e.g. "JPEG", "HEIC", "GainMap", "MP4", "SEF"
    let byteOffset: Int
    let byteCount: Int
    let totalBytes: Int

    var percentage: Double {
        guard totalBytes > 0, byteCount > 0 else { return 0 }
        return (Double(byteCount) / Double(totalBytes)) * 100.0
    }
}

struct MotionPhotoVideoSpecs: Equatable, Sendable {
    let codecName: String       // e.g. "HEVC (hvc1)", "H.264 (avc1)"
    let width: Int
    let height: Int
    let frameRate: Double
    let durationSeconds: Double
}

struct MotionPhotoXMPField: Identifiable, Equatable, Sendable {
    var id: String { key }
    let key: String
    let value: String
}

struct MotionPhotoInspectionReport: Equatable, Sendable {
    let totalBytes: Int
    let brand: MotionPhotoBrand
    let exifMake: String
    let exifModel: String
    let segments: [MotionPhotoByteSegment]
    let xmpFields: [MotionPhotoXMPField]
    var videoSpecs: MotionPhotoVideoSpecs?

    /// 生成用于剪贴板的纯文本技术摘要（不含任何本地路径）
    func formattedSummary() -> String {
        var lines: [String] = []
        lines.append("Motion2Live · File Structure")
        lines.append("Size: \(MotionPhotoStructureAnalyzer.formatByteCount(totalBytes)) (\(totalBytes) B)")

        let deviceSummary = formattedBrandAndDevice
        if !deviceSummary.isEmpty {
            lines.append("Device: \(deviceSummary)")
        }

        if !segments.isEmpty {
            lines.append("")
            lines.append("[Container Segments]")
            for segment in segments {
                let sizeText = MotionPhotoStructureAnalyzer.formatByteCount(segment.byteCount)
                let pctText = MotionPhotoStructureAnalyzer.formatPercentage(segment.percentage)
                lines.append("- \(segment.label): \(sizeText) (\(pctText)) @ \(segment.byteOffset)")
            }
        }

        if let specs = videoSpecs {
            lines.append("")
            lines.append("[Video Track]")
            lines.append("- Codec: \(specs.codecName)")
            if specs.width > 0 && specs.height > 0 {
                lines.append("- Resolution: \(specs.width) x \(specs.height)")
            }
            if specs.frameRate > 0 {
                lines.append(String(format: "- Frame Rate: %.2f fps", specs.frameRate))
            }
            if specs.durationSeconds > 0 {
                lines.append(String(format: "- Duration: %.2f s", specs.durationSeconds))
            }
        }

        if !xmpFields.isEmpty {
            lines.append("")
            lines.append("[XMP Metadata]")
            for field in xmpFields {
                lines.append("- \(field.key): \(field.value)")
            }
        }

        return lines.joined(separator: "\n")
    }

    var formattedBrandAndDevice: String {
        let model = exifModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let make = exifMake.trimmingCharacters(in: .whitespacesAndNewlines)
        let device: String
        if !model.isEmpty && !make.isEmpty {
            device = model.localizedCaseInsensitiveContains(make) ? model : "\(make) \(model)"
        } else {
            device = model.isEmpty ? make : model
        }
        if device.isEmpty {
            return brand.displayName
        }
        return "\(brand.displayName) · \(device)"
    }
}

// MARK: - Read-Only Analyzer

enum MotionPhotoStructureAnalyzer {
    private static let sefMarkers: [Data] = [
        ISOBMFFHelper.samsungSEFSignature,
        Data("SEFH".utf8),
        Data("SEFT".utf8)
    ]

    private static let heicBrands: Set<String> = [
        "heic", "heix", "hevc", "hevx", "mif1", "msf1"
    ]

    private static let prioritizedXMPKeys: [String] = [
        "GCamera:MotionPhoto",
        "GCamera:MotionPhotoVersion",
        "GCamera:MotionPhotoPresentationTimestampUs",
        "Motion Photo Presentation Timestamp Us",
        "GCamera:MicroVideo",
        "GCamera:MicroVideoVersion",
        "GCamera:MicroVideoOffset",
        "GCamera:MicroVideoPresentationTimestampUs",
        "Item:Length",
        "GContainer:ItemLength",
        "Directory Item Length",
        "Item:Padding",
        "Directory Item Padding",
        "Item:Mime",
        "Item:Semantic",
        "HwCamera:MovingPicture",
        "OPPO:LivePhoto",
        "vivo:LivePhoto",
        "hdrgm:Version"
    ]

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.includesUnit = true
        return formatter
    }()

    static func formatByteCount(_ bytes: Int) -> String {
        let clamped = max(0, bytes)
        if clamped < 1024 {
            return "\(clamped) B"
        }
        return byteFormatter.string(fromByteCount: Int64(clamped))
    }

    static func formatPercentage(_ percentage: Double) -> String {
        if percentage <= 0 {
            return "0%"
        }
        if percentage < 1.0 {
            return "<1%"
        }
        return "\(Int(percentage.rounded()))%"
    }

    /// 构建只读容器结构与元数据报告（不持有原始大文件 Data）
    static func analyze(
        data: Data,
        xmpInfo: [String: String],
        extracted: MotionPhotoData
    ) -> MotionPhotoInspectionReport {
        let totalBytes = data.count
        let exif = ISOBMFFHelper.extractDisplayExifMakeAndModel(from: data)
        let xmpFields = orderedXMPFields(from: xmpInfo)

        guard totalBytes > 0 else {
            return MotionPhotoInspectionReport(
                totalBytes: 0,
                brand: extracted.brand,
                exifMake: exif.make,
                exifModel: exif.model,
                segments: [],
                xmpFields: xmpFields,
                videoSpecs: nil
            )
        }

        let resolvedVideoStart = resolveVideoStart(in: data, extracted: extracted)
        var segments: [MotionPhotoByteSegment] = []

        if let videoStart = resolvedVideoStart, videoStart >= 0, videoStart <= totalBytes {
            // 1. 前置图像区 0..<videoStart
            if videoStart > 0 {
                segments.append(contentsOf: analyzeImageRegion(in: data, endOffset: videoStart, totalBytes: totalBytes, xmpInfo: xmpInfo))
            }

            // 2. 内嵌视频流区 videoStart..<videoEnd
            let fallbackVideoLen = min(extracted.videoData.count, totalBytes - videoStart)
            let pureVideoLen = ISOBMFFHelper.measurePureMP4Length(in: data, startingAt: videoStart) ?? fallbackVideoLen
            let clampedVideoLen = max(0, min(pureVideoLen, totalBytes - videoStart))
            let videoEnd = videoStart + clampedVideoLen

            if clampedVideoLen > 0 {
                segments.append(
                    MotionPhotoByteSegment(
                        id: "video-\(videoStart)",
                        kind: .video,
                        label: "MP4",
                        byteOffset: videoStart,
                        byteCount: clampedVideoLen,
                        totalBytes: totalBytes
                    )
                )
            }

            // 3. 尾部区块 videoEnd..<totalBytes
            let trailerLen = totalBytes - videoEnd
            if trailerLen > 0 {
                let trailerSlice = data.subdata(in: (data.startIndex + videoEnd)..<data.endIndex)
                let isSEF = sefMarkers.contains { trailerSlice.range(of: $0) != nil }
                segments.append(
                    MotionPhotoByteSegment(
                        id: "trailer-\(videoEnd)",
                        kind: isSEF ? .sefTrailer : .unknownTrailer,
                        label: isSEF ? "SEF" : "Trailer",
                        byteOffset: videoEnd,
                        byteCount: trailerLen,
                        totalBytes: totalBytes
                    )
                )
            }
        } else {
            // 未定位到合法 MP4 起始偏移时的边界安全降级
            segments.append(
                MotionPhotoByteSegment(
                    id: "primary-0",
                    kind: .primaryImage,
                    label: primaryImageLabel(for: data),
                    byteOffset: 0,
                    byteCount: totalBytes,
                    totalBytes: totalBytes
                )
            )
        }

        return MotionPhotoInspectionReport(
            totalBytes: totalBytes,
            brand: extracted.brand,
            exifMake: exif.make,
            exifModel: exif.model,
            segments: segments,
            xmpFields: xmpFields,
            videoSpecs: nil
        )
    }

    /// 从已创建的 AVAsset 异步提取视频流技术规格（零额外磁盘 I/O）
    static func extractVideoSpecs(from asset: AVAsset) async -> MotionPhotoVideoSpecs? {
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let safeDuration = (durationSeconds.isFinite && durationSeconds > 0) ? durationSeconds : 0

            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return MotionPhotoVideoSpecs(
                    codecName: "—",
                    width: 0,
                    height: 0,
                    frameRate: 0,
                    durationSeconds: safeDuration
                )
            }

            let formatDescriptions = try await track.load(.formatDescriptions)
            let naturalSize = try await track.load(.naturalSize)
            let preferredTransform = try await track.load(.preferredTransform)
            let nominalFrameRate = try await track.load(.nominalFrameRate)

            let transformedSize = naturalSize.applying(preferredTransform)
            let width = Int(abs(transformedSize.width).rounded())
            let height = Int(abs(transformedSize.height).rounded())
            let fps = Double(nominalFrameRate)
            let codecName = formatDescriptions.first.map(formatCodecName) ?? "—"

            return MotionPhotoVideoSpecs(
                codecName: codecName,
                width: width,
                height: height,
                frameRate: (fps.isFinite && fps > 0) ? fps : 0,
                durationSeconds: safeDuration
            )
        } catch {
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func resolveVideoStart(in data: Data, extracted: MotionPhotoData) -> Int? {
        if let offset = extracted.videoOffset,
           offset >= 0,
           offset < data.count,
           ISOBMFFHelper.hasFtypSignature(in: data, at: offset) {
            return offset
        }
        return ISOBMFFHelper.findMP4Offset(in: data)
    }

    private static func primaryImageLabel(for data: Data) -> String {
        if ISOBMFFHelper.isJPEG(data: data) {
            return "JPEG"
        }
        if isHEICContainer(data: data) {
            return "HEIC"
        }
        return "Image"
    }

    private static func isHEICContainer(data: Data) -> Bool {
        guard ISOBMFFHelper.hasFtypSignature(in: data, at: 0), data.count >= 12 else {
            return false
        }
        let brandData = data.subdata(in: (data.startIndex + 8)..<(data.startIndex + 12))
        let brand = String(data: brandData, encoding: .ascii)?.lowercased() ?? ""
        return heicBrands.contains(brand)
    }

    private static func analyzeImageRegion(
        in data: Data,
        endOffset: Int,
        totalBytes: Int,
        xmpInfo: [String: String]
    ) -> [MotionPhotoByteSegment] {
        guard endOffset > 0, endOffset <= data.count else { return [] }

        let imageLabel = primaryImageLabel(for: data)
        if imageLabel == "JPEG",
           let gainMapStart = findGainMapJPEGOffset(in: data, endOffset: endOffset, xmpInfo: xmpInfo),
           gainMapStart > 0,
           gainMapStart < endOffset {
            return [
                MotionPhotoByteSegment(
                    id: "primary-0",
                    kind: .primaryImage,
                    label: "JPEG",
                    byteOffset: 0,
                    byteCount: gainMapStart,
                    totalBytes: totalBytes
                ),
                MotionPhotoByteSegment(
                    id: "gainmap-\(gainMapStart)",
                    kind: .gainMap,
                    label: "GainMap",
                    byteOffset: gainMapStart,
                    byteCount: endOffset - gainMapStart,
                    totalBytes: totalBytes
                )
            ]
        }

        return [
            MotionPhotoByteSegment(
                id: "primary-0",
                kind: .primaryImage,
                label: imageLabel,
                byteOffset: 0,
                byteCount: endOffset,
                totalBytes: totalBytes
            )
        ]
    }

    /// 在 `0..<endOffset` 内沿 JPEG 段结构定位主图 EOI 之后的次级 GainMap JPEG 起始偏移
    private static func findGainMapJPEGOffset(
        in data: Data,
        endOffset: Int,
        xmpInfo: [String: String]
    ) -> Int? {
        guard endOffset > 4, ISOBMFFHelper.isJPEG(data: data) else { return nil }

        guard let primaryEnd = findPrimaryJPEGEOI(in: data, limit: endOffset),
              primaryEnd < endOffset else {
            return nil
        }

        // 查找主图 EOI 之后紧随的次级 JPEG SOI (0xFF 0xD8)
        var candidate = primaryEnd
        while candidate + 1 < endOffset {
            let byte = data[data.startIndex + candidate]
            if byte == 0xFF {
                let nextByte = data[data.startIndex + candidate + 1]
                if nextByte == 0xD8 {
                    // 确认确实为 GainMap（ImageIO 辅助图元数据、XMP 声明或标准次级 JPEG）
                    if hasHDRGainMapAuxiliaryData(in: data) || hasGainMapXMPIndicator(xmpInfo) || (endOffset - candidate >= 4) {
                        return candidate
                    }
                    return nil
                }
                break
            } else if byte == 0x00 {
                candidate += 1
            } else {
                break
            }
        }
        return nil
    }

    /// 沿 JPEG Marker 结构步进至主图 EOI 结束位置（跳过 APP1/EXIF 内部缩略图，避免误判）
    private static func findPrimaryJPEGEOI(in data: Data, limit: Int) -> Int? {
        guard limit >= 4 else { return nil }
        let base = data.startIndex
        var pos = 2 // 跳过初始 SOI (0xFF 0xD8)

        while pos + 1 < limit {
            // 跳过填充字节 0xFF
            while pos < limit && data[base + pos] == 0xFF {
                pos += 1
            }
            guard pos < limit else { return nil }
            let marker = data[base + pos]
            pos += 1

            if marker == 0xD9 { // EOI
                return pos
            }
            if marker == 0x00 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0xD8 {
                continue
            }

            if marker == 0xDA { // SOS (Start of Scan): 扫描压缩图像数据直到真正 EOI (0xFF 0xD9)
                while pos + 1 < limit {
                    if data[base + pos] == 0xFF {
                        let next = data[base + pos + 1]
                        if next == 0xD9 {
                            return pos + 2
                        }
                        if next == 0x00 || (next >= 0xD0 && next <= 0xD7) || next == 0xFF {
                            pos += 2
                            continue
                        }
                    }
                    pos += 1
                }
                return nil
            }

            // 普通带长度段 (2 字节大端长度，含长度字段本身)
            guard pos + 2 <= limit else { return nil }
            let segLen = (Int(data[base + pos]) << 8) | Int(data[base + pos + 1])
            guard segLen >= 2, pos + segLen <= limit else { return nil }
            pos += segLen
        }
        return nil
    }

    private static func hasHDRGainMapAuxiliaryData(in data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeHDRGainMap) != nil
    }

    private static func hasGainMapXMPIndicator(_ xmpInfo: [String: String]) -> Bool {
        xmpInfo.contains { key, value in
            key.localizedCaseInsensitiveContains("GainMap")
                || key.localizedCaseInsensitiveContains("hdrgm")
                || value.localizedCaseInsensitiveContains("GainMap")
        }
    }

    private static func orderedXMPFields(from xmpInfo: [String: String]) -> [MotionPhotoXMPField] {
        var seen = Set<String>()
        var result: [MotionPhotoXMPField] = []

        func appendIfValid(key: String, value: String) {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedVal = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty,
                  !trimmedVal.isEmpty,
                  !trimmedKey.hasPrefix("xmlns:"),
                  !seen.contains(trimmedKey) else {
                return
            }
            seen.insert(trimmedKey)
            result.append(MotionPhotoXMPField(key: trimmedKey, value: trimmedVal))
        }

        for key in prioritizedXMPKeys {
            if let value = xmpInfo[key] {
                appendIfValid(key: key, value: value)
            }
        }

        for key in xmpInfo.keys.sorted() {
            if let value = xmpInfo[key] {
                appendIfValid(key: key, value: value)
            }
        }

        return result
    }

    private static func formatCodecName(_ description: CMFormatDescription) -> String {
        let subType = CMFormatDescriptionGetMediaSubType(description)
        let fourCC = fourCCString(subType)
        switch subType {
        case kCMVideoCodecType_HEVC:
            return "HEVC (\(fourCC))"
        case kCMVideoCodecType_H264:
            return "H.264 (\(fourCC))"
        case kCMVideoCodecType_MPEG4Video:
            return "MPEG-4 (\(fourCC))"
        case kCMVideoCodecType_JPEG:
            return "JPEG (\(fourCC))"
        default:
            if fourCC.isEmpty {
                return "—"
            }
            return fourCC
        }
    }

    private static func fourCCString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        let scalars = bytes.filter { $0 >= 0x20 && $0 <= 0x7E }.map { Character(UnicodeScalar($0)) }
        return String(scalars)
    }
}
