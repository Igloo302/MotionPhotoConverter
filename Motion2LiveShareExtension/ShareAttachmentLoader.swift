//
//  ShareAttachmentLoader.swift
//  Motion2LiveShareExtension
//
//  Streams shared image attachments into the extension's isolated temporaryDirectory
//  and performs read-only Motion Photo parsing with ftyp boundary validation.
//

import Foundation
import UniformTypeIdentifiers

enum ShareAttachmentError: LocalizedError, Equatable {
    case noSupportedImage
    case loadFailed(String)
    case notMotionPhoto

    var errorDescription: String? {
        switch self {
        case .noSupportedImage:
            return Localizable.string(.shareNoSupportedImage)
        case .loadFailed(let detail):
            return detail.isEmpty ? Localizable.string(.cannotReadFile) : detail
        case .notMotionPhoto:
            return Localizable.string(.selectedPhotoIsNotMotionPhoto)
        }
    }
}

struct LoadedShareAttachment: Equatable {
    let fileURL: URL
    let hasMultipleItems: Bool
}

struct ParsedShareMotionPhoto {
    let sourceURL: URL
    let originalData: Data
    let motionPhotoData: MotionPhotoData
    let processor: MotionPhotoProcessorProtocol
}

enum ShareAttachmentLoader {
    /// Type identifier priority order matching Info.plist NSExtensionActivationRule.
    static let preferredTypeIdentifiers: [String] = [
        UTType.jpeg.identifier,
        UTType.heic.identifier,
        "public.avif",
        UTType.image.identifier,
        UTType.fileURL.identifier
    ]

    private static let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "avif"
    ]

    static func extractProviders(from extensionItems: [Any]?) -> [NSItemProvider] {
        guard let items = extensionItems as? [NSExtensionItem] else { return [] }
        return items.flatMap { $0.attachments ?? [] }
    }

    static func loadFirstImage(from extensionItems: [Any]?) async throws -> LoadedShareAttachment {
        let providers = extractProviders(from: extensionItems)
        return try await loadFirstImage(from: providers)
    }

    static func loadFirstImage(from providers: [NSItemProvider]) async throws -> LoadedShareAttachment {
        guard !providers.isEmpty else {
            throw ShareAttachmentError.noSupportedImage
        }

        let hasMultipleItems = providers.count > 1
        var lastError: ShareAttachmentError?

        for provider in providers {
            guard let matchedType = matchingTypeIdentifier(for: provider) else {
                continue
            }

            do {
                if matchedType == UTType.fileURL.identifier {
                    if let copiedURL = try await loadFileURLProvider(provider) {
                        return LoadedShareAttachment(fileURL: copiedURL, hasMultipleItems: hasMultipleItems)
                    }
                    continue
                }

                let copiedURL = try await copyFileRepresentation(from: provider, typeIdentifier: matchedType)
                if isSupportedImageURL(copiedURL) {
                    return LoadedShareAttachment(fileURL: copiedURL, hasMultipleItems: hasMultipleItems)
                } else {
                    MediaExportService.removeIfInTemporaryDirectory(copiedURL)
                }
            } catch {
                let mappedError = (error as? ShareAttachmentError) ?? .loadFailed(error.localizedDescription)
                lastError = mappedError
                if providers.count == 1 {
                    throw mappedError
                }
            }
        }

        throw lastError ?? ShareAttachmentError.noSupportedImage
    }

    static func parseMotionPhoto(at url: URL) throws -> ParsedShareMotionPhoto {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let xmpInfo = XMPParser.extractAndParse(from: data)

        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) else {
            throw ShareAttachmentError.notMotionPhoto
        }

        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard result.success,
              let motionData = result.data,
              !motionData.videoData.isEmpty,
              ISOBMFFHelper.hasFtypSignature(in: motionData.videoData, at: 0) else {
            throw ShareAttachmentError.notMotionPhoto
        }

        return ParsedShareMotionPhoto(
            sourceURL: url,
            originalData: data,
            motionPhotoData: motionData,
            processor: processor
        )
    }

    static func cleanupTemporaryFile(_ url: URL?) {
        MediaExportService.removeIfInTemporaryDirectory(url)
    }

    // MARK: - Private Helpers

    static func matchingTypeIdentifier(for provider: NSItemProvider) -> String? {
        for identifier in preferredTypeIdentifiers {
            if provider.hasItemConformingToTypeIdentifier(identifier) {
                return identifier
            }
        }
        return nil
    }

    private static func copyFileRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { sourceURL, error in
                if let error = error {
                    continuation.resume(throwing: ShareAttachmentError.loadFailed(error.localizedDescription))
                    return
                }
                guard let sourceURL = sourceURL else {
                    continuation.resume(throwing: ShareAttachmentError.noSupportedImage)
                    return
                }
                do {
                    let ext = resolvedExtension(for: sourceURL, typeIdentifier: typeIdentifier)
                    let destinationURL = try copyToTemporaryFile(from: sourceURL, preferredExtension: ext)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: ShareAttachmentError.loadFailed(error.localizedDescription))
                }
            }
        }
    }

    private static func loadFileURLProvider(_ provider: NSItemProvider) async throws -> URL? {
        let url: URL? = try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: ShareAttachmentError.loadFailed(error.localizedDescription))
                    return
                }
                if let itemURL = item as? URL {
                    continuation.resume(returning: itemURL)
                } else if let data = item as? Data,
                          let string = String(data: data, encoding: .utf8),
                          let itemURL = URL(string: string) {
                    continuation.resume(returning: itemURL)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let sourceURL = url, isSupportedImageURL(sourceURL) else {
            return nil
        }

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        return try copyToTemporaryFile(from: sourceURL, preferredExtension: sourceURL.pathExtension)
    }

    static func copyToTemporaryFile(from sourceURL: URL, preferredExtension: String? = nil) throws -> URL {
        let ext = (preferredExtension?.isEmpty == false ? preferredExtension! : sourceURL.pathExtension)
        let safeExt = ext.isEmpty ? "jpg" : ext.lowercased()
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("share_\(UUID().uuidString).\(safeExt)")
        MediaExportService.removeIfInTemporaryDirectory(destURL)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    static func isSupportedImageURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if supportedImageExtensions.contains(ext) {
            return true
        }
        if let utType = UTType(filenameExtension: ext) {
            return utType.conforms(to: .image)
        }
        return false
    }

    private static func resolvedExtension(for sourceURL: URL, typeIdentifier: String) -> String {
        let ext = sourceURL.pathExtension
        if !ext.isEmpty {
            return ext
        }
        if typeIdentifier == "public.avif" {
            return "avif"
        }
        if let utType = UTType(typeIdentifier), let preferred = utType.preferredFilenameExtension {
            return preferred
        }
        return "jpg"
    }
}
