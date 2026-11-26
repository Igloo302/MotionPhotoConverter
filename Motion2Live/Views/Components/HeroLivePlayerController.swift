//
//  HeroLivePlayerController.swift
//  Motion2Live
//
//  Single-instance muted AVPlayer controller for Home Hero Deck long-press Live preview.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class HeroLivePlayerController: ObservableObject {
    let player: AVPlayer

    @Published private(set) var isReadyToDisplay: Bool = false
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isVideoVisible: Bool = false

    private var preparedURL: URL?
    private var statusObservation: NSKeyValueObservation?
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?

    init() {
        let avPlayer = AVPlayer()
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        self.player = avPlayer
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    var hasVideoSource: Bool {
        preparedURL != nil
    }

    /// Preloads a local video URL and pauses at 0.0s for zero-latency long-press playback.
    func prepare(url: URL?) {
        if url == preparedURL, (url == nil || player.currentItem != nil) {
            if !isPlaying, player.currentItem != nil {
                player.pause()
            }
            return
        }

        clearObservations()
        preparedURL = url
        isPlaying = false
        isVideoVisible = false
        isReadyToDisplay = false

        guard let url else {
            player.pause()
            player.replaceCurrentItem(with: nil)
            return
        }

        let item = AVPlayerItem(url: url)

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            let status = observedItem.status
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === observedItem else { return }
                if status == .readyToPlay {
                    self.isReadyToDisplay = true
                    if self.isPlaying {
                        self.isVideoVisible = true
                        self.player.play()
                    }
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.isPlaying else { return }
                        self.player.play()
                    }
                }
            }
        }

        player.pause()
        player.replaceCurrentItem(with: item)
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Starts muted Live playback (or sets playing state for fallback motion when no video exists).
    func startPlayback() {
        isPlaying = true
        guard preparedURL != nil, player.currentItem != nil else {
            isVideoVisible = false
            return
        }

        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                if self.isReadyToDisplay {
                    self.isVideoVisible = true
                }
                self.player.play()
            }
        }
    }

    /// Pauses playback, hides video layer, and rewinds to 0.0s.
    func stopAndReset() {
        isPlaying = false
        isVideoVisible = false
        player.pause()
        if player.currentItem != nil {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    /// Releases the current item and observations when the view disappears or enters background.
    func teardown() {
        stopAndReset()
        clearObservations()
        preparedURL = nil
        isReadyToDisplay = false
        player.replaceCurrentItem(with: nil)
    }

    private func clearObservations() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
