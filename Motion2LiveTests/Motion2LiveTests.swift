//
//  Motion2LiveTests.swift
//  Motion2LiveTests
//

import XCTest
import AVFoundation
import ImageIO
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
}
