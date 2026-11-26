//
//  Motion2LiveTests.swift
//  Motion2LiveTests
//

import XCTest
import AVFoundation
import ImageIO
import SwiftUI
import UIKit
@testable import Motion2Live

final class Motion2LiveTests: XCTestCase {

    // MARK: - Helpers
    private func sampleURL(named name: String, ext: String = "jpg") throws -> URL {
        let bundle = Bundle(for: Self.self)
        return try XCTUnwrap(
            bundle.url(forResource: name, withExtension: ext),
            "Missing test sample \(name).\(ext) in Motion2LiveTests bundle"
        )
    }

    // MARK: - Brand Parsing Tests
    func testPixelMotionPhoto() throws {
        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let xmpInfo = XMPParser.extractAndParse(from: data)

        let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data)
        XCTAssertNotNil(processor)
        XCTAssertEqual(processor?.brand, .pixel)

        let result = try XCTUnwrap(processor?.processMotionPhoto(data: data, xmpInfo: xmpInfo))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?.videoData.count, 1_619_843)
    }

    func testSamsungMotionPhoto() throws {
        let data = try Data(contentsOf: try sampleURL(named: "Samsung"))
        let xmpInfo = XMPParser.extractAndParse(from: data)

        let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data)
        XCTAssertNotNil(processor)
        XCTAssertEqual(processor?.brand, .samsung)

        let result = try XCTUnwrap(processor?.processMotionPhoto(data: data, xmpInfo: xmpInfo))
        XCTAssertTrue(result.success)
        // 剥离末尾 123 字节的三星 SEF Trailer (MotionPhoto_Data) 之后，得到标准合法的 MP4 数据流
        XCTAssertEqual(result.data?.videoData.count, 5_421_550)
    }

    func testXiaomiNewMotionPhoto() throws {
        let data = try Data(contentsOf: try sampleURL(named: "XiaomiNew"))
        let xmpInfo = XMPParser.extractAndParse(from: data)

        let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data)
        XCTAssertNotNil(processor)
        XCTAssertEqual(processor?.brand, .xiaomi)

        let result = try XCTUnwrap(processor?.processMotionPhoto(data: data, xmpInfo: xmpInfo))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?.videoData.count, 1_943_922)
    }

    func testXiaomiOldMotionPhoto() throws {
        let data = try Data(contentsOf: try sampleURL(named: "XiaomiOld"))
        let xmpInfo = XMPParser.extractAndParse(from: data)

        let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data)
        XCTAssertNotNil(processor)
        XCTAssertEqual(processor?.brand, .xiaomi)

        let result = try XCTUnwrap(processor?.processMotionPhoto(data: data, xmpInfo: xmpInfo))
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.data?.videoData.count ?? 0, 10_000)
        XCTAssertTrue(ISOBMFFHelper.hasFtypSignature(in: try XCTUnwrap(result.data?.videoData), at: 0))
    }

    func testUniversalOrHuaweiConcatenatedMP4Detection() throws {
        let baseData = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let ftypOffset = try XCTUnwrap(ISOBMFFHelper.findMP4Offset(in: baseData))
        let pureImage = baseData.prefix(ftypOffset)
        let pureVideo = baseData.suffix(from: ftypOffset)
        let syntheticMovingPhoto = pureImage + pureVideo

        // 测试在没有任何 XMP 的情况下（如华为/vivo无XMP实况照片），能否准确识别并切分
        let processor = MotionPhotoProcessorFactory.getProcessor(for: [:], data: syntheticMovingPhoto)
        XCTAssertNotNil(processor)

        let result = try XCTUnwrap(processor?.processMotionPhoto(data: syntheticMovingPhoto, xmpInfo: [:]))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data?.videoData.count, pureVideo.count)
    }

    // MARK: - Edge Cases & Validation Tests
    func testNonMotionPhotoReturnsNil() {
        let plainBytes = Data(repeating: 0xFF, count: 20_000)
        XCTAssertNil(MotionPhotoProcessorFactory.getProcessor(for: [:], data: plainBytes))
        XCTAssertNil(ISOBMFFHelper.findMP4Offset(in: plainBytes))
    }

    func testCalculateStillImageTimeBounds() {
        let processor = BaseMotionPhotoProcessor(brand: .universal)

        // 0 或非法时长
        XCTAssertEqual(processor.calculateStillImageTime(videoDuration: 0, presentationTimestamp: 500_000, frameRate: 30), 0)
        XCTAssertEqual(processor.calculateStillImageTime(videoDuration: -1, presentationTimestamp: 500_000, frameRate: 30), 0)
        XCTAssertEqual(processor.calculateStillImageTime(videoDuration: .nan, presentationTimestamp: 500_000, frameRate: 30), 0)

        // 高帧率/长视频 int8 上限 127 钳制
        XCTAssertEqual(processor.calculateStillImageTime(videoDuration: 10.0, presentationTimestamp: 8_000_000, frameRate: 60), 127)

        // 无时间戳时默认取中点帧
        XCTAssertEqual(processor.calculateStillImageTime(videoDuration: 3.0, presentationTimestamp: nil, frameRate: 30), 45)
    }

    func testExtractExifCreationDate() throws {
        let data = try Data(contentsOf: try sampleURL(named: "XiaomiNew"))
        let exifDate = ISOBMFFHelper.extractExifCreationDate(from: data)
        XCTAssertNotNil(exifDate)
    }

    func testXMPExtractionAndParsing() throws {
        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let xmpData = try XCTUnwrap(XMPParser.extract(from: data))
        let parsed = try XCTUnwrap(XMPParser.parse(data: xmpData))
        XCTAssertFalse(parsed.isEmpty)
    }

    func testOppoProcessorValidatesFtypSignature() throws {
        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let oppo = OppoMotionPhotoProcessor()
        // 故意传入错误偏移量，应自动回退至有效 ftyp 扫描而不是盲切
        let result = oppo.processMotionPhoto(data: data, xmpInfo: ["GCamera:MicroVideoOffset": "12345"])
        XCTAssertTrue(result.success)
        let videoData = try XCTUnwrap(result.data?.videoData)
        XCTAssertTrue(ISOBMFFHelper.hasFtypSignature(in: videoData, at: 0))
    }

    // MARK: - MediaExportService Pipeline Tests
    func testPrepareLivePhotoFilesCreatesValidMetadataAndCleansUp() async throws {
        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let xmpInfo = XMPParser.extractAndParse(from: data)
        let processor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data))
        let extracted = try XCTUnwrap(processor.processMotionPhoto(data: data, xmpInfo: xmpInfo).data)

        let tempMP4 = FileManager.default.temporaryDirectory.appendingPathComponent("test_src_\(UUID().uuidString).mp4")
        try extracted.videoData.write(to: tempMP4)
        defer { try? FileManager.default.removeItem(at: tempMP4) }

        let prepared = try await MediaExportService.prepareLivePhotoFiles(
            imageData: extracted.imageData,
            videoURL: tempMP4,
            stillImageTime: 15
        )
        defer { prepared.cleanup() }

        // 验证静态图写入了匹配的 Apple Maker Dictionary ["17"]
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithURL(prepared.imageURL as CFURL, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any])
        let makerApple = try XCTUnwrap(props[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any])
        XCTAssertEqual(makerApple["17"] as? String, prepared.assetIdentifier)

        // 验证 MOV 写入了匹配的 QuickTime content.identifier
        let movAsset = AVAsset(url: prepared.videoURL)
        let metadata = try await movAsset.load(.metadata)
        let contentIdItem = metadata.first { ($0.key as? String) == "com.apple.quicktime.content.identifier" }
        let contentIdValue = try await contentIdItem?.load(.stringValue)
        XCTAssertEqual(contentIdValue, prepared.assetIdentifier)

        // 验证 cleanup 能彻底删除临时产物
        prepared.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.imageURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.videoURL.path))
    }

    func testGIFCreationAndZeroDurationGuard() async throws {
        let emptyURL = FileManager.default.temporaryDirectory.appendingPathComponent("empty_\(UUID().uuidString).mp4")
        let gifURL = FileManager.default.temporaryDirectory.appendingPathComponent("out_\(UUID().uuidString).gif")
        try Data().write(to: emptyURL)
        defer {
            try? FileManager.default.removeItem(at: emptyURL)
            try? FileManager.default.removeItem(at: gifURL)
        }

        let emptyAsset = AVAsset(url: emptyURL)
        do {
            try await MediaExportService.createGIFFile(from: emptyAsset, outputURL: gifURL)
            XCTFail("Expected invalid video to throw an error")
        } catch {
            XCTAssertTrue(true)
        }
    }

    // MARK: - Regression Tests
    func testXMPXPacketFallbackPreservesClosingTag() throws {
        let xml = """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description GCamera:MicroVideo="1" GCamera:MicroVideoOffset="123456"/>
        </rdf:RDF>
        <?xpacket end="w"?>
        """
        let payload = Data([0xFF, 0xD8, 0xFF, 0xE1]) + Data(xml.utf8) + Data(repeating: 0x00, count: 64)
        let extracted = try XCTUnwrap(XMPParser.extract(from: payload))
        let parsed = try XCTUnwrap(XMPParser.parse(data: extracted))
        XCTAssertEqual(parsed["GCamera:MicroVideo"], "1")
        XCTAssertEqual(parsed["GCamera:MicroVideoOffset"], "123456")
    }

    func testXMPContainerPreservesVideoLengthAndNonZeroPadding() throws {
        let xml = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description>
              <Container:Directory>
                <rdf:Seq>
                  <rdf:li><Container:Item Item:Mime="image/jpeg" Item:Semantic="Primary" Item:Padding="138"/></rdf:li>
                  <rdf:li><Container:Item Item:Mime="video/mp4" Item:Semantic="MotionPhoto" Item:Length="5421673" Item:Padding="0"/></rdf:li>
                  <rdf:li><Container:Item Item:Mime="image/jpeg" Item:Semantic="GainMap" Item:Length="50000" Item:Padding="0"/></rdf:li>
                </rdf:Seq>
              </Container:Directory>
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        """
        let parsed = try XCTUnwrap(XMPParser.parse(data: Data(xml.utf8)))
        XCTAssertEqual(parsed["Item:Padding"], "138")
        XCTAssertEqual(parsed["Item:Length"], "5421673")
    }

    func testPixelV1MicroVideoNotStolenByXiaomi() throws {
        // Pixel.jpg 带有 Google EXIF Make；即使传入 Pixel v1 的 MicroVideoOffset，也不应被小米处理器抢占
        let pixelData = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let v1XMP: [String: String] = [
            "GCamera:MicroVideo": "1",
            "GCamera:MicroVideoOffset": "1619843"
        ]
        let processor = MotionPhotoProcessorFactory.getProcessor(for: v1XMP, data: pixelData)
        XCTAssertEqual(processor?.brand, .pixel)
    }

    func testFindMP4OffsetWorksOnDataSlice() throws {
        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let expectedOffset = try XCTUnwrap(ISOBMFFHelper.findMP4Offset(in: data))

        let padded = Data(repeating: 0xAA, count: 128) + data
        let slice = padded.dropFirst(128) // startIndex == 128
        XCTAssertEqual(slice.startIndex, 128)
        XCTAssertEqual(ISOBMFFHelper.findMP4Offset(in: slice), expectedOffset)
    }

    func testPrepareLivePhotoFilesUsesMatchingExtensionForNonJPEG() async throws {
        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let xmpInfo = XMPParser.extractAndParse(from: data)
        let processor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data))
        let extracted = try XCTUnwrap(processor.processMotionPhoto(data: data, xmpInfo: xmpInfo).data)

        // 将静态图重编码为 PNG，验证临时文件不再硬编码为 .jpg
        let uiImage = try XCTUnwrap(UIImage(data: extracted.imageData))
        let pngData = try XCTUnwrap(uiImage.pngData())

        let tempMP4 = FileManager.default.temporaryDirectory.appendingPathComponent("test_png_\(UUID().uuidString).mp4")
        try extracted.videoData.write(to: tempMP4)
        defer { try? FileManager.default.removeItem(at: tempMP4) }

        let prepared = try await MediaExportService.prepareLivePhotoFiles(
            imageData: pngData,
            videoURL: tempMP4,
            stillImageTime: 0
        )
        defer { prepared.cleanup() }

        XCTAssertEqual(prepared.imageURL.pathExtension.lowercased(), "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.imageURL.path))
    }

    func testExtractCoverFrameDataPreservesMetadataAndProducesValidJPEG() async throws {
        let data = try Data(contentsOf: try sampleURL(named: "XiaomiNew"))
        let xmpInfo = XMPParser.extractAndParse(from: data)
        let processor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data))
        let extracted = try XCTUnwrap(processor.processMotionPhoto(data: data, xmpInfo: xmpInfo).data)

        let tempMP4 = FileManager.default.temporaryDirectory.appendingPathComponent("cover_test_\(UUID().uuidString).mp4")
        try extracted.videoData.write(to: tempMP4)
        defer { try? FileManager.default.removeItem(at: tempMP4) }

        let coverData = try await MediaExportService.extractCoverFrameData(
            from: tempMP4,
            at: 0.5,
            preservingMetadataFrom: extracted.imageData
        )
        XCTAssertGreaterThan(coverData.count, 1_000)
        XCTAssertNotNil(UIImage(data: coverData))
        XCTAssertNotNil(ISOBMFFHelper.extractExifCreationDate(from: coverData))
    }

    @MainActor
    func testRecentConversionStoreCapsAtThreeEntriesAndClears() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("recent_test_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = RecentConversionStore(directory: tempDir)
        let data = try Data(contentsOf: try sampleURL(named: "XiaomiNew"))
        let xmpInfo = XMPParser.extractAndParse(from: data)
        let processor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data))
        let extracted = try XCTUnwrap(processor.processMotionPhoto(data: data, xmpInfo: xmpInfo).data)

        for i in 1...4 {
            await store.recordConversion(imageData: extracted.imageData, durationSeconds: Double(i))
        }

        XCTAssertEqual(store.entries.count, 3)
        XCTAssertEqual(store.entries.first?.durationSeconds, 4.0)
        XCTAssertNotNil(store.image(for: store.entries[0]))

        store.clearHistory()
        XCTAssertTrue(store.entries.isEmpty)
    }

    @MainActor
    func testRecentConversionStoreCachesAndEvictsMutedPreviewVideos() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("recent_video_test_\(UUID().uuidString)", isDirectory: true)
        let srcMP4 = FileManager.default.temporaryDirectory.appendingPathComponent("recent_src_\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: tempDir)
            try? FileManager.default.removeItem(at: srcMP4)
        }

        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let xmpInfo = XMPParser.extractAndParse(from: data)
        let processor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data))
        let extracted = try XCTUnwrap(processor.processMotionPhoto(data: data, xmpInfo: xmpInfo).data)
        try extracted.videoData.write(to: srcMP4)

        let store = RecentConversionStore(directory: tempDir)
        for i in 1...4 {
            await store.recordConversion(
                imageData: extracted.imageData,
                videoURL: srcMP4,
                durationSeconds: Double(i)
            )
        }

        XCTAssertEqual(store.entries.count, 3)
        for entry in store.entries {
            let cachedVideoURL = try XCTUnwrap(store.videoURL(for: entry))
            XCTAssertTrue(FileManager.default.fileExists(atPath: cachedVideoURL.path))
            let tracks = try await AVURLAsset(url: cachedVideoURL).load(.tracks)
            XCTAssertFalse(tracks.contains(where: { $0.mediaType == .audio }), "Cached preview video must be muted")
        }

        // Verify evicted entry's .mp4 was removed from disk (only 3 .mp4 files remain)
        let filesInDir = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        let mp4Files = filesInDir.filter { $0.hasSuffix(".mp4") }
        XCTAssertEqual(mp4Files.count, 3)

        // Verify backward compatibility with legacy index.json without videoFileName
        let legacyJSON = """
        [
          {
            "id": "\(UUID().uuidString)",
            "fileName": "\(try XCTUnwrap(store.entries.first?.fileName))",
            "durationSeconds": 2.0,
            "createdAt": 0
          }
        ]
        """
        let decodedLegacy = try JSONDecoder().decode([RecentConversionEntry].self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decodedLegacy.count, 1)
        XCTAssertNil(decodedLegacy[0].videoFileName)

        store.clearHistory()
        XCTAssertTrue(store.entries.isEmpty)
    }

    @MainActor
    func testRecentConversionStoreClearHistoryDuringRecordDoesNotResurrectEntry() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("recent_race_test_\(UUID().uuidString)", isDirectory: true)
        let srcMP4 = FileManager.default.temporaryDirectory.appendingPathComponent("recent_race_src_\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: tempDir)
            try? FileManager.default.removeItem(at: srcMP4)
        }

        let data = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let xmpInfo = XMPParser.extractAndParse(from: data)
        let processor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data))
        let extracted = try XCTUnwrap(processor.processMotionPhoto(data: data, xmpInfo: xmpInfo).data)
        try extracted.videoData.write(to: srcMP4)

        let store = RecentConversionStore(directory: tempDir)
        let recordTask = Task {
            await store.recordConversion(
                imageData: extracted.imageData,
                videoURL: srcMP4,
                durationSeconds: 2.0
            )
        }

        // Yield so `recordTask` enters its background export before `clearHistory()` runs
        try await Task.sleep(nanoseconds: 20_000_000)
        store.clearHistory()
        await recordTask.value

        XCTAssertTrue(store.entries.isEmpty, "In-flight recordConversion must not resurrect entries after clearHistory()")
    }

    func testHeroDeckCyclicRelativeSlot() {
        // Initial activeIndex = 0: [0] -> 0, [1] -> +1, [2] -> -1
        XCTAssertEqual(HeroDeckMath.cyclicRelativeSlot(for: 0, activeIndex: 0), 0, accuracy: 0.001)
        XCTAssertEqual(HeroDeckMath.cyclicRelativeSlot(for: 1, activeIndex: 0), 1, accuracy: 0.001)
        XCTAssertEqual(HeroDeckMath.cyclicRelativeSlot(for: 2, activeIndex: 0), -1, accuracy: 0.001)

        // activeIndex = 1: [0] -> -1, [1] -> 0, [2] -> +1
        XCTAssertEqual(HeroDeckMath.cyclicRelativeSlot(for: 0, activeIndex: 1), -1, accuracy: 0.001)
        XCTAssertEqual(HeroDeckMath.cyclicRelativeSlot(for: 1, activeIndex: 1), 0, accuracy: 0.001)
        XCTAssertEqual(HeroDeckMath.cyclicRelativeSlot(for: 2, activeIndex: 1), 1, accuracy: 0.001)

        // Dragging right past +1.5 wraps slot +1 to -1.4 (e.g. dragProgress = +0.6 -> +1.6 -> -1.4)
        XCTAssertEqual(
            HeroDeckMath.cyclicRelativeSlot(for: 1, activeIndex: 0, dragProgress: 0.6),
            -1.4,
            accuracy: 0.001
        )
        // Dragging left past -1.5 wraps slot -1 to +1.4 (e.g. dragProgress = -0.6 -> -1.6 -> +1.4)
        XCTAssertEqual(
            HeroDeckMath.cyclicRelativeSlot(for: 2, activeIndex: 0, dragProgress: -0.6),
            1.4,
            accuracy: 0.001
        )
    }

    func testHeroDeckPredictedTargetIndex() {
        // Small drag stays on current index
        XCTAssertEqual(
            HeroDeckMath.predictedTargetIndex(currentActiveIndex: 0, translationX: 20, predictedEndTranslationX: 25),
            0
        )

        // Drag right past threshold brings index 2 (left card) to center
        XCTAssertEqual(
            HeroDeckMath.predictedTargetIndex(currentActiveIndex: 0, translationX: 70, predictedEndTranslationX: 80),
            2
        )

        // Drag left past threshold brings index 1 (right card) to center
        XCTAssertEqual(
            HeroDeckMath.predictedTargetIndex(currentActiveIndex: 0, translationX: -70, predictedEndTranslationX: -80),
            1
        )

        // Fast left flick with modest translation but large predicted end translation advances index
        XCTAssertEqual(
            HeroDeckMath.predictedTargetIndex(currentActiveIndex: 1, translationX: -24, predictedEndTranslationX: -140),
            2
        )

        // Fast right flick wraps from 0 to 2
        XCTAssertEqual(
            HeroDeckMath.predictedTargetIndex(currentActiveIndex: 0, translationX: 24, predictedEndTranslationX: 140),
            2
        )
    }

    // MARK: - Local Samples Verification (samples/local)
    private struct LocalManifest: Decodable {
        struct FileItem: Decodable {
            let path: String
            let size_bytes: Int
            let sha256: String
            let kind: String?
            let pair: String?
            let expected: String?
            let embedded_video_payload: Bool?
        }
        let files: [FileItem]
    }

    private var localSamplesManifestURL: URL? {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let manifest = repoRoot.appendingPathComponent("samples/local/manifest.json")
        guard FileManager.default.fileExists(atPath: manifest.path) else {
            return nil
        }
        return manifest
    }

    func testLocalSamplesAllCases() async throws {
        guard let manifestURL = localSamplesManifestURL else {
            print("Notice: samples/local/manifest.json not present in environment. Skipping local samples test.")
            return
        }

        let repoRoot = manifestURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(LocalManifest.self, from: manifestData)

        XCTAssertFalse(manifest.files.isEmpty, "Manifest should contain test files")

        for fileItem in manifest.files {
            let fileURL = repoRoot.appendingPathComponent(fileItem.path)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                XCTFail("Missing local sample file: \(fileItem.path)")
                continue
            }

            let fileData = try Data(contentsOf: fileURL)
            XCTAssertEqual(fileData.count, fileItem.size_bytes, "File size mismatch for \(fileItem.path)")

            let kind = fileItem.kind ?? ""
            let expected = fileItem.expected ?? "positive"

            if kind == "apple-pair" || kind == "vivo-live" || expected == "positive-pair" {
                // Dual-file / Pair test
                if let pairPath = fileItem.pair {
                    let pairURL = repoRoot.appendingPathComponent(pairPath)
                    XCTAssertTrue(FileManager.default.fileExists(atPath: pairURL.path), "Pair file must exist: \(pairPath)")

                    let isImage = fileItem.path.hasSuffix(".jpg") || fileItem.path.hasSuffix(".jpeg") || fileItem.path.hasSuffix(".HEIC") || fileItem.path.hasSuffix(".heic")
                    if isImage {
                        let prepared = try await MediaExportService.prepareLivePhotoFiles(
                            imageData: fileData,
                            videoURL: pairURL,
                            stillImageTime: 0
                        )
                        defer { prepared.cleanup() }

                        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.imageURL.path))
                        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.videoURL.path))

                        let prepSource = try XCTUnwrap(CGImageSourceCreateWithURL(prepared.imageURL as CFURL, nil))
                        let prepProps = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(prepSource, 0, nil) as? [String: Any])
                        let makerApple = try XCTUnwrap(prepProps[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any])
                        XCTAssertEqual(makerApple["17"] as? String, prepared.assetIdentifier)

                        let movAsset = AVAsset(url: prepared.videoURL)
                        let movMetadata = try await movAsset.load(.metadata)
                        let contentIdItem = movMetadata.first { ($0.key as? String) == "com.apple.quicktime.content.identifier" }
                        let contentIdValue = try await contentIdItem?.load(.stringValue)
                        XCTAssertEqual(contentIdValue, prepared.assetIdentifier)
                    }
                }
            } else if expected == "negative" || expected == "no-motion-photo" {
                // Negative / Non-Motion Photo validation
                let xmpInfo = XMPParser.extractAndParse(from: fileData)
                let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: fileData)
                if let proc = processor {
                    let result = proc.processMotionPhoto(data: fileData, xmpInfo: xmpInfo)
                    XCTAssertFalse(
                        result.success,
                        "Expected negative result for non-motion photo \(fileItem.path), but processing succeeded"
                    )
                } else {
                    XCTAssertNil(processor, "Expected nil processor for \(fileItem.path)")
                }
            } else {
                // Single-file embedded Motion Photo (positive)
                let xmpInfo = XMPParser.extractAndParse(from: fileData)
                let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: fileData)
                XCTAssertNotNil(processor, "Expected processor for positive sample: \(fileItem.path)")

                guard let proc = processor else { continue }
                let result = proc.processMotionPhoto(data: fileData, xmpInfo: xmpInfo)
                XCTAssertTrue(result.success, "processMotionPhoto failed for \(fileItem.path): \(result.errorMessage ?? "")")

                guard let extracted = result.data else {
                    XCTFail("Missing extracted data for \(fileItem.path)")
                    continue
                }

                // 1. Verify valid image payload
                let imageSource = CGImageSourceCreateWithData(extracted.imageData as CFData, nil)
                XCTAssertNotNil(imageSource, "Extracted image data must be readable by CGImageSource for \(fileItem.path)")
                let imageProps = imageSource.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) }
                XCTAssertNotNil(imageProps, "Image properties must be extractable for \(fileItem.path)")

                // 2. Verify valid video payload starting with ftyp
                XCTAssertTrue(
                    ISOBMFFHelper.hasFtypSignature(in: extracted.videoData, at: 0),
                    "Extracted video data must begin with ftyp box for \(fileItem.path)"
                )

                // 3. Verify video can be loaded and played by AVAsset
                let tempVideo = FileManager.default.temporaryDirectory
                    .appendingPathComponent("test_local_\(UUID().uuidString).mp4")
                try extracted.videoData.write(to: tempVideo)
                defer { try? FileManager.default.removeItem(at: tempVideo) }

                let avAsset = AVAsset(url: tempVideo)
                let duration = try await avAsset.load(.duration)
                let tracks = try await avAsset.loadTracks(withMediaType: .video)
                XCTAssertFalse(tracks.isEmpty, "Video must have at least one video track for \(fileItem.path)")
                XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0, "Video duration must be > 0 for \(fileItem.path)")

                // 4. Verify end-to-end Live Photo preparation
                let prepared = try await MediaExportService.prepareLivePhotoFiles(
                    imageData: extracted.imageData,
                    videoURL: tempVideo,
                    stillImageTime: extracted.stillImageTime
                )
                defer { prepared.cleanup() }

                XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.imageURL.path))
                XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.videoURL.path))

                let prepSource = try XCTUnwrap(CGImageSourceCreateWithURL(prepared.imageURL as CFURL, nil))
                let prepProps = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(prepSource, 0, nil) as? [String: Any])
                let makerApple = try XCTUnwrap(prepProps[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any])
                XCTAssertEqual(makerApple["17"] as? String, prepared.assetIdentifier)

                let movAsset = AVAsset(url: prepared.videoURL)
                let movMetadata = try await movAsset.load(.metadata)
                let contentIdItem = movMetadata.first { ($0.key as? String) == "com.apple.quicktime.content.identifier" }
                let contentIdValue = try await contentIdItem?.load(.stringValue)
                XCTAssertEqual(contentIdValue, prepared.assetIdentifier)
            }
        }
    }

    // MARK: - iPhone Duo Adaptive Layout Metrics Tests

    func testDuoOuterScreenMetrics() {
        let metrics = AdaptiveLayoutMetrics(
            containerSize: CGSize(width: 466, height: 678),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular,
            hinge: HingeStateSnapshot(status: .closed, angleDegrees: 0)
        )

        XCTAssertEqual(metrics.layoutMode, .compactVertical)
        XCTAssertTrue(metrics.isCompactShortScreen)
        XCTAssertFalse(metrics.isWideSplit)
        XCTAssertEqual(metrics.batchGridColumns, 3)
        XCTAssertEqual(metrics.keyframeDetentMode, .largeOnly)
        XCTAssertFalse(metrics.usesSideBySideKeyframeLayout)
        XCTAssertEqual(metrics.hingeAvoidanceGap, 0)
        XCTAssertGreaterThan(metrics.heroDeckScale, 0.95)
    }

    func testDuoUnfoldedPortraitMetrics() {
        let metrics = AdaptiveLayoutMetrics(
            containerSize: CGSize(width: 669, height: 951),
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular,
            hinge: HingeStateSnapshot(status: .fullyOpen, angleDegrees: 180)
        )

        XCTAssertEqual(metrics.layoutMode, .unfoldedWideSplit)
        XCTAssertFalse(metrics.isCompactShortScreen)
        XCTAssertTrue(metrics.isWideSplit)
        XCTAssertTrue(metrics.prefersHorizontalSplitAxis)
        XCTAssertEqual(metrics.batchGridColumns, 4)
        XCTAssertEqual(metrics.keyframeDetentMode, .mediumAndLarge)
        XCTAssertFalse(metrics.usesSideBySideKeyframeLayout)
        XCTAssertEqual(metrics.hingeAvoidanceGap, 24)
    }

    func testDuoUnfoldedLandscapeMetrics() {
        let metrics = AdaptiveLayoutMetrics(
            containerSize: CGSize(width: 951, height: 669),
            horizontalSizeClass: .regular,
            verticalSizeClass: .compact,
            hinge: HingeStateSnapshot(status: .fullyOpen, angleDegrees: 180)
        )

        XCTAssertEqual(metrics.layoutMode, .unfoldedWideSplit)
        XCTAssertTrue(metrics.isCompactShortScreen)
        XCTAssertTrue(metrics.isWideSplit)
        XCTAssertTrue(metrics.prefersHorizontalSplitAxis)
        XCTAssertEqual(metrics.batchGridColumns, 5)
        XCTAssertEqual(metrics.keyframeDetentMode, .largeOnly)
        XCTAssertTrue(metrics.usesSideBySideKeyframeLayout)
        XCTAssertEqual(metrics.hingeAvoidanceGap, 24)
    }

    func testDuoPartiallyOpenFlexPostureMetrics() {
        let portraitFlex = AdaptiveLayoutMetrics(
            containerSize: CGSize(width: 669, height: 951),
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular,
            hinge: HingeStateSnapshot(status: .partiallyOpen, angleDegrees: 115)
        )
        XCTAssertEqual(portraitFlex.layoutMode, .hingeFlexSplit)
        XCTAssertTrue(portraitFlex.isWideSplit)
        XCTAssertFalse(portraitFlex.prefersHorizontalSplitAxis)
        XCTAssertEqual(portraitFlex.hingeAvoidanceGap, 28)

        let landscapeFlex = AdaptiveLayoutMetrics(
            containerSize: CGSize(width: 951, height: 669),
            horizontalSizeClass: .regular,
            verticalSizeClass: .compact,
            hinge: HingeStateSnapshot(status: .partiallyOpen, angleDegrees: 115)
        )
        XCTAssertEqual(landscapeFlex.layoutMode, .hingeFlexSplit)
        XCTAssertTrue(landscapeFlex.isWideSplit)
        XCTAssertTrue(landscapeFlex.prefersHorizontalSplitAxis)
        XCTAssertEqual(landscapeFlex.hingeAvoidanceGap, 28)
    }

    func testHingeStateSnapshotDebounce() {
        let initial = HingeStateSnapshot(status: .partiallyOpen, angleDegrees: 110.0)
        let jittered = HingeStateSnapshot.resolveNext(
            current: initial,
            rawStatus: .partiallyOpen,
            rawAngleDegrees: 111.2
        )
        XCTAssertEqual(jittered, initial)

        let moved = HingeStateSnapshot.resolveNext(
            current: initial,
            rawStatus: .partiallyOpen,
            rawAngleDegrees: 114.0
        )
        XCTAssertEqual(moved.angleDegrees, 114.0)

        let statusChanged = HingeStateSnapshot.resolveNext(
            current: initial,
            rawStatus: .fullyOpen,
            rawAngleDegrees: 111.0
        )
        XCTAssertEqual(statusChanged.status, .fullyOpen)
    }

    func testSafeAreaHorizontalPaddingAvoidsEdgeInsets() {
        let noEdge = AdaptiveLayoutMetrics(
            containerSize: CGSize(width: 466, height: 678),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular
        )
        XCTAssertEqual(noEdge.horizontalPadding, 20)

        let withSideBar = AdaptiveLayoutMetrics(
            containerSize: CGSize(width: 466, height: 678),
            safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20),
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular
        )
        XCTAssertEqual(withSideBar.horizontalPadding, 32)
    }

    // MARK: - Live Photo -> Motion Photo (Reverse Conversion) Tests

    private func makeSyntheticHEICWithMetadata(from jpegData: Data, orientation: Int = 6, make: String = "Apple", dateOriginal: String = "2025:06:15 14:30:00") throws -> Data {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(jpegData as CFData, nil))
        let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let out = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(out as CFMutableData, AVFileType.heic.rawValue as CFString, 1, nil))
        let props: [String: Any] = [
            kCGImagePropertyOrientation as String: orientation,
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: make,
                kCGImagePropertyTIFFOrientation as String: orientation
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: dateOriginal
            ]
        ]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    func testLiveToMotion7BrandsRoundTrip() async throws {
        // 1. 从样图拆出合法视频流并封装为带 QuickTime 元数据的 .mov，模拟系统 Live Photo 配对资源
        let sampleData = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let sampleXMP = XMPParser.extractAndParse(from: sampleData)
        let sampleProcessor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: sampleXMP, data: sampleData))
        let parsedSample = sampleProcessor.processMotionPhoto(data: sampleData, xmpInfo: sampleXMP)
        let sampleMotion = try XCTUnwrap(parsedSample.data)

        let tempRoot = FileManager.default.temporaryDirectory
        let sourceMP4URL = tempRoot.appendingPathComponent("test_src_\(UUID().uuidString).mp4")
        let heicURL = tempRoot.appendingPathComponent("test_src_\(UUID().uuidString).heic")
        defer {
            MediaExportService.removeIfInTemporaryDirectory(sourceMP4URL)
            MediaExportService.removeIfInTemporaryDirectory(heicURL)
        }
        try sampleMotion.videoData.write(to: sourceMP4URL)

        let preparedLive = try await MediaExportService.prepareLivePhotoFiles(
            imageData: sampleMotion.imageData,
            videoURL: sourceMP4URL,
            stillImageTime: 5
        )
        defer { preparedLive.cleanup() }

        let heicData = try makeSyntheticHEICWithMetadata(
            from: sampleMotion.imageData,
            orientation: 6,
            make: "Apple",
            dateOriginal: "2025:06:15 14:30:00"
        )
        try heicData.write(to: heicURL)

        // 2. 遍历全部 7 类品牌执行逆向封装与正向解析闭环校验
        let allBrands = MotionPhotoProcessorFactory.getAllSupportedBrands()
        XCTAssertEqual(allBrands.count, 7)

        for brand in allBrands {
            let exportedURL = try await MediaExportService.exportMotionPhoto(
                imageURL: heicURL,
                videoURL: preparedLive.videoURL,
                targetBrand: brand
            )
            defer { MediaExportService.removeIfInTemporaryDirectory(exportedURL) }

            XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
            let exportedData = try Data(contentsOf: exportedURL)
            let xmpInfo = XMPParser.extractAndParse(from: exportedData)

            if brand == .universal {
                XCTAssertTrue(xmpInfo.isEmpty, "Universal should not inject vendor Motion XMP")
            } else {
                XCTAssertFalse(xmpInfo.isEmpty, "Brand \(brand.rawValue) should contain XMP")
            }

            let detectedProcessor = try XCTUnwrap(
                MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: exportedData),
                "Failed to detect processor for brand \(brand.rawValue)"
            )
            XCTAssertEqual(detectedProcessor.brand, brand, "Brand mismatch for \(brand.rawValue)")

            let roundTrip = detectedProcessor.processMotionPhoto(data: exportedData, xmpInfo: xmpInfo)
            XCTAssertTrue(roundTrip.success, "Round-trip parse failed for \(brand.rawValue)")
            let decoded = try XCTUnwrap(roundTrip.data)
            XCTAssertGreaterThan(decoded.videoData.count, 10_000)
            XCTAssertTrue(ISOBMFFHelper.hasFtypSignature(in: decoded.videoData, at: 0))

            if brand == .samsung {
                XCTAssertNil(decoded.videoData.range(of: Data("MotionPhoto_Versionmpv3".utf8)), "Samsung SEF trailer should be stripped from videoData")
                XCTAssertNil(decoded.videoData.range(of: Data("SEFT".utf8)))
            }

            // 验证 HEIC->JPEG 元数据保留（方向与拍摄时间）
            let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(decoded.imageData as CFData, nil))
            let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any])
            XCTAssertEqual(props[kCGImagePropertyOrientation as String] as? Int, 6)
            let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
            XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String, "2025:06:15 14:30:00")

            // 验证导出的 MP4 可被 AVAsset 正常读取时长
            let verifyMP4URL = tempRoot.appendingPathComponent("verify_\(UUID().uuidString).mp4")
            defer { MediaExportService.removeIfInTemporaryDirectory(verifyMP4URL) }
            try decoded.videoData.write(to: verifyMP4URL)
            let duration = try await AVAsset(url: verifyMP4URL).load(.duration)
            XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0.1)
        }
    }

    func testMotionPhotoEncoderStripsConflictingXMPAndMakes() async throws {
        // 使用带小米 XMP 的样图作为输入，重新封装为 Huawei，验证旧 XMP 被剥离且不会误命中 Xiaomi
        let xiaomiData = try Data(contentsOf: try sampleURL(named: "XiaomiNew"))
        let xiaomiXMP = XMPParser.extractAndParse(from: xiaomiData)
        let xiaomiProc = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: xiaomiXMP, data: xiaomiData))
        let parsed = try XCTUnwrap(xiaomiProc.processMotionPhoto(data: xiaomiData, xmpInfo: xiaomiXMP).data)

        let tempRoot = FileManager.default.temporaryDirectory
        let videoURL = tempRoot.appendingPathComponent("test_conflict_\(UUID().uuidString).mp4")
        defer { MediaExportService.removeIfInTemporaryDirectory(videoURL) }
        try parsed.videoData.write(to: videoURL)

        let reencoded = try await MotionPhotoEncoder.encode(
            imageData: parsed.imageData,
            videoURL: videoURL,
            targetBrand: .huawei
        )

        let newXMP = XMPParser.extractAndParse(from: reencoded)
        XCTAssertNil(newXMP["GCamera:MicroVideo"])
        XCTAssertNil(newXMP["GCamera:MicroVideoOffset"])
        XCTAssertEqual(newXMP["HwCamera:MovingPicture"], "1")

        let detected = MotionPhotoProcessorFactory.getProcessor(for: newXMP, data: reencoded)
        XCTAssertEqual(detected?.brand, .huawei)

        // 验证直接传入完整 Motion Photo JPEG（含 EOI 之后的旧 MP4 字节）时，旧视频尾部与 XMP 均被剥离
        let pixelRawData = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let strippedPixel = MotionPhotoEncoder.stripXMPApp1Segments(from: pixelRawData)
        XCTAssertEqual(strippedPixel.suffix(2), Data([0xFF, 0xD9]))
        XCTAssertNil(ISOBMFFHelper.findMP4Offset(in: strippedPixel), "Old embedded MP4 after EOI must be stripped")
        XCTAssertTrue(XMPParser.extractAndParse(from: strippedPixel).isEmpty)

        let reencodedFromRawPixel = try await MotionPhotoEncoder.encode(
            imageData: pixelRawData,
            videoURL: videoURL,
            targetBrand: .huawei
        )
        let huaweiXMP = XMPParser.extractAndParse(from: reencodedFromRawPixel)
        let huaweiProc = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: huaweiXMP, data: reencodedFromRawPixel))
        XCTAssertEqual(huaweiProc.brand, .huawei)
        let huaweiParsed = try XCTUnwrap(huaweiProc.processMotionPhoto(data: reencodedFromRawPixel, xmpInfo: huaweiXMP).data)
        XCTAssertNil(ISOBMFFHelper.findMP4Offset(in: huaweiParsed.imageData))
    }

    func testExtractedLivePhotoAndTempDirectoryCleanupGuard() throws {
        let tempRoot = FileManager.default.temporaryDirectory
        let imgURL = tempRoot.appendingPathComponent("cleanup_img_\(UUID().uuidString).heic")
        let vidURL = tempRoot.appendingPathComponent("cleanup_vid_\(UUID().uuidString).mov")
        try Data("img".utf8).write(to: imgURL)
        try Data("vid".utf8).write(to: vidURL)

        let extracted = ExtractedLivePhoto(imageURL: imgURL, videoURL: vidURL, creationDate: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imgURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vidURL.path))

        extracted.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: imgURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: vidURL.path))

        // 验证非临时目录文件不会被 removeIfInTemporaryDirectory 误删
        let sample = try sampleURL(named: "Pixel")
        MediaExportService.removeIfInTemporaryDirectory(sample)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sample.path))

        // 验证 nil URL 不会崩溃
        MediaExportService.removeIfInTemporaryDirectory(nil)
    }

    private func makePlainJPEGData(from jpegData: Data, includeExifDate: Bool) throws -> Data {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(jpegData as CFData, nil))
        let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let out = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(out as CFMutableData, AVFileType.jpg.rawValue as CFString, 1, nil))
        var props: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: 0.9
        ]
        if includeExifDate {
            props[kCGImagePropertyExifDictionary as String] = [
                kCGImagePropertyExifDateTimeOriginal as String: "2025:07:10 11:22:33"
            ]
        }
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    func testCustomImageDataAndPlainVideoWithoutStillTime7BrandsRoundTrip() async throws {
        let sampleData = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let sampleXMP = XMPParser.extractAndParse(from: sampleData)
        let sampleProcessor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: sampleXMP, data: sampleData))
        let sampleMotion = try XCTUnwrap(sampleProcessor.processMotionPhoto(data: sampleData, xmpInfo: sampleXMP).data)

        let tempRoot = FileManager.default.temporaryDirectory
        let rawMP4URL = tempRoot.appendingPathComponent("plain_raw_\(UUID().uuidString).mp4")
        let plainVideoURL = tempRoot.appendingPathComponent("plain_nometa_\(UUID().uuidString).mp4")
        defer {
            MediaExportService.removeIfInTemporaryDirectory(rawMP4URL)
            MediaExportService.removeIfInTemporaryDirectory(plainVideoURL)
        }
        try sampleMotion.videoData.write(to: rawMP4URL)

        // 生成纯视频流（剥离一切元数据轨道，确保无 com.apple.quicktime.still-image-time）
        let remuxedMP4 = try await MotionPhotoEncoder.remuxToMP4Data(from: rawMP4URL)
        try remuxedMP4.write(to: plainVideoURL)

        let plainAsset = AVAsset(url: plainVideoURL)
        let metadataTracks = try await plainAsset.loadTracks(withMediaType: .metadata)
        XCTAssertTrue(metadataTracks.isEmpty, "Plain video must not have timed metadata tracks")
        let containerMetadata = try await plainAsset.load(.metadata)
        XCTAssertFalse(containerMetadata.contains { ($0.key as? String) == "com.apple.quicktime.still-image-time" })

        let durationSeconds = CMTimeGetSeconds(try await plainAsset.load(.duration))
        XCTAssertGreaterThan(durationSeconds, 0.1)
        let expectedMidpointUs = Int64(round((durationSeconds / 2.0) * 1_000_000.0))
        let resolvedUs = await MotionPhotoEncoder.readStillImageTimestampUs(from: plainVideoURL)
        XCTAssertLessThanOrEqual(abs(resolvedUs - expectedMidpointUs), 1_000)

        let plainJPEGData = try makePlainJPEGData(from: sampleMotion.imageData, includeExifDate: true)
        let plainHEICData = try makeSyntheticHEICWithMetadata(
            from: sampleMotion.imageData,
            orientation: 8,
            make: "Canon",
            dateOriginal: "2025:08:20 09:15:30"
        )

        let inputs: [(label: String, data: Data, expectedOrientation: Int?, expectedDate: String?)] = [
            ("JPEG", plainJPEGData, nil, "2025:07:10 11:22:33"),
            ("HEIC", plainHEICData, 8, "2025:08:20 09:15:30")
        ]

        let allBrands = MotionPhotoProcessorFactory.getAllSupportedBrands()
        XCTAssertEqual(allBrands.count, 7)

        for input in inputs {
            for brand in allBrands {
                let exportedURL = try await MediaExportService.exportMotionPhoto(
                    imageData: input.data,
                    videoURL: plainVideoURL,
                    targetBrand: brand
                )
                defer { MediaExportService.removeIfInTemporaryDirectory(exportedURL) }

                XCTAssertEqual(exportedURL.pathExtension.lowercased(), "jpg")
                XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))

                let exportedData = try Data(contentsOf: exportedURL)
                let xmpInfo = XMPParser.extractAndParse(from: exportedData)

                if brand == .universal {
                    XCTAssertTrue(xmpInfo.isEmpty)
                } else {
                    let tsString = xmpInfo["GCamera:MotionPhotoPresentationTimestampUs"]
                        ?? xmpInfo["GCamera:MicroVideoPresentationTimestampUs"]
                    let parsedTs = try XCTUnwrap(Int64(tsString ?? ""), "Missing midpoint timestamp for \(input.label)/\(brand.rawValue)")
                    XCTAssertLessThanOrEqual(abs(parsedTs - expectedMidpointUs), 1_000)
                }

                let detectedProcessor = try XCTUnwrap(
                    MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: exportedData),
                    "Processor not detected for \(input.label)/\(brand.rawValue)"
                )
                XCTAssertEqual(detectedProcessor.brand, brand)

                let roundTrip = detectedProcessor.processMotionPhoto(data: exportedData, xmpInfo: xmpInfo)
                XCTAssertTrue(roundTrip.success)
                let decoded = try XCTUnwrap(roundTrip.data)
                XCTAssertTrue(ISOBMFFHelper.hasFtypSignature(in: decoded.videoData, at: 0))

                if brand == .samsung {
                    XCTAssertNil(decoded.videoData.range(of: Data("MotionPhoto_Versionmpv3".utf8)))
                    XCTAssertNil(decoded.videoData.range(of: Data("SEFT".utf8)))
                }

                let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(decoded.imageData as CFData, nil))
                let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any])
                if let expectedOrientation = input.expectedOrientation {
                    XCTAssertEqual(props[kCGImagePropertyOrientation as String] as? Int, expectedOrientation)
                }
                if let expectedDate = input.expectedDate {
                    let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
                    XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String, expectedDate)
                }

                MediaExportService.removeIfInTemporaryDirectory(exportedURL)
                XCTAssertFalse(FileManager.default.fileExists(atPath: exportedURL.path))
            }
        }
    }

    func testCreationDateFallbackAndRemuxTempFileCleanup() async throws {
        let sampleData = try Data(contentsOf: try sampleURL(named: "Pixel"))
        let sampleXMP = XMPParser.extractAndParse(from: sampleData)
        let sampleProcessor = try XCTUnwrap(MotionPhotoProcessorFactory.getProcessor(for: sampleXMP, data: sampleData))
        let sampleMotion = try XCTUnwrap(sampleProcessor.processMotionPhoto(data: sampleData, xmpInfo: sampleXMP).data)

        let tempRoot = FileManager.default.temporaryDirectory
        let videoURL = tempRoot.appendingPathComponent("test_date_vid_\(UUID().uuidString).mp4")
        defer { MediaExportService.removeIfInTemporaryDirectory(videoURL) }
        try sampleMotion.videoData.write(to: videoURL)

        // 构造无 EXIF 日期的普通 JPEG Data
        let noDateJPEG = try makePlainJPEGData(from: sampleMotion.imageData, includeExifDate: false)
        XCTAssertNil(ISOBMFFHelper.extractExifCreationDate(from: noDateJPEG))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let targetDate = try XCTUnwrap(formatter.date(from: "2024:11:05 18:20:30"))

        let remuxBefore = (try? FileManager.default.contentsOfDirectory(atPath: tempRoot.path))?
            .filter { $0.hasPrefix("motion_remux_") } ?? []

        let exportedURL = try await MediaExportService.exportMotionPhoto(
            imageData: noDateJPEG,
            videoURL: videoURL,
            targetBrand: .pixel,
            creationDate: targetDate
        )
        defer { MediaExportService.removeIfInTemporaryDirectory(exportedURL) }

        let remuxAfter = (try? FileManager.default.contentsOfDirectory(atPath: tempRoot.path))?
            .filter { $0.hasPrefix("motion_remux_") } ?? []
        XCTAssertEqual(remuxAfter.count, remuxBefore.count, "Intermediate motion_remux_* temp files must be cleaned up")

        let exportedData = try Data(contentsOf: exportedURL)
        let extractedDate = try XCTUnwrap(ISOBMFFHelper.extractExifCreationDate(from: exportedData))
        XCTAssertLessThan(abs(extractedDate.timeIntervalSince(targetDate)), 1.0)

        let exportedAttrs = try FileManager.default.attributesOfItem(atPath: exportedURL.path)
        let fileCreationDate = try XCTUnwrap(exportedAttrs[.creationDate] as? Date)
        let fileModificationDate = try XCTUnwrap(exportedAttrs[.modificationDate] as? Date)
        XCTAssertLessThan(abs(fileCreationDate.timeIntervalSince(targetDate)), 1.0)
        XCTAssertLessThan(abs(fileModificationDate.timeIntervalSince(targetDate)), 1.0)

        MediaExportService.removeIfInTemporaryDirectory(exportedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportedURL.path))

        // 验证不传 creationDate 时，自动从源图 EXIF DateTimeOriginal 继承并同步输出 .jpg 文件时间戳
        let exifJPEG = try makePlainJPEGData(from: sampleMotion.imageData, includeExifDate: true)
        let expectedExifDate = try XCTUnwrap(formatter.date(from: "2025:07:10 11:22:33"))
        let exifExportedURL = try await MediaExportService.exportMotionPhoto(
            imageData: exifJPEG,
            videoURL: videoURL,
            targetBrand: .pixel
        )
        defer { MediaExportService.removeIfInTemporaryDirectory(exifExportedURL) }

        let exifAttrs = try FileManager.default.attributesOfItem(atPath: exifExportedURL.path)
        let exifFileCreationDate = try XCTUnwrap(exifAttrs[.creationDate] as? Date)
        let exifFileModificationDate = try XCTUnwrap(exifAttrs[.modificationDate] as? Date)
        XCTAssertLessThan(abs(exifFileCreationDate.timeIntervalSince(expectedExifDate)), 1.0)
        XCTAssertLessThan(abs(exifFileModificationDate.timeIntervalSince(expectedExifDate)), 1.0)
    }
}
