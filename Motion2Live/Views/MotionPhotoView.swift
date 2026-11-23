//
//  MotionPhotoView.swift
//  Motion2Live
//
//  Single Motion Photo Inspector & Export View.
//

import SwiftUI
import AVKit

@MainActor
struct MotionPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @State var sourceURL: URL

    @State private var selectedImage: UIImage?
    @State private var videoPlayer: AVPlayer?
    @State private var isPlayingVideo = false
    @State private var motionPhotoData: MotionPhotoData?
    @State private var originalFileData: Data?
    @State private var isShowingPhotoPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    @State private var stillImageTime: Int = 0
    @State private var isExportingGIF = false
    @State private var isExportMenuPresented = false
    @State private var creationDate: Date?

    // 资源生命周期追踪
    @State private var previewVideoURL: URL?
    @State private var playerEndObserver: NSObjectProtocol?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    init(sourceURL: URL) {
        _sourceURL = State(initialValue: sourceURL)
        let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        _creationDate = State(initialValue: attrs?[.creationDate] as? Date)
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                if let image = selectedImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .edgesIgnoringSafeArea(.horizontal)

                        if let player = videoPlayer {
                            PlayerView(player: player)
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .edgesIgnoringSafeArea(.horizontal)
                                .opacity(isPlayingVideo ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: isPlayingVideo)
                                .clipped()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startVideoPlayback() }
                            .onEnded { _ in stopVideoPlayback() }
                    )
                } else {
                    Text(Localizable.string(.pleaseSelectMotionPhoto))
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 导出按钮
                Button(action: { isExportMenuPresented = true }) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                        }
                        Text(Localizable.string(.export))
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedImage == nil || isProcessing ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .disabled(selectedImage == nil || isProcessing)
                .confirmationDialog(Localizable.string(.export), isPresented: $isExportMenuPresented, titleVisibility: .visible) {
                    Button(Localizable.string(.livePhoto)) {
                        exportAsLivePhoto()
                    }
                    Button(Localizable.string(.video)) {
                        exportVideo()
                    }
                    Button(Localizable.string(.gif)) {
                        exportAsGIF()
                    }
                    Button(Localizable.string(.cancel), role: .cancel) {}
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let date = creationDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dateFormatter.string(from: date))
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                        Text(Self.timeFormatter.string(from: date))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        isShowingPhotoPicker = true
                    }) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(onImagePicked: { url, isMotionPhoto in
                Task {
                    if isMotionPhoto {
                        let oldURL = sourceURL
                        sourceURL = url
                        MediaExportService.removeIfInTemporaryDirectory(oldURL)
                        await extractVideoFromMotionPhoto(url: url)
                    } else {
                        MediaExportService.removeIfInTemporaryDirectory(url)
                        showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                    }
                }
            }, onNonMotionPhotoSelected: {
                showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
            })
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(Localizable.string(.tip)),
                message: Text(alertMessage),
                dismissButton: .default(Text(Localizable.string(.ok)))
            )
        }
        .task {
            await extractVideoFromMotionPhoto(url: sourceURL)
        }
        .onDisappear {
            cleanupPlaybackResources()
            MediaExportService.removeIfInTemporaryDirectory(sourceURL)
        }
    }

    private func startVideoPlayback() {
        guard !isPlayingVideo else { return }
        isPlayingVideo = true
        videoPlayer?.seek(to: .zero)
        videoPlayer?.play()
    }

    private func stopVideoPlayback() {
        isPlayingVideo = false
        videoPlayer?.pause()
        videoPlayer?.seek(to: .zero)
    }

    private func cleanupPlaybackResources() {
        videoPlayer?.pause()
        if let observer = playerEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerEndObserver = nil
        }
        videoPlayer = nil
        MediaExportService.removeIfInTemporaryDirectory(previewVideoURL)
        previewVideoURL = nil
    }

    func extractVideoFromMotionPhoto(url: URL) async {
        cleanupPlaybackResources()
        AppLogger.parser.info("Loading motion photo: \(url.lastPathComponent, privacy: .public)")

        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            showAlert(message: Localizable.string(.cannotReadFile))
            return
        }

        let xmpInfo = XMPParser.extractAndParse(from: data)
        guard let processor = MotionPhotoProcessorFactory.getProcessor(for: xmpInfo, data: data) else {
            showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
            return
        }

        let result = processor.processMotionPhoto(data: data, xmpInfo: xmpInfo)
        guard result.success, let extracted = result.data else {
            showAlert(message: result.errorMessage ?? Localizable.string(.selectedPhotoIsNotMotionPhoto))
            return
        }

        self.originalFileData = data
        self.motionPhotoData = extracted
        self.selectedImage = UIImage(data: extracted.imageData)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview_\(UUID().uuidString).mp4")
        do {
            try extracted.videoData.write(to: tempURL)
            self.previewVideoURL = tempURL

            let asset = AVAsset(url: tempURL)
            let duration = try await asset.load(.duration)
            let videoDuration = CMTimeGetSeconds(duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let frameRate = try await tracks.first?.load(.nominalFrameRate) ?? 30.0

            self.stillImageTime = processor.calculateStillImageTime(
                videoDuration: videoDuration,
                presentationTimestamp: extracted.presentationTimestamp,
                frameRate: Double(frameRate)
            )

            let player = AVPlayer(url: tempURL)
            player.actionAtItemEnd = .none
            self.videoPlayer = player

            self.playerEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
        } catch {
            AppLogger.parser.error("Failed to prepare preview video: \(error.localizedDescription, privacy: .public)")
            MediaExportService.removeIfInTemporaryDirectory(tempURL)
            self.previewVideoURL = nil
            showAlert(message: Localizable.string(.errorProcessingVideoFile))
        }

        if let resolvedDate = MediaExportService.resolveCreationDate(originalData: data, fallbackURL: url) {
            self.creationDate = resolvedDate
        }
    }

    private func exportVideo() {
        guard let extracted = motionPhotoData else {
            showAlert(message: Localizable.string(.cannotGetVideoData))
            return
        }

        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await MediaExportService.exportVideo(
                    videoData: extracted.videoData,
                    originalData: originalFileData,
                    fallbackURL: sourceURL,
                    preferredDate: creationDate
                )
                showAlert(message: Localizable.string(.videoSaved))
            } catch {
                showAlert(message: Localizable.string(.savingVideoFailed) + ": \(error.localizedDescription)")
            }
        }
    }

    private func exportAsLivePhoto() {
        guard let extracted = motionPhotoData else {
            showAlert(message: Localizable.string(.missingData))
            return
        }

        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await MediaExportService.exportLivePhoto(
                    motionPhotoData: extracted,
                    originalData: originalFileData,
                    fallbackURL: sourceURL,
                    preferredDate: creationDate,
                    stillImageTime: stillImageTime
                )
                showAlert(message: Localizable.string(.livePhotoSaved))
            } catch {
                showAlert(message: Localizable.string(.savingLivePhotoFailed) + ": \(error.localizedDescription)")
            }
        }
    }

    private func exportAsGIF() {
        guard let extracted = motionPhotoData else {
            showAlert(message: Localizable.string(.cannotGetVideoData))
            return
        }

        isExportingGIF = true
        isProcessing = true
        Task {
            defer {
                isProcessing = false
                isExportingGIF = false
            }
            do {
                try await MediaExportService.exportGIF(videoData: extracted.videoData)
                showAlert(message: Localizable.string(.gifSavedToPhotos))
            } catch {
                showAlert(message: Localizable.string(.failedToCreateGIF) + ": \(error.localizedDescription)")
            }
        }
    }

    private func showAlert(message: String) {
        self.alertMessage = message
        self.showAlert = true
    }
}
