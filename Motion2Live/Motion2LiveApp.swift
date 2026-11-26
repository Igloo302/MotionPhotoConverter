//
//  Motion2LiveApp.swift
//  Motion2Live
//
//  Created by larry.shen on 2024/9/14.
//

import SwiftUI

@main
struct Motion2LiveApp: App {
    @StateObject private var homeViewModel = HomeViewModel()
    #if targetEnvironment(macCatalyst)
    @State private var didConfigureInitialWindow = false
    #endif

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: homeViewModel)
                .onOpenURL { url in
                    homeViewModel.handleIncomingURLs([url])
                }
                #if targetEnvironment(macCatalyst)
                .onAppear {
                    configureMacCatalystWindowIfNeeded()
                }
                #endif
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            CommandGroup(after: .newItem) {
                Button(Localizable.string(.menuOpenFromFiles)) {
                    homeViewModel.isShowingFileImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(Localizable.string(.menuSelectFromPhotos)) {
                    homeViewModel.selectPhoto()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button(Localizable.string(.menuOpenLab)) {
                    homeViewModel.isShowingLabView = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func configureMacCatalystWindowIfNeeded() {
        guard !didConfigureInitialWindow else { return }
        didConfigureInitialWindow = true

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 680, height: 540)
        let screenBounds = windowScene.screen.bounds
        let targetWidth: CGFloat = min(960, screenBounds.width * 0.85)
        let targetHeight: CGFloat = min(680, screenBounds.height * 0.85)
        let originX = screenBounds.midX - targetWidth / 2
        let originY = screenBounds.midY - targetHeight / 2
        let targetFrame = CGRect(x: originX, y: originY, width: targetWidth, height: targetHeight)
        windowScene.requestGeometryUpdate(.Mac(systemFrame: targetFrame))
    }
    #endif
}
