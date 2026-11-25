//
//  LivePhotoExtractor.swift
//  Motion2Live
//
//  Read-only extraction of Apple Live Photo still image and paired video
//  to NSTemporaryDirectory via PHAssetResource (with PHLivePhoto fallback).
//

import Foundation
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct ExtractedLivePhoto: Sendable {
    let imageURL: URL
    let videoURL: URL
    let creationDate: Date?

    func cleanup() {
        MediaExportService.removeIfInTemporaryDirectory(imageURL)
        MediaExportService.removeIfInTemporaryDirectory(videoURL)
    }
}

enum LivePhotoExtractionError: LocalizedError {
    case notALivePhoto
    case resourceMissing
    case readFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .notALivePhoto:
            return Localizable.string(.liveToMotionNotLivePhoto)
        case .resourceMissing:
            return Localizable.string(.liveToMotionResourceMissing)
        case .readFailed(let underlying):
            return underlying?.localizedDescription ?? Localizable.string(.cannotReadFile)
        }
    }
}

enum LivePhotoExtractor {
    /// 从 PHPickerResult 只读抽取 Live Photo 静态图与配对视频至 NSTemporaryDirectory
    static func extract(from result: PHPickerResult) async throws -> ExtractedLivePhoto {
        if let assetIdentifier = result.assetIdentifier,
           let extracted = await extractFromAsset(identifier: assetIdentifier) {
            return extracted
        }
        return try await extractFromItemProvider(result.itemProvider)
    }

    // MARK: - Path A: PHAssetResource (requires Photo Library read authorization)

    private static func extractFromAsset(identifier: String) async -> ExtractedLivePhoto? {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            return nil
        }

        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetched.firstObject else { return nil }

        let resources = PHAssetResource.assetResources(for: asset)
        return await writePairedResources(resources, creationDate: asset.creationDate)
    }

    // MARK: - Path B: PHLivePhoto via NSItemProvider (no Photo Library read permission needed)

    private static func extractFromItemProvider(_ provider: NSItemProvider) async throws -> ExtractedLivePhoto {
        guard provider.canLoadObject(ofClass: PHLivePhoto.self) else {
            throw LivePhotoExtractionError.notALivePhoto
        }

        let livePhoto: PHLivePhoto = try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: PHLivePhoto.self) { object, error in
                if let livePhoto = object as? PHLivePhoto {
                    continuation.resume(returning: livePhoto)
                } else if let error = error {
                    continuation.resume(throwing: LivePhotoExtractionError.readFailed(error))
                } else {
                    continuation.resume(throwing: LivePhotoExtractionError.notALivePhoto)
                }
            }
        }

        let resources = PHAssetResource.assetResources(for: livePhoto)
        guard let extracted = await writePairedResources(resources, creationDate: nil) else {
            throw LivePhotoExtractionError.resourceMissing
        }
        return extracted
    }

    // MARK: - Shared Resource Writer

    private static func writePairedResources(
        _ resources: [PHAssetResource],
        creationDate: Date?
    ) async -> ExtractedLivePhoto? {
        let photoTypes: [PHAssetResourceType] = [.fullSizePhoto, .photo, .alternatePhoto]
        let videoTypes: [PHAssetResourceType] = [.fullSizePairedVideo, .pairedVideo]

        guard let photoResource = photoTypes.compactMap({ type in
            resources.first(where: { $0.type == type })
        }).first,
        let videoResource = videoTypes.compactMap({ type in
            resources.first(where: { $0.type == type })
        }).first else {
            return nil
        }

        let token = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory

        let photoExt = sanitizedExtension(for: photoResource, fallback: "heic")
        let videoExt = sanitizedExtension(for: videoResource, fallback: "mov")
        let photoURL = tempDir.appendingPathComponent("live_still_\(token).\(photoExt)")
        let videoURL = tempDir.appendingPathComponent("live_video_\(token).\(videoExt)")

        do {
            try await writeResource(photoResource, to: photoURL)
            try await writeResource(videoResource, to: videoURL)
            return ExtractedLivePhoto(imageURL: photoURL, videoURL: videoURL, creationDate: creationDate)
        } catch {
            MediaExportService.removeIfInTemporaryDirectory(photoURL)
            MediaExportService.removeIfInTemporaryDirectory(videoURL)
            AppLogger.picker.warning("Failed writing Live Photo resources: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func writeResource(_ resource: PHAssetResource, to destinationURL: URL) async throws {
        MediaExportService.removeIfInTemporaryDirectory(destinationURL)

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: destinationURL, options: options) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func sanitizedExtension(for resource: PHAssetResource, fallback: String) -> String {
        let ext = (resource.originalFilename as NSString).pathExtension.lowercased()
        if !ext.isEmpty {
            return ext
        }
        if let utiExt = UTType(resource.uniformTypeIdentifier)?.preferredFilenameExtension?.lowercased(),
           !utiExt.isEmpty {
            return utiExt
        }
        return fallback
    }
}
