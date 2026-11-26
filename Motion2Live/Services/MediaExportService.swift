//
//  MediaExportService.swift
//  Motion2Live
//
//  Unified media export pipeline (Live Photo, Video, GIF, Custom Live Photo).
//  Single source of truth shared by Single Inspector, Batch Converter, and Lab.
//

import Foundation
import AVFoundation
import Photos
import ImageIO
import UniformTypeIdentifiers
import UIKit

enum MediaExportError: LocalizedError {
    case photoLibraryPermissionDenied
    case invalidVideoDuration
    case imageConversionFailed
    case imageSourceCreationFailed
    case imageDestinationCreationFailed
    case metadataWriteFailed
    case exportSessionCreationFailed
    case videoExportFailed(Error?)
    case gifDestinationCreationFailed
    case gifFinalizationFailed

    var errorDescription: String? {
        switch self {
        case .photoLibraryPermissionDenied:
            return Localizable.string(.photoLibraryPermissionDenied)
        case .invalidVideoDuration:
            return Localizable.string(.invalidVideoData)
        case .imageConversionFailed:
            return Localizable.string(.imageConversionFailed)
        case .imageSourceCreationFailed:
            return Localizable.string(.cannotCreateImageSource)
        case .imageDestinationCreationFailed:
            return Localizable.string(.cannotCreateImageDestination)
        case .metadataWriteFailed:
            return Localizable.string(.metadataWriteFailed)
        case .exportSessionCreationFailed:
            return Localizable.string(.cannotCreateExportSession)
        case .videoExportFailed(let underlying):
            return underlying?.localizedDescription ?? Localizable.string(.videoExportFailed)
        case .gifDestinationCreationFailed:
            return Localizable.string(.cannotCreateGIFDestination)
        case .gifFinalizationFailed:
            return Localizable.string(.cannotFinalizeGIFCreation)
        }
    }
}

struct PreparedLivePhoto {
    let assetIdentifier: String
    let imageURL: URL
    let videoURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: videoURL)
    }
}

enum MediaExportService {

    // MARK: - Temporary File Safety Helper
    /// 安全删除位于临时目录内的文件（防止误删外部样图或用户文件）
    static func removeIfInTemporaryDirectory(_ url: URL?) {
        guard let url = url else { return }
        let tempRoot = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        guard targetPath.hasPrefix(tempRoot) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Photo Library Authorization
    static func ensurePhotoLibraryAddAuthorization() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard newStatus == .authorized || newStatus == .limited else {
                throw MediaExportError.photoLibraryPermissionDenied
            }
        case .denied, .restricted:
            throw MediaExportError.photoLibraryPermissionDenied
        @unknown default:
            throw MediaExportError.photoLibraryPermissionDenied
        }
    }

    // MARK: - Date Resolution
    static func resolveCreationDate(originalData: Data?, fallbackURL: URL?, preferredDate: Date? = nil) -> Date? {
        if let preferredDate = preferredDate {
            return preferredDate
        }
        if let originalData = originalData,
           let exifDate = ISOBMFFHelper.extractExifCreationDate(from: originalData) {
            return exifDate
        }
        if let fallbackURL = fallbackURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: fallbackURL.path) {
            return (attrs[.creationDate] as? Date) ?? (attrs[.modificationDate] as? Date)
        }
        return nil
    }

    // MARK: - Extract Cover Frame from Video (Preserving Original EXIF Metadata)
    static func extractCoverFrameData(
        from videoURL: URL,
        at seconds: Double,
        preservingMetadataFrom originalImageData: Data? = nil
    ) async throws -> Data {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw MediaExportError.invalidVideoDuration
        }

        let clampedSeconds = max(0, min(seconds, max(0, durationSeconds - 0.01)))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.02, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.02, preferredTimescale: 600)

        let cgImage = try await generator.image(at: CMTime(seconds: clampedSeconds, preferredTimescale: 600)).image

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaExportError.imageDestinationCreationFailed
        }

        var properties: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: 0.95
        ]
        if let originalImageData = originalImageData,
           let originalSource = CGImageSourceCreateWithData(originalImageData as CFData, nil),
           let originalProps = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) as? [String: Any] {
            if let exif = originalProps[kCGImagePropertyExifDictionary as String] {
                properties[kCGImagePropertyExifDictionary as String] = exif
            }
            if let tiff = originalProps[kCGImagePropertyTIFFDictionary as String] {
                properties[kCGImagePropertyTIFFDictionary as String] = tiff
            }
            if let gps = originalProps[kCGImagePropertyGPSDictionary as String] {
                properties[kCGImagePropertyGPSDictionary as String] = gps
            }
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaExportError.metadataWriteFailed
        }

        return outputData as Data
    }

    // MARK: - Prepare Live Photo Artifacts (Testable without PHPhotoLibrary)
    static func prepareLivePhotoFiles(
        imageData: Data,
        videoURL sourceVideoURL: URL,
        stillImageTime: Int = 0
    ) async throws -> PreparedLivePhoto {
        let assetIdentifier = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory
        let tempMOVURL = tempDir.appendingPathComponent("\(assetIdentifier).mov")

        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageType = CGImageSourceGetType(imageSource) else {
            throw MediaExportError.imageSourceCreationFailed
        }

        let imageExt = UTType(imageType as String)?.preferredFilenameExtension ?? "jpg"
        let tempImageURL = tempDir.appendingPathComponent("\(assetIdentifier).\(imageExt)")

        do {
            // 1. 写入带 Apple Maker Metadata ("17": assetIdentifier) 的静态图
            guard let imageDestination = CGImageDestinationCreateWithURL(tempImageURL as CFURL, imageType, 1, nil) else {
                throw MediaExportError.imageDestinationCreationFailed
            }

            var mutableProperties = (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]) ?? [:]
            if var makerAppleDict = mutableProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] {
                makerAppleDict["17"] = assetIdentifier
                mutableProperties[kCGImagePropertyMakerAppleDictionary as String] = makerAppleDict
            } else {
                mutableProperties[kCGImagePropertyMakerAppleDictionary as String] = ["17": assetIdentifier]
            }

            CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, mutableProperties as CFDictionary)
            guard CGImageDestinationFinalize(imageDestination) else {
                throw MediaExportError.metadataWriteFailed
            }

            // 2. 封装 MOV 并写入 QuickTime Content Identifier & still-image-time
            let asset = AVAsset(url: sourceVideoURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
                throw MediaExportError.exportSessionCreationFailed
            }

            exportSession.outputURL = tempMOVURL
            exportSession.outputFileType = .mov

            let originalMetadata = ((try? await asset.load(.metadata)) ?? []).filter { item in
                guard let key = item.key as? String else { return true }
                return key != "com.apple.quicktime.content.identifier" && key != "com.apple.quicktime.still-image-time"
            }
            let clampedStillTime = max(0, min(127, stillImageTime))
            let livePhotoMetadata: [AVMetadataItem] = [
                {
                    let item = AVMutableMetadataItem()
                    item.key = "com.apple.quicktime.content.identifier" as NSString
                    item.keySpace = .quickTimeMetadata
                    item.value = assetIdentifier as NSString
                    item.dataType = "com.apple.metadata.datatype.UTF-8"
                    return item
                }(),
                {
                    let item = AVMutableMetadataItem()
                    item.key = "com.apple.quicktime.still-image-time" as NSString
                    item.keySpace = AVMetadataKeySpace(rawValue: "mdta")
                    item.value = clampedStillTime as NSNumber
                    item.dataType = "com.apple.metadata.datatype.int8"
                    return item
                }()
            ]
            exportSession.metadata = originalMetadata + livePhotoMetadata

            await exportSession.export()
            guard exportSession.status == .completed else {
                throw MediaExportError.videoExportFailed(exportSession.error)
            }

            return PreparedLivePhoto(assetIdentifier: assetIdentifier, imageURL: tempImageURL, videoURL: tempMOVURL)
        } catch {
            try? FileManager.default.removeItem(at: tempImageURL)
            try? FileManager.default.removeItem(at: tempMOVURL)
            throw error
        }
    }

    // MARK: - Export Live Photo from MotionPhotoData
    static func exportLivePhoto(
        motionPhotoData: MotionPhotoData,
        originalData: Data? = nil,
        fallbackURL: URL? = nil,
        preferredDate: Date? = nil,
        stillImageTime: Int? = nil,
        processor: MotionPhotoProcessorProtocol? = nil,
        recordRecent: Bool = true
    ) async throws {
        try await ensurePhotoLibraryAddAuthorization()

        let tempMP4URL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tempMP4URL) }

        try motionPhotoData.videoData.write(to: tempMP4URL)

        let resolvedStillTime: Int
        if let explicitStillTime = stillImageTime {
            resolvedStillTime = explicitStillTime
        } else if let processor = processor {
            let asset = AVAsset(url: tempMP4URL)
            let duration = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
            let tracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
            let frameRate = (try? await tracks.first?.load(.nominalFrameRate)) ?? 30.0
            resolvedStillTime = processor.calculateStillImageTime(
                videoDuration: duration,
                presentationTimestamp: motionPhotoData.presentationTimestamp,
                frameRate: Double(frameRate)
            )
        } else {
            resolvedStillTime = motionPhotoData.stillImageTime
        }

        let prepared = try await prepareLivePhotoFiles(
            imageData: motionPhotoData.imageData,
            videoURL: tempMP4URL,
            stillImageTime: resolvedStillTime
        )
        defer { prepared.cleanup() }

        let finalDate = resolveCreationDate(originalData: originalData, fallbackURL: fallbackURL, preferredDate: preferredDate)

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: prepared.imageURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: prepared.videoURL, options: nil)
            if let finalDate = finalDate {
                request.creationDate = finalDate
            }
        }

        if recordRecent {
            let videoDurationSec = (try? await AVAsset(url: tempMP4URL).load(.duration)).map(CMTimeGetSeconds)
            let validDuration = (videoDurationSec?.isFinite == true && (videoDurationSec ?? 0) > 0) ? videoDurationSec : nil
            await RecentConversionStore.shared.recordConversion(
                imageData: motionPhotoData.imageData,
                durationSeconds: validDuration
            )
        }
    }

    // MARK: - Export Custom Live Photo (Lab)
    static func exportCustomLivePhoto(
        imageData: Data,
        videoURL: URL,
        creationDate: Date = Date()
    ) async throws {
        try await ensurePhotoLibraryAddAuthorization()

        let prepared = try await prepareLivePhotoFiles(
            imageData: imageData,
            videoURL: videoURL,
            stillImageTime: 0
        )
        defer { prepared.cleanup() }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: prepared.imageURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: prepared.videoURL, options: nil)
            request.creationDate = creationDate
        }

        let videoDurationSec = (try? await AVAsset(url: videoURL).load(.duration)).map(CMTimeGetSeconds)
        let validDuration = (videoDurationSec?.isFinite == true && (videoDurationSec ?? 0) > 0) ? videoDurationSec : nil
        await RecentConversionStore.shared.recordConversion(
            imageData: imageData,
            durationSeconds: validDuration
        )
    }

    // MARK: - Export Standalone Video
    static func exportVideo(
        videoData: Data,
        originalData: Data? = nil,
        fallbackURL: URL? = nil,
        preferredDate: Date? = nil,
        recordRecent: Bool = true
    ) async throws {
        try await ensurePhotoLibraryAddAuthorization()

        let tempVideoURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tempVideoURL) }

        try videoData.write(to: tempVideoURL)
        let finalDate = resolveCreationDate(originalData: originalData, fallbackURL: fallbackURL, preferredDate: preferredDate)

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempVideoURL)
            if let finalDate = finalDate {
                request?.creationDate = finalDate
            }
        }

        if recordRecent {
            await RecentConversionStore.shared.recordConversion(videoURL: tempVideoURL)
        }
    }

    // MARK: - Generate GIF File (Testable without PHPhotoLibrary)
    static func createGIFFile(
        from asset: AVAsset,
        outputURL: URL,
        frameCount: Int = 30,
        maxDimension: CGFloat = 720
    ) async throws {
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0, frameCount > 0 else {
            throw MediaExportError.invalidVideoDuration
        }

        let frameInterval = durationSeconds / Double(frameCount)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        generator.requestedTimeToleranceBefore = CMTime(seconds: frameInterval / 2.0, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: frameInterval / 2.0, preferredTimescale: 600)

        let destProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw MediaExportError.gifDestinationCreationFailed
        }

        CGImageDestinationSetProperties(destination, destProperties as CFDictionary)

        for index in 0..<frameCount {
            try Task.checkCancellation()
            let time = CMTime(seconds: Double(index) * frameInterval, preferredTimescale: 600)
            let cgImage = try await generator.image(at: time).image
            let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameInterval]]
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw MediaExportError.gifFinalizationFailed
        }
    }

    // MARK: - Export GIF to Photos
    static func exportGIF(
        videoData: Data,
        originalData: Data? = nil,
        fallbackURL: URL? = nil,
        preferredDate: Date? = nil,
        frameCount: Int = 30,
        maxDimension: CGFloat = 720,
        recordRecent: Bool = true
    ) async throws {
        try await ensurePhotoLibraryAddAuthorization()

        let tempMP4URL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        let tempGIFURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gif")
        defer {
            try? FileManager.default.removeItem(at: tempMP4URL)
            try? FileManager.default.removeItem(at: tempGIFURL)
        }

        try videoData.write(to: tempMP4URL)
        let asset = AVAsset(url: tempMP4URL)
        try await createGIFFile(from: asset, outputURL: tempGIFURL, frameCount: frameCount, maxDimension: maxDimension)

        let finalDate = resolveCreationDate(originalData: originalData, fallbackURL: fallbackURL, preferredDate: preferredDate)

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: tempGIFURL, options: nil)
            if let finalDate = finalDate {
                request.creationDate = finalDate
            }
        }

        if recordRecent {
            await RecentConversionStore.shared.recordConversion(videoURL: tempMP4URL)
        }
    }

    // MARK: - Export Motion Photo (.jpg) from Live Photo or Still+Video Pair (Lab)
    static func exportMotionPhoto(
        imageURL: URL,
        videoURL: URL,
        targetBrand: MotionPhotoBrand,
        creationDate: Date? = nil
    ) async throws -> URL {
        let encodedData = try await MotionPhotoEncoder.encode(
            imageURL: imageURL,
            videoURL: videoURL,
            targetBrand: targetBrand,
            creationDate: creationDate
        )
        return try writeMotionPhotoToTempFile(
            encodedData,
            targetBrand: targetBrand,
            creationDate: creationDate
        )
    }

    static func exportMotionPhoto(
        imageData: Data,
        videoURL: URL,
        targetBrand: MotionPhotoBrand,
        creationDate: Date? = nil
    ) async throws -> URL {
        let encodedData = try await MotionPhotoEncoder.encode(
            imageData: imageData,
            videoURL: videoURL,
            targetBrand: targetBrand,
            creationDate: creationDate
        )
        return try writeMotionPhotoToTempFile(
            encodedData,
            targetBrand: targetBrand,
            creationDate: creationDate
        )
    }

    private static func writeMotionPhotoToTempFile(
        _ encodedData: Data,
        targetBrand: MotionPhotoBrand,
        creationDate: Date? = nil
    ) throws -> URL {
        let brandSlug = targetBrand.rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "__", with: "_")
        let shortToken = UUID().uuidString.prefix(8)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MotionPhoto_\(brandSlug)_\(shortToken).jpg")

        removeIfInTemporaryDirectory(outputURL)
        try encodedData.write(to: outputURL, options: .atomic)

        // 仅依据显式 creationDate 或编码后 JPEG 内嵌 EXIF 同步文件时间戳（不回退临时源图文件时间）
        if let resolvedDate = resolveCreationDate(
            originalData: encodedData,
            fallbackURL: nil,
            preferredDate: creationDate
        ) {
            try? FileManager.default.setAttributes(
                [.creationDate: resolvedDate, .modificationDate: resolvedDate],
                ofItemAtPath: outputURL.path
            )
        }

        return outputURL
    }
}
