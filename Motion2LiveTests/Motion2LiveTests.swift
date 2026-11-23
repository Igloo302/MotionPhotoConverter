//
//  Motion2LiveTests.swift
//  Motion2LiveTests
//

import XCTest
import AVFoundation
import ImageIO
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
}
