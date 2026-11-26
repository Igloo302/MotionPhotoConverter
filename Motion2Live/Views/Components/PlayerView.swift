//
//  PlayerView.swift
//  Motion2Live
//
//  Lightweight AVPlayerLayer wrapper for SwiftUI.
//

import SwiftUI
import AVKit

struct PlayerView: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(player: player, videoGravity: videoGravity)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.updatePlayer(player, videoGravity: videoGravity)
    }
}

final class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    init(player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = videoGravity
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePlayer(_ player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
        if playerLayer.videoGravity != videoGravity {
            playerLayer.videoGravity = videoGravity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
