//
//  XMPParser.swift
//  Motion2Live
//
//  XMP metadata extraction & parsing utilities and structured OSLog logging.
//

import Foundation
import os

// MARK: - Structured App Logger
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.igloo.MotionPhotoConverter"

    static let parser = Logger(subsystem: subsystem, category: "Parser")
    static let export = Logger(subsystem: subsystem, category: "Export")
    static let picker = Logger(subsystem: subsystem, category: "Picker")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}

// MARK: - XMP Parser
enum XMPParser {
    private static let xmpMetaStart = Data("<x:xmpmeta".utf8)
    private static let xmpMetaEnd = Data("</x:xmpmeta>".utf8)
    private static let xpacketBegin = Data("<?xpacket begin=".utf8)
    private static let xpacketEnd = Data("<?xpacket end=".utf8)
    private static let processingInstructionEnd = Data("?>".utf8)
    private static let headerScanLimit = 512 * 1024

    static func extract(from data: Data) -> Data? {
        guard !data.isEmpty else { return nil }

        let headEnd = min(data.endIndex, data.startIndex + headerScanLimit)
        if let foundInHead = extractSlice(from: data, in: data.startIndex..<headEnd) {
            return foundInHead
        }

        // JPEG 的 XMP 始终位于头部 APP1 段，无需扫描后续图像与视频主体
        let isJPEG = data.count >= 2 &&
            data[data.startIndex] == 0xFF &&
            data[data.index(after: data.startIndex)] == 0xD8
        if isJPEG || data.count <= headerScanLimit {
            return nil
        }

        // HEIC/AVIF 等容器的 meta box 可能位于文件尾部
        let tailStart = max(headEnd, data.endIndex - headerScanLimit)
        return extractSlice(from: data, in: tailStart..<data.endIndex)
    }

    private static func extractSlice(from data: Data, in searchRange: Range<Data.Index>) -> Data? {
        if let xmpStartRange = data.range(of: xmpMetaStart, in: searchRange),
           let xmpEndRange = data.range(of: xmpMetaEnd, in: xmpStartRange.lowerBound..<searchRange.upperBound) {
            return Data(data[xmpStartRange.lowerBound..<xmpEndRange.upperBound])
        }

        // Fallback: 尝试查找 <?xpacket ... ?> 标签，并完整保留结束的 "?>"
        if let xpacketStartRange = data.range(of: xpacketBegin, in: searchRange),
           let xpacketEndRange = data.range(of: xpacketEnd, in: xpacketStartRange.lowerBound..<searchRange.upperBound) {
            if let closingRange = data.range(of: processingInstructionEnd, in: xpacketEndRange.upperBound..<searchRange.upperBound) {
                return Data(data[xpacketStartRange.lowerBound..<closingRange.upperBound])
            }
            return Data(data[xpacketStartRange.lowerBound..<xpacketEndRange.lowerBound])
        }
        return nil
    }

    static func parse(data: Data) -> [String: String]? {
        var cleanedData = data
        if let utf8String = String(data: data, encoding: .utf8) {
            if let range = utf8String.range(of: "<x:") ?? utf8String.range(of: "<?xpacket") {
                cleanedData = Data(utf8String[range.lowerBound...].utf8)
            } else if let range = utf8String.range(of: "<", options: .caseInsensitive) {
                cleanedData = Data(utf8String[range.lowerBound...].utf8)
            }
        }

        let parser = XMLParser(data: cleanedData)
        let delegate = XMPParserDelegate()
        parser.delegate = delegate

        if parser.parse() {
            return delegate.parsedData
        } else {
            AppLogger.parser.warning("XML parse failed: \(parser.parserError?.localizedDescription ?? "unknown", privacy: .public)")
            return nil
        }
    }

    static func extractAndParse(from data: Data) -> [String: String] {
        guard let xmpData = extract(from: data),
              let parsed = parse(data: xmpData) else {
            return [:]
        }
        return parsed
    }
}

final class XMPParserDelegate: NSObject, XMLParserDelegate {
    var parsedData = [String: String]()
    private var currentElement = ""
    private var currentText = ""
    private var hasVideoItemLength = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        let isVideoItem = attributeDict["Item:Semantic"] == "MotionPhoto" ||
            (attributeDict["Item:Mime"]?.lowercased().hasPrefix("video/") == true)

        for (key, value) in attributeDict {
            if key == "Item:Padding",
               value == "0",
               let existing = parsedData[key],
               existing != "0" {
                continue
            }

            if (key == "Item:Length" || key == "GContainer:ItemLength"),
               hasVideoItemLength,
               !isVideoItem {
                continue
            }

            parsedData[key] = value
        }

        if isVideoItem && (attributeDict["Item:Length"] != nil || attributeDict["GContainer:ItemLength"] != nil) {
            hasVideoItemLength = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmedString = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedString.isEmpty {
            parsedData[elementName] = trimmedString
        }
        currentText = ""
    }
}

// MARK: - Backward-compatible Helpers
func extractXMPData(from data: Data) -> Data? {
    XMPParser.extract(from: data)
}

func parseXMP(data: Data) -> [String: String]? {
    XMPParser.parse(data: data)
}
