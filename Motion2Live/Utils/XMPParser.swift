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
    static func extract(from data: Data) -> Data? {
        if let xmpStartRange = data.range(of: Data("<x:xmpmeta".utf8)),
           let xmpEndRange = data.range(of: Data("</x:xmpmeta>".utf8), in: xmpStartRange.lowerBound..<data.count) {
            return data[xmpStartRange.lowerBound..<xmpEndRange.upperBound]
        }

        // Fallback: 尝试查找 <?xpacket ... ?> 标签
        if let xpacketStartRange = data.range(of: Data("<?xpacket begin=".utf8)),
           let xpacketEndRange = data.range(of: Data("<?xpacket end=".utf8), in: xpacketStartRange.lowerBound..<data.count) {
            return data[xpacketStartRange.lowerBound..<xpacketEndRange.upperBound]
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

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        for (key, value) in attributeDict {
            parsedData[key] = value
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedString.isEmpty {
            parsedData[currentElement] = trimmedString
        }
    }
}

// MARK: - Backward-compatible Helpers
func extractXMPData(from data: Data) -> Data? {
    XMPParser.extract(from: data)
}

func parseXMP(data: Data) -> [String: String]? {
    XMPParser.parse(data: data)
}
