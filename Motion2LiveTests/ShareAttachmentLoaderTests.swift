//
//  ShareAttachmentLoaderTests.swift
//  Motion2LiveTests
//
//  Unit tests for ShareAttachmentLoader attachment copying, non-motion-photo interception,
//  and temporary file cleanup boundaries.
//

import XCTest
import UIKit
import UniformTypeIdentifiers
@testable import Motion2Live

final class ShareAttachmentLoaderTests: XCTestCase {

    private func sampleURL(named name: String, ext: String = "jpg") throws -> URL {
        let bundle = Bundle(for: Self.self)
        return try XCTUnwrap(
            bundle.url(forResource: name, withExtension: ext),
            "Missing test sample \(name).\(ext) in Motion2LiveTests bundle"
        )
    }

    func testLoadFirstImageCopiesMotionPhotoToTemporaryDirectory() async throws {
        let sourceURL = try sampleURL(named: "Pixel")
        let provider = try XCTUnwrap(NSItemProvider(contentsOf: sourceURL))

        let loaded = try await ShareAttachmentLoader.loadFirstImage(from: [provider])
        defer { ShareAttachmentLoader.cleanupTemporaryFile(loaded.fileURL) }

        XCTAssertFalse(loaded.hasMultipleItems)
        XCTAssertTrue(FileManager.default.fileExists(atPath: loaded.fileURL.path))

        let tempRoot = FileManager.default.temporaryDirectory.standardizedFileURL.path
        XCTAssertTrue(loaded.fileURL.standardizedFileURL.path.hasPrefix(tempRoot))

        let originalData = try Data(contentsOf: sourceURL)
        let copiedData = try Data(contentsOf: loaded.fileURL)
        XCTAssertEqual(copiedData, originalData)

        let parsed = try ShareAttachmentLoader.parseMotionPhoto(at: loaded.fileURL)
        XCTAssertEqual(parsed.motionPhotoData.brand, .pixel)
        XCTAssertTrue(ISOBMFFHelper.hasFtypSignature(in: parsed.motionPhotoData.videoData, at: 0))
    }

    func testLoadMultipleItemsFlagsHasMultipleItems() async throws {
        let firstURL = try sampleURL(named: "Pixel")
        let secondURL = try sampleURL(named: "XiaomiNew")
        let firstProvider = try XCTUnwrap(NSItemProvider(contentsOf: firstURL))
        let secondProvider = try XCTUnwrap(NSItemProvider(contentsOf: secondURL))

        let loaded = try await ShareAttachmentLoader.loadFirstImage(from: [firstProvider, secondProvider])
        defer { ShareAttachmentLoader.cleanupTemporaryFile(loaded.fileURL) }

        XCTAssertTrue(loaded.hasMultipleItems)
        let parsed = try ShareAttachmentLoader.parseMotionPhoto(at: loaded.fileURL)
        XCTAssertEqual(parsed.motionPhotoData.brand, .pixel)
    }

    func testStaticJPEGIsInterceptedAsNotMotionPhoto() async throws {
        let staticURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("static_\(UUID().uuidString).jpg")
        defer { ShareAttachmentLoader.cleanupTemporaryFile(staticURL) }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        let jpegData = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        try jpegData.write(to: staticURL)

        let provider = try XCTUnwrap(NSItemProvider(contentsOf: staticURL))
        let loaded = try await ShareAttachmentLoader.loadFirstImage(from: [provider])
        defer { ShareAttachmentLoader.cleanupTemporaryFile(loaded.fileURL) }

        XCTAssertThrowsError(try ShareAttachmentLoader.parseMotionPhoto(at: loaded.fileURL)) { error in
            XCTAssertEqual(error as? ShareAttachmentError, .notMotionPhoto)
        }
    }

    func testNonImageAttachmentIsRejected() async throws {
        let textURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("note_\(UUID().uuidString).txt")
        defer { ShareAttachmentLoader.cleanupTemporaryFile(textURL) }

        try "Not an image".write(to: textURL, atomically: true, encoding: .utf8)
        let provider = try XCTUnwrap(NSItemProvider(contentsOf: textURL))

        do {
            let loaded = try await ShareAttachmentLoader.loadFirstImage(from: [provider])
            ShareAttachmentLoader.cleanupTemporaryFile(loaded.fileURL)
            XCTFail("Expected ShareAttachmentError.noSupportedImage for .txt attachment")
        } catch let error as ShareAttachmentError {
            XCTAssertEqual(error, .noSupportedImage)
        }
    }

    func testEmptyExtensionItemsThrowsNoSupportedImage() async {
        do {
            _ = try await ShareAttachmentLoader.loadFirstImage(from: nil as [Any]?)
            XCTFail("Expected ShareAttachmentError.noSupportedImage for empty extensionItems")
        } catch let error as ShareAttachmentError {
            XCTAssertEqual(error, .noSupportedImage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCleanupTemporaryFileOnlyDeletesInsideTemporaryDirectory() throws {
        // 1. File inside temporaryDirectory should be removed
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("cleanup_test_\(UUID().uuidString).jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: tempFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path))

        ShareAttachmentLoader.cleanupTemporaryFile(tempFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path))

        // 2. File outside temporaryDirectory must NOT be removed
        let bundleSample = try sampleURL(named: "Pixel")
        ShareAttachmentLoader.cleanupTemporaryFile(bundleSample)
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleSample.path))
    }
}
