//
//  MotionPhotoEncoder.swift
//  Motion2Live
//
//  Encodes a still image + video pair into a single-file multi-brand Motion Photo (.jpg).
//  Supports Pixel, Xiaomi, Samsung SEF, Huawei, OPPO, vivo, and Universal formats.
//

import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum MotionPhotoEncodingError: LocalizedError {
    case unsupportedBrand
    case invalidImageSource
    case jpegEncodingFailed
    case videoRemuxFailed(Error?)
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedBrand:
            return Localizable.string(.invalidMotionPhotoOrUnsupportedFormat)
        case .invalidImageSource:
            return Localizable.string(.cannotCreateImageSource)
        case .jpegEncodingFailed:
            return Localizable.string(.imageConversionFailed)
        case .videoRemuxFailed(let underlying):
            return underlying?.localizedDescription ?? Localizable.string(.videoExportFailed)
        case .verificationFailed:
            return Localizable.string(.liveToMotionVerificationFailed)
        }
    }
}

enum MotionPhotoEncoder {
    static let supportedBrands: [MotionPhotoBrand] = MotionPhotoProcessorFactory.getAllSupportedBrands()

    private static let conflictingMakes = [
        "xiaomi", "redmi", "poco",
        "samsung", "sec",
        "google",
        "huawei", "honor",
        "oppo", "oneplus", "realme",
        "vivo", "iqoo"
    ]

    /// 将静态图与配对视频封装为指定品牌的单文件 Motion Photo (.jpg)
    static func encode(
        imageURL: URL,
        videoURL: URL,
        targetBrand: MotionPhotoBrand,
        creationDate: Date? = nil
    ) async throws -> Data {
        guard targetBrand != .unknown else {
            throw MotionPhotoEncodingError.unsupportedBrand
        }

        let rawImageData = try Data(contentsOf: imageURL, options: .mappedIfSafe)
        return try await encode(
            imageData: rawImageData,
            videoURL: videoURL,
            targetBrand: targetBrand,
            creationDate: creationDate
        )
    }

    static func encode(
        imageData rawImageData: Data,
        videoURL: URL,
        targetBrand: MotionPhotoBrand,
        creationDate: Date? = nil
    ) async throws -> Data {
        guard targetBrand != .unknown else {
            throw MotionPhotoEncodingError.unsupportedBrand
        }

        // 1. 归一化静态图为保留 EXIF/Orientation/GPS/色彩配置的 JPEG，并剥离冲突旧 XMP
        let cleanJPEG = try normalizeToCleanJPEG(
            rawImageData,
            targetBrand: targetBrand,
            creationDate: creationDate
        )

        // 2. 读取 still-image-time 微秒时间戳并无损混流为 .mp4
        let presentationTimestampUs = await readStillImageTimestampUs(from: videoURL)
        let mp4Data = try await remuxToMP4Data(from: videoURL)

        // 3. 按品牌注入 APP1 XMP 并拼装二进制容器
        let assembled = try assembleContainer(
            cleanJPEG: cleanJPEG,
            mp4Data: mp4Data,
            targetBrand: targetBrand,
            presentationTimestampUs: presentationTimestampUs
        )

        // 4. 输出前自校验
        try verifyEncodedMotionPhoto(assembled, expectedBrand: targetBrand)
        return assembled
    }

    // MARK: - Step 1: Image Normalization & XMP Stripping

    static func normalizeToCleanJPEG(
        _ rawData: Data,
        targetBrand: MotionPhotoBrand,
        creationDate: Date? = nil
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(rawData as CFData, nil),
              let sourceType = CGImageSourceGetType(source) as String? else {
            throw MotionPhotoEncodingError.invalidImageSource
        }

        let isAlreadyJPEG = sourceType == UTType.jpeg.identifier
        let props = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        let needsMakeStrip = shouldStripMake(from: props, targetBrand: targetBrand)
        let existingExifDate = ISOBMFFHelper.extractExifCreationDate(from: rawData)
        let needsDateInjection = (creationDate != nil && existingExifDate == nil)

        let jpegData: Data
        if isAlreadyJPEG && !needsMakeStrip && !needsDateInjection {
            jpegData = rawData
        } else {
            let outputData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                outputData as CFMutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                throw MotionPhotoEncodingError.jpegEncodingFailed
            }

            var destinationProperties: [String: Any] = [
                kCGImageDestinationLossyCompressionQuality as String: 0.95
            ]

            var tiff = (props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
            var exif = (props[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
            var tiffModified = false
            var exifModified = false

            if needsMakeStrip {
                if tiff[kCGImagePropertyTIFFMake as String] != nil {
                    tiff[kCGImagePropertyTIFFMake as String] = kCFNull
                    tiffModified = true
                }
                if exif[kCGImagePropertyExifLensMake as String] != nil {
                    exif[kCGImagePropertyExifLensMake as String] = kCFNull
                    exifModified = true
                }
            }

            if needsDateInjection, let creationDate = creationDate {
                let dateString = formatExifDateString(creationDate)
                if exif[kCGImagePropertyExifDateTimeOriginal as String] == nil {
                    exif[kCGImagePropertyExifDateTimeOriginal as String] = dateString
                    exifModified = true
                }
                if exif[kCGImagePropertyExifDateTimeDigitized as String] == nil {
                    exif[kCGImagePropertyExifDateTimeDigitized as String] = dateString
                    exifModified = true
                }
                if tiff[kCGImagePropertyTIFFDateTime as String] == nil {
                    tiff[kCGImagePropertyTIFFDateTime as String] = dateString
                    tiffModified = true
                }
            }

            if tiffModified {
                destinationProperties[kCGImagePropertyTIFFDictionary as String] = tiff
            }
            if exifModified {
                destinationProperties[kCGImagePropertyExifDictionary as String] = exif
            }

            CGImageDestinationAddImageFromSource(destination, source, 0, destinationProperties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw MotionPhotoEncodingError.jpegEncodingFailed
            }
            jpegData = outputData as Data
        }

        return stripXMPApp1Segments(from: jpegData)
    }

    private static let exifDateFormatterLock = NSLock()
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func formatExifDateString(_ date: Date) -> String {
        exifDateFormatterLock.lock()
        defer { exifDateFormatterLock.unlock() }
        return exifDateFormatter.string(from: date)
    }

    private static func shouldStripMake(from properties: [String: Any], targetBrand: MotionPhotoBrand) -> Bool {
        // Universal 模式完整保留原图 EXIF
        guard targetBrand != .universal else { return false }

        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiffMake = ((tiff?[kCGImagePropertyTIFFMake as String] as? String) ?? "").lowercased()
        let lensMake = ((exif?[kCGImagePropertyExifLensMake as String] as? String) ?? "").lowercased()
        let combinedMake = tiffMake.isEmpty ? lensMake : tiffMake

        // 小米处理器在无小米 EXIF Make 时仅当 exifMake 为空才按 MicroVideo XMP 兜底
        if targetBrand == .xiaomi {
            return !combinedMake.isEmpty && !combinedMake.contains("xiaomi") && !combinedMake.contains("redmi") && !combinedMake.contains("poco")
        }

        return conflictingMakes.contains(where: { combinedMake.contains($0) })
    }

    /// 剥离 JPEG 头部中可能冲突的旧 XMP APP1 段（保留 EXIF APP1 与图像主体）
    static func stripXMPApp1Segments(from rawData: Data) -> Data {
        let jpegData = rawData.startIndex == 0 ? rawData : Data(rawData)
        guard jpegData.count >= 4,
              jpegData[0] == 0xFF,
              jpegData[1] == 0xD8 else {
            return jpegData
        }

        var result = Data()
        result.reserveCapacity(jpegData.count)
        // SOI
        result.append(contentsOf: [0xFF, 0xD8])

        var index = 2
        let count = jpegData.count
        let xmpNamespacePrefix = Data("http://ns.adobe.com/xap/1.0/\0".utf8)
        let xmpExtPrefix = Data("http://ns.adobe.com/xmp/extension/\0".utf8)
        let xmpMetaPrefix = Data("<x:xmpmeta".utf8)

        while index < count {
            // 定位下一个 marker (0xFF)
            if jpegData[index] != 0xFF {
                result.append(jpegData[index..<count])
                break
            }

            // 跳过填充 0xFF
            while index < count && jpegData[index] == 0xFF {
                index += 1
            }
            guard index < count else { break }

            let marker = jpegData[index]
            index += 1

            // 无长度字段的独立标记或 SOS (0xDA) / EOI (0xD9)
            if marker == 0xD9 {
                result.append(contentsOf: [0xFF, 0xD9])
                break
            }
            if marker == 0xDA {
                result.append(contentsOf: [0xFF, marker])
                let sosEnd = findJPEGEndOfImageOffset(in: jpegData, from: index) ?? count
                result.append(jpegData[index..<sosEnd])
                break
            }
            if marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01 {
                result.append(contentsOf: [0xFF, marker])
                continue
            }

            guard index + 2 <= count else {
                result.append(contentsOf: [0xFF, marker])
                result.append(jpegData[index..<count])
                break
            }

            let length = (Int(jpegData[index]) << 8) | Int(jpegData[index + 1])
            guard length >= 2, index + length <= count else {
                result.append(contentsOf: [0xFF, marker])
                result.append(jpegData[index..<count])
                break
            }

            let payloadStart = index + 2
            let segmentEnd = index + length

            if marker == 0xE1 {
                let payload = jpegData[payloadStart..<segmentEnd]
                let isXMP = payload.starts(with: xmpNamespacePrefix)
                    || payload.starts(with: xmpExtPrefix)
                    || payload.range(of: xmpMetaPrefix) != nil
                if isXMP {
                    index = segmentEnd
                    continue
                }
            }

            result.append(contentsOf: [0xFF, marker])
            result.append(jpegData[index..<segmentEnd])
            index = segmentEnd
        }

        return result
    }

    /// 在 SOS 熵编码段之后定位合法 JPEG EOI (`0xFF 0xD9`) 结束位置，剥离旧 Motion Photo 尾部视频字节
    private static func findJPEGEndOfImageOffset(in data: Data, from startIndex: Int) -> Int? {
        let count = data.count
        var i = startIndex
        while i + 1 < count {
            if data[i] != 0xFF {
                i += 1
                continue
            }
            var nextIndex = i + 1
            while nextIndex < count && data[nextIndex] == 0xFF {
                nextIndex += 1
            }
            guard nextIndex < count else { break }

            let marker = data[nextIndex]
            if marker == 0xD9 {
                return nextIndex + 1
            }
            if marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01 {
                i = nextIndex + 1
                continue
            }
            // 多段扫描（如渐进式 JPEG 的后续 SOS/DHT/DQT 标记）跳过显式长度字段
            if nextIndex + 2 < count {
                let segLength = (Int(data[nextIndex + 1]) << 8) | Int(data[nextIndex + 2])
                if segLength >= 2 && nextIndex + 1 + segLength <= count {
                    i = nextIndex + 1 + segLength
                    continue
                }
            }
            i = nextIndex + 1
        }
        return nil
    }

    // MARK: - Step 2: Timestamp Extraction & Lossless MP4 Remux

    static func readStillImageTimestampUs(from videoURL: URL) async -> Int64 {
        let asset = AVAsset(url: videoURL)
        let durationSeconds = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
        let fallbackUs = durationSeconds.isFinite && durationSeconds > 0
            ? Int64(round((durationSeconds / 2.0) * 1_000_000.0))
            : 0

        // 1. 优先通过 AVAssetReader 遍历所有定时元数据轨道中的 com.apple.quicktime.still-image-time
        if let metadataTracks = try? await asset.loadTracks(withMediaType: .metadata) {
            for metadataTrack in metadataTracks {
                guard let reader = try? AVAssetReader(asset: asset) else { continue }
                let trackOutput = AVAssetReaderTrackOutput(track: metadataTrack, outputSettings: nil)
                let adaptor = AVAssetReaderOutputMetadataAdaptor(assetReaderTrackOutput: trackOutput)
                if reader.canAdd(trackOutput) {
                    reader.add(trackOutput)
                    if reader.startReading() {
                        while let group = adaptor.nextTimedMetadataGroup() {
                            let hasStillImageKey = group.items.contains { item in
                                (item.key as? String) == "com.apple.quicktime.still-image-time" ||
                                    item.identifier?.rawValue == "mdta/com.apple.quicktime.still-image-time"
                            }
                            if hasStillImageKey && group.timeRange.start.isValid {
                                let seconds = CMTimeGetSeconds(group.timeRange.start)
                                if seconds.isFinite && seconds >= 0 {
                                    reader.cancelReading()
                                    return Int64(round(seconds * 1_000_000.0))
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2. 回退读取容器级元数据（例如由 MediaExportService 写入的帧序号）
        if let fileMetadata = try? await asset.load(.metadata),
           let stillItem = fileMetadata.first(where: {
               ($0.key as? String) == "com.apple.quicktime.still-image-time" ||
                   $0.identifier?.rawValue == "mdta/com.apple.quicktime.still-image-time"
           }),
           let frameNumber = try? await stillItem.load(.numberValue)?.intValue,
           frameNumber >= 0 {
            if frameNumber == 0 {
                return 0
            }
            let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
            let fps = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? 30.0
            let safeFPS = (fps.isFinite && fps > 0) ? Double(fps) : 30.0
            let seconds = Double(frameNumber) / safeFPS
            return Int64(round(seconds * 1_000_000.0))
        }

        return fallbackUs
    }

    static func remuxToMP4Data(from videoURL: URL) async throws -> Data {
        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = videoTracks.first else {
            throw MotionPhotoEncodingError.videoRemuxFailed(nil)
        }

        let videoDuration = try await asset.load(.duration)
        let videoTimeRange = CMTimeRange(start: .zero, duration: videoDuration)

        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MotionPhotoEncodingError.videoRemuxFailed(nil)
        }
        try compVideoTrack.insertTimeRange(videoTimeRange, of: sourceVideoTrack, at: .zero)
        compVideoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

        if let audioTracks = try? await asset.loadTracks(withMediaType: .audio),
           let sourceAudioTrack = audioTracks.first,
           let audioRange = try? await sourceAudioTrack.load(.timeRange) {
            let clippedAudioRange = videoTimeRange.intersection(audioRange)
            if clippedAudioRange.isValid && !clippedAudioRange.isEmpty && CMTimeGetSeconds(clippedAudioRange.duration) > 0,
               let compAudioTrack = composition.addMutableTrack(
                   withMediaType: .audio,
                   preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                do {
                    try compAudioTrack.insertTimeRange(clippedAudioRange, of: sourceAudioTrack, at: .zero)
                } catch {
                    composition.removeTrack(compAudioTrack)
                }
            }
        }

        let tempMP4URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("motion_remux_\(UUID().uuidString).mp4")
        defer { MediaExportService.removeIfInTemporaryDirectory(tempMP4URL) }

        // 默认使用 Passthrough 无损混流；不兼容 .mp4 容器时静默回退标准重编码
        if await exportComposition(composition, to: tempMP4URL, presetName: AVAssetExportPresetPassthrough),
           let data = try? Data(contentsOf: tempMP4URL),
           ISOBMFFHelper.hasFtypSignature(in: data, at: 0) {
            return data
        }

        MediaExportService.removeIfInTemporaryDirectory(tempMP4URL)
        if await exportComposition(composition, to: tempMP4URL, presetName: AVAssetExportPresetHighestQuality),
           let data = try? Data(contentsOf: tempMP4URL),
           ISOBMFFHelper.hasFtypSignature(in: data, at: 0) {
            return data
        }

        throw MotionPhotoEncodingError.videoRemuxFailed(nil)
    }

    private static func exportComposition(
        _ composition: AVMutableComposition,
        to outputURL: URL,
        presetName: String
    ) async -> Bool {
        guard let session = AVAssetExportSession(asset: composition, presetName: presetName),
              session.supportedFileTypes.contains(.mp4) else {
            return false
        }
        session.outputURL = outputURL
        session.outputFileType = .mp4
        await session.export()
        return session.status == .completed
    }

    // MARK: - Step 3: Brand XMP & Container Assembly

    static func assembleContainer(
        cleanJPEG: Data,
        mp4Data: Data,
        targetBrand: MotionPhotoBrand,
        presentationTimestampUs: Int64
    ) throws -> Data {
        switch targetBrand {
        case .samsung:
            let sefTrailer = buildMinimalSamsungSEFTrailer()
            let itemLength = mp4Data.count + sefTrailer.count
            let xmpString = buildXMPString(
                for: .samsung,
                videoLength: itemLength,
                presentationTimestampUs: presentationTimestampUs
            )
            let jpegWithXMP = injectXMPApp1Segment(xmpString, into: cleanJPEG)
            var result = Data()
            result.reserveCapacity(jpegWithXMP.count + ISOBMFFHelper.samsungSEFSignature.count + itemLength)
            result.append(jpegWithXMP)
            result.append(ISOBMFFHelper.samsungSEFSignature)
            result.append(mp4Data)
            result.append(sefTrailer)
            return result

        case .universal:
            var result = Data()
            result.reserveCapacity(cleanJPEG.count + mp4Data.count)
            result.append(cleanJPEG)
            result.append(mp4Data)
            return result

        case .pixel, .xiaomi, .huawei, .oppo, .vivo:
            let xmpString = buildXMPString(
                for: targetBrand,
                videoLength: mp4Data.count,
                presentationTimestampUs: presentationTimestampUs
            )
            let jpegWithXMP = injectXMPApp1Segment(xmpString, into: cleanJPEG)
            var result = Data()
            result.reserveCapacity(jpegWithXMP.count + mp4Data.count)
            result.append(jpegWithXMP)
            result.append(mp4Data)
            return result

        case .unknown:
            throw MotionPhotoEncodingError.unsupportedBrand
        }
    }

    private static func buildMinimalSamsungSEFTrailer() -> Data {
        // 最小合法 Samsung SEF 尾部标记，开头非有效 ISOBMFF box 以便 measurePureMP4Length 准确截断
        var trailer = Data()
        trailer.append(Data("MotionPhoto_Versionmpv3\0".utf8))
        trailer.append(Data("SEFH".utf8))
        trailer.append(contentsOf: [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        trailer.append(Data("SEFT".utf8))
        return trailer
    }

    static func buildXMPString(
        for brand: MotionPhotoBrand,
        videoLength: Int,
        presentationTimestampUs: Int64
    ) -> String {
        switch brand {
        case .pixel:
            return """
            <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                  xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
                  xmlns:Container="http://ns.google.com/photos/1.0/container/"
                  xmlns:Item="http://ns.google.com/photos/1.0/container/item/"
                  GCamera:MotionPhoto="1"
                  GCamera:MotionPhotoVersion="1"
                  GCamera:MotionPhotoPresentationTimestampUs="\(presentationTimestampUs)">
                  <Container:Directory>
                    <rdf:Seq>
                      <rdf:li rdf:parseType="Resource">
                        <Container:Item
                          Item:Mime="image/jpeg"
                          Item:Semantic="Primary"
                          Item:Length="0"
                          Item:Padding="0"/>
                      </rdf:li>
                      <rdf:li rdf:parseType="Resource">
                        <Container:Item
                          Item:Mime="video/mp4"
                          Item:Semantic="MotionPhoto"
                          Item:Length="\(videoLength)"
                          Item:Padding="0"/>
                      </rdf:li>
                    </rdf:Seq>
                  </Container:Directory>
                </rdf:Description>
              </rdf:RDF>
            </x:xmpmeta>
            """

        case .xiaomi:
            return """
            <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                  xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
                  xmlns:MiCamera="http://ns.xiaomi.com/photos/1.0/camera/"
                  GCamera:MicroVideo="1"
                  GCamera:MicroVideoVersion="1"
                  GCamera:MicroVideoOffset="\(videoLength)"
                  GCamera:MicroVideoPresentationTimestampUs="\(presentationTimestampUs)"
                  MiCamera:XMPMeta="1"/>
              </rdf:RDF>
            </x:xmpmeta>
            """

        case .samsung:
            return """
            <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                  xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
                  xmlns:Container="http://ns.google.com/photos/1.0/container/"
                  xmlns:Item="http://ns.google.com/photos/1.0/container/item/"
                  GCamera:MotionPhoto="1"
                  GCamera:MotionPhotoVersion="1"
                  GCamera:MotionPhotoPresentationTimestampUs="\(presentationTimestampUs)">
                  <Container:Directory>
                    <rdf:Seq>
                      <rdf:li rdf:parseType="Resource">
                        <Container:Item
                          Item:Mime="image/jpeg"
                          Item:Semantic="Primary"
                          Item:Length="0"
                          Item:Padding="0"/>
                      </rdf:li>
                      <rdf:li rdf:parseType="Resource">
                        <Container:Item
                          Item:Mime="video/mp4"
                          Item:Semantic="MotionPhoto"
                          Item:Length="\(videoLength)"
                          Item:Padding="138"/>
                      </rdf:li>
                    </rdf:Seq>
                  </Container:Directory>
                </rdf:Description>
              </rdf:RDF>
            </x:xmpmeta>
            """

        case .huawei:
            return """
            <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                  xmlns:HwCamera="http://ns.huawei.com/photos/1.0/camera/"
                  xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
                  HwCamera:MovingPicture="1"
                  GCamera:MotionPhotoPresentationTimestampUs="\(presentationTimestampUs)"/>
              </rdf:RDF>
            </x:xmpmeta>
            """

        case .oppo:
            return """
            <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                  xmlns:OPPO="http://ns.oppo.com/photos/1.0/camera/"
                  xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
                  OPPO:LivePhoto="1"
                  O-Live="1"
                  GCamera:MotionPhotoPresentationTimestampUs="\(presentationTimestampUs)"/>
              </rdf:RDF>
            </x:xmpmeta>
            """

        case .vivo:
            return """
            <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                  xmlns:vivo="http://ns.vivo.com/photos/1.0/camera/"
                  xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
                  vivo:LivePhoto="1"
                  LivePhoto="1"
                  GCamera:MotionPhotoPresentationTimestampUs="\(presentationTimestampUs)"/>
              </rdf:RDF>
            </x:xmpmeta>
            """

        case .universal, .unknown:
            return ""
        }
    }

    static func injectXMPApp1Segment(_ xmpString: String, into jpegData: Data) -> Data {
        guard !xmpString.isEmpty,
              jpegData.count >= 2,
              jpegData[jpegData.startIndex] == 0xFF,
              jpegData[jpegData.index(after: jpegData.startIndex)] == 0xD8 else {
            return jpegData
        }

        let header = Data("http://ns.adobe.com/xap/1.0/\0".utf8)
        let xmpBody = Data(xmpString.utf8)
        let segmentLength = 2 + header.count + xmpBody.count
        guard segmentLength <= Int(UInt16.max) else {
            return jpegData
        }

        var segment = Data()
        segment.reserveCapacity(2 + segmentLength)
        segment.append(contentsOf: [0xFF, 0xE1])
        segment.append(UInt8((segmentLength >> 8) & 0xFF))
        segment.append(UInt8(segmentLength & 0xFF))
        segment.append(header)
        segment.append(xmpBody)

        var output = Data()
        output.reserveCapacity(jpegData.count + segment.count)
        output.append(jpegData.prefix(2)) // FF D8
        output.append(segment)
        output.append(jpegData.dropFirst(2))
        return output
    }

    // MARK: - Step 4: Self-Verification

    private static func verifyEncodedMotionPhoto(_ data: Data, expectedBrand: MotionPhotoBrand) throws {
        let xmpInfo = XMPParser.extractAndParse(from: data)
        if expectedBrand != .universal && xmpInfo.isEmpty {
            throw MotionPhotoEncodingError.verificationFailed
        }

        guard let offset = ISOBMFFHelper.findMP4Offset(in: data),
              ISOBMFFHelper.hasFtypSignature(in: data, at: offset) else {
            throw MotionPhotoEncodingError.verificationFailed
        }

        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) else {
            throw MotionPhotoEncodingError.verificationFailed
        }

        // Universal 模式完整保留原图 EXIF（若原图带厂商 Make 可能命中对应厂商处理器）
        if expectedBrand != .universal && processor.brand != expectedBrand {
            throw MotionPhotoEncodingError.verificationFailed
        }

        let parsed = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard parsed.success, let motionData = parsed.data, !motionData.videoData.isEmpty else {
            throw MotionPhotoEncodingError.verificationFailed
        }
    }
}
