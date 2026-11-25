//
//  RecentConversionStore.swift
//  Motion2Live
//
//  Lightweight local cache of the 1–3 most recently converted thumbnails
//  for the Home hero deck. Reuses converted output thumbnails only and never
//  requests full Photo Library read access.
//

import Foundation
import Combine
import SwiftUI
import UIKit
import ImageIO
import AVFoundation
import UniformTypeIdentifiers

struct RecentConversionEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let durationSeconds: Double?
    let createdAt: Date
}

@MainActor
final class RecentConversionStore: ObservableObject {
    static let shared = RecentConversionStore()

    @Published private(set) var entries: [RecentConversionEntry] = []
    @Published var showRecentOnHome: Bool {
        didSet {
            UserDefaults.standard.set(showRecentOnHome, forKey: Self.showRecentDefaultsKey)
        }
    }

    private static let showRecentDefaultsKey = "homeShowRecentConversions"
    private static let maxEntries = 3

    private let cacheDirectory: URL
    private let indexURL: URL

    init(directory: URL? = nil) {
        if let directory {
            self.cacheDirectory = directory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.cacheDirectory = caches.appendingPathComponent("RecentConversions", isDirectory: true)
        }
        self.indexURL = self.cacheDirectory.appendingPathComponent("index.json")

        if UserDefaults.standard.object(forKey: Self.showRecentDefaultsKey) == nil {
            self.showRecentOnHome = true
        } else {
            self.showRecentOnHome = UserDefaults.standard.bool(forKey: Self.showRecentDefaultsKey)
        }

        loadIndex()
    }

    /// Returns a cached UIImage for the given entry, or nil if unavailable.
    func image(for entry: RecentConversionEntry) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(entry.fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Records a converted item's downsampled thumbnail from image data.
    func recordConversion(imageData: Data, durationSeconds: Double? = nil) async {
        let dir = cacheDirectory
        let idxURL = indexURL

        let jpegData = await Task.detached(priority: .utility) {
            Self.makeThumbnailJPEGData(fromImageData: imageData)
        }.value
        guard let jpegData else { return }
        await persistEntry(jpegData: jpegData, durationSeconds: durationSeconds, directory: dir, indexURL: idxURL)
    }

    /// Records a converted item's downsampled thumbnail from a video URL when no still image data is available.
    func recordConversion(videoURL: URL, durationSeconds: Double? = nil) async {
        let dir = cacheDirectory
        let idxURL = indexURL

        let result: (Data, Double?)? = await Task.detached(priority: .utility) {
            let asset = AVAsset(url: videoURL)
            let resolvedDuration: Double?
            if let durationSeconds {
                resolvedDuration = durationSeconds
            } else {
                let dur = try? await asset.load(.duration)
                let sec = dur.map(CMTimeGetSeconds)
                resolvedDuration = (sec?.isFinite == true && (sec ?? 0) > 0) ? sec : nil
            }
            guard let jpegData = await Self.makeThumbnailJPEGData(fromVideoAsset: asset) else { return nil }
            return (jpegData, resolvedDuration)
        }.value

        guard let (jpegData, resolvedDuration) = result else { return }
        await persistEntry(jpegData: jpegData, durationSeconds: resolvedDuration, directory: dir, indexURL: idxURL)
    }

    /// Clears all cached recent conversion thumbnails and restores the default demo deck.
    func clearHistory() {
        entries = []
        let dir = cacheDirectory
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Persistence

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([RecentConversionEntry].self, from: data) else {
            entries = []
            return
        }
        // Keep only entries whose thumbnail file still exists on disk
        entries = decoded.filter { entry in
            FileManager.default.fileExists(atPath: cacheDirectory.appendingPathComponent(entry.fileName).path)
        }
    }

    private func persistEntry(jpegData: Data, durationSeconds: Double?, directory: URL, indexURL: URL) async {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let newEntry = RecentConversionEntry(
            id: id,
            fileName: fileName,
            durationSeconds: durationSeconds,
            createdAt: Date()
        )

        var updated = entries
        updated.insert(newEntry, at: 0)
        let evicted = Array(updated.dropFirst(Self.maxEntries))
        let kept = Array(updated.prefix(Self.maxEntries))

        // Persist thumbnail and index before publishing `entries` so the UI
        // never reads an un-written file path on re-render.
        await Task.detached(priority: .utility) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent(fileName)
            try? jpegData.write(to: fileURL, options: .atomic)

            for old in evicted {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(old.fileName))
            }

            if let encoded = try? JSONEncoder().encode(kept) {
                try? encoded.write(to: indexURL, options: .atomic)
            }
        }.value

        entries = kept
    }

    // MARK: - Low-Memory Thumbnail Generation

    private nonisolated static func makeThumbnailJPEGData(fromImageData data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 720
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encodeJPEG(cgImage: cgImage)
    }

    private nonisolated static func makeThumbnailJPEGData(fromVideoAsset asset: AVAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 720)
        guard let cgImage = try? await generator.image(at: .zero).image else { return nil }
        return encodeJPEG(cgImage: cgImage)
    }

    private nonisolated static func encodeJPEG(cgImage: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ]
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
