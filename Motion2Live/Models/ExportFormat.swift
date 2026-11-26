//
//  ExportFormat.swift
//  Motion2Live
//
//  Shared export format enum used by MotionPhotoView, BatchConvertView, and Motion2LiveShareExtension.
//

import Foundation

enum BatchExportFormat: String, CaseIterable, Identifiable {
    case livePhoto = "Live Photo"
    case video = "Video"
    case gif = "GIF"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .livePhoto: return Localizable.string(.livePhoto)
        case .video: return Localizable.string(.video)
        case .gif: return Localizable.string(.gif)
        }
    }

    var icon: String {
        switch self {
        case .livePhoto: return "livephoto"
        case .video: return "video"
        case .gif: return "play.rectangle"
        }
    }

    var description: String {
        switch self {
        case .livePhoto: return Localizable.string(.livePhotoFormatDesc)
        case .video: return Localizable.string(.videoFormatDesc)
        case .gif: return Localizable.string(.gifFormatDesc)
        }
    }
}
