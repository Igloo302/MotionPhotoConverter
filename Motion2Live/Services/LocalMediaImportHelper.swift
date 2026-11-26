//
//  LocalMediaImportHelper.swift
//  Motion2Live
//
//  Read-only security-scoped file import helper for Finder selection,
//  drag & drop, and "Open With" (.onOpenURL) on macOS / iOS.
//

import Foundation
import AVFoundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum LocalMediaImportError: LocalizedError {
    case invalidFileURL
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .invalidFileURL:
            return Localizable.string(.fileNotSupported)
        case .unreadableFile:
            return Localizable.string(.cannotReadFile)
        }
    }
}

enum LocalMediaImportHelper {
    private static let supportedMotionExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "avif"
    ]

    /// 安全作用域只读拷贝到 `NSTemporaryDirectory`，严禁回写源资源
    nonisolated static func copySecurityScopedFileToTemp(from url: URL, prefix: String = "import") throws -> URL {
        guard url.isFileURL, !url.hasDirectoryPath else {
            throw LocalMediaImportError.invalidFileURL
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            throw LocalMediaImportError.invalidFileURL
        }

        let ext = url.pathExtension.lowercased()
        let safeExt = ext.isEmpty ? "jpg" : ext
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString).\(safeExt)")

        MediaExportService.removeIfInTemporaryDirectory(destURL)
        try FileManager.default.copyItem(at: url, to: destURL)
        return destURL
    }

    nonisolated static func isSupportedMotionPhoto(at url: URL) -> Bool {
        guard supportedMotionExtensions.contains(url.pathExtension.lowercased()),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return false
        }
        let xmpInfo = XMPParser.extractAndParse(from: data)
        return MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) != nil
    }

    /// 批量导入外部文件 URL，过滤非 Motion Photo 并清理无效临时副本
    static func importMotionPhotos(
        from urls: [URL],
        onProgress: ((Int, Int) -> Void)? = nil
    ) async -> (validURLs: [URL], ignoredCount: Int) {
        let total = urls.count
        var validURLs: [URL] = []
        var ignoredCount = 0

        for (index, url) in urls.enumerated() {
            await MainActor.run {
                onProgress?(index + 1, total)
            }

            let result: URL? = await Task.detached(priority: .userInitiated) {
                guard let tempURL = try? copySecurityScopedFileToTemp(from: url) else {
                    return nil
                }
                if isSupportedMotionPhoto(at: tempURL) {
                    return tempURL
                } else {
                    MediaExportService.removeIfInTemporaryDirectory(tempURL)
                    return nil
                }
            }.value

            if let validURL = result {
                validURLs.append(validURL)
            } else {
                ignoredCount += 1
            }
        }

        await MainActor.run {
            onProgress?(0, 0)
        }

        return (validURLs, ignoredCount)
    }

    /// 从拖拽的 NSItemProvider 列表提取并拷贝到本地临时目录（支持 fileURL 与直接图片/视频数据）
    static func copyDroppedProvidersToTemp(
        _ providers: [NSItemProvider],
        acceptedTypes: [UTType],
        defaultExtension: String = "jpg"
    ) async -> [URL] {
        var resultURLs: [URL] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                if let fileURL = await loadFileURL(from: provider),
                   let tempURL = try? await Task.detached(priority: .userInitiated, operation: {
                       try copySecurityScopedFileToTemp(from: fileURL, prefix: "drop")
                   }).value {
                    resultURLs.append(tempURL)
                    continue
                }
            }

            if let matchedType = acceptedTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
                if let tempURL = await loadFileRepresentationToTemp(from: provider, typeIdentifier: matchedType.identifier, defaultExtension: defaultExtension) {
                    resultURLs.append(tempURL)
                }
            }
        }

        return resultURLs
    }

    /// 从本地文件读取静态图及其原始字节（用于 LabView 封面导入）
    nonisolated static func loadStillImageData(from url: URL) throws -> (image: UIImage, data: Data, pixelSize: CGSize?) {
        let tempURL = try copySecurityScopedFileToTemp(from: url, prefix: "lab_img")
        defer { MediaExportService.removeIfInTemporaryDirectory(tempURL) }

        let data = try Data(contentsOf: tempURL, options: .mappedIfSafe)
        let previewImage = makePreviewThumbnail(from: data) ?? UIImage(data: data)
        guard let image = previewImage else {
            throw LocalMediaImportError.unreadableFile
        }
        let pixelSize = readPixelDimensions(from: data)
        return (image, data, pixelSize)
    }

    /// 从本地文件拷贝视频到临时目录并解析时长（用于 LabView 视频导入）
    static func loadVideoToTemp(from url: URL) async throws -> (tempURL: URL, duration: Double?) {
        let tempURL = try await Task.detached(priority: .userInitiated) {
            try copySecurityScopedFileToTemp(from: url, prefix: "lab_video")
        }.value

        let asset = AVAsset(url: tempURL)
        let duration = try? await asset.load(.duration)
        let seconds = duration.map { CMTimeGetSeconds($0) }
        let validDuration = (seconds?.isFinite == true && (seconds ?? 0) > 0) ? seconds : nil
        return (tempURL, validDuration)
    }

    // MARK: - Private Helpers

    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let str = String(data: data, encoding: .utf8),
                          let url = URL(string: str) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadFileRepresentationToTemp(
        from provider: NSItemProvider,
        typeIdentifier: String,
        defaultExtension: String
    ) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { sourceURL, _ in
                guard let sourceURL else {
                    continuation.resume(returning: nil)
                    return
                }
                let ext = sourceURL.pathExtension.isEmpty
                    ? (UTType(typeIdentifier)?.preferredFilenameExtension ?? defaultExtension)
                    : sourceURL.pathExtension
                let destURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("drop_\(UUID().uuidString).\(ext)")
                do {
                    MediaExportService.removeIfInTemporaryDirectory(destURL)
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    continuation.resume(returning: destURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private nonisolated static func readPixelDimensions(from data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: w, height: h)
    }

    private nonisolated static func makePreviewThumbnail(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 600
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
