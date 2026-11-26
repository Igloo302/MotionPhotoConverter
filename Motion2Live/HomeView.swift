//
//  HomeView.swift
//  Motion2Live
//
//  Editorial Liquid Glass Home Entry (Adaptive iPhone / iPhone Duo / iPad).
//  Follows Apple HIG Liquid Glass boundaries: glass only on top nav controls & primary CTA.
//

import SwiftUI
import AVFoundation

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var recentStore = RecentConversionStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingLabView = false
    @State private var showingAboutView = false
    @State private var hingeState: HingeStateSnapshot = .unavailable

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let metrics = AdaptiveLayoutMetrics(
                    containerSize: proxy.size,
                    safeAreaInsets: proxy.safeAreaInsets,
                    horizontalSizeClass: horizontalSizeClass,
                    verticalSizeClass: verticalSizeClass,
                    hinge: hingeState
                )

                ZStack {
                    AppTheme.canvas
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        topNavigationBar(metrics: metrics)

                        editorialStageLayout(metrics: metrics)
                    }
                }
            }
            .observeDeviceHinge($hingeState)
            .toolbar(.hidden, for: .navigationBar)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(Localizable.string(.tip)),
                    message: Text(alertMessage),
                    dismissButton: .default(Text(Localizable.string(.ok)))
                )
            }
            .sheet(isPresented: $showingAboutView) {
                AboutSheetView()
            }
            .sheet(isPresented: $viewModel.isShowingPhotoPicker) {
                PhotoPicker(
                    onSinglePicked: { url in
                        viewModel.selectedImageURL = url
                    },
                    onBatchPicked: { validURLs, ignoredCount in
                        viewModel.batchURLs = validURLs
                        viewModel.ignoredCount = ignoredCount
                        viewModel.isShowingBatchView = true
                    },
                    onNoneValidSelected: { totalCount in
                        if totalCount <= 1 {
                            self.showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                        } else {
                            self.showAlert(message: Localizable.string(.noValidMotionPhotosInBatch, totalCount))
                        }
                    },
                    onAnalyzingProgress: { current, total in
                        viewModel.analyzingCurrent = current
                        viewModel.analyzingTotal = total
                        viewModel.isAnalyzingPhotos = (total > 0)
                    }
                )
            }
            .sheet(isPresented: $viewModel.isShowingBatchView, onDismiss: {
                viewModel.resetBatchState()
            }) {
                BatchConvertView(
                    motionPhotoURLs: viewModel.batchURLs,
                    ignoredCount: viewModel.ignoredCount,
                    onDismiss: {
                        viewModel.resetBatchState()
                    }
                )
            }
            .sheet(isPresented: $showingLabView) {
                LabView()
            }
            .overlay {
                if viewModel.isAnalyzingPhotos {
                    analyzingOverlay
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.selectedImageURL != nil },
                set: { if !$0 { viewModel.selectedImageURL = nil } }
            )) {
                if let url = viewModel.selectedImageURL {
                    MotionPhotoView(sourceURL: url)
                }
            }
        }
    }

    // MARK: - Top Navigation Bar (Liquid Glass Controls)

    private func topNavigationBar(metrics: AdaptiveLayoutMetrics) -> some View {
        HStack {
            // Brand Wordmark
            HStack(spacing: 8) {
                Image(systemName: "livephoto")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                Text(Localizable.string(.appTitle))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            // Liquid Glass Top Controls: Lab Pill + More Menu
            LiquidGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        AppHaptics.lightImpact()
                        showingLabView = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "flask")
                                .font(.system(size: 12, weight: .medium))
                            Text(Localizable.string(.lab))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.leading, 13)
                        .padding(.trailing, 14)
                        .frame(height: 36)
                        .contentShape(Capsule())
                        .liquidGlassControl(in: Capsule(), interactive: true)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Toggle(isOn: $recentStore.showRecentOnHome) {
                            Label(Localizable.string(.homeShowRecentConversions), systemImage: "clock.arrow.circlepath")
                        }

                        Divider()

                        Button {
                            showingAboutView = true
                        } label: {
                            Label(Localizable.string(.about), systemImage: "info.circle")
                        }

                        #if DEBUG
                        if let samplesDir = ProcessInfo.processInfo.environment["MOTION2LIVE_SAMPLES_DIR"],
                           !samplesDir.isEmpty {
                            Divider()
                            Button {
                                let base = URL(fileURLWithPath: samplesDir)
                                viewModel.batchURLs = [
                                    base.appendingPathComponent("Pixel.jpg"),
                                    base.appendingPathComponent("Samsung.jpg"),
                                    base.appendingPathComponent("XiaomiNew.jpg"),
                                    base.appendingPathComponent("XiaomiOld.jpg")
                                ].filter { FileManager.default.fileExists(atPath: $0.path) }
                                viewModel.ignoredCount = 5
                                viewModel.isShowingBatchView = !viewModel.batchURLs.isEmpty
                            } label: {
                                Label("预览批量转换", systemImage: "square.stack.3d.up")
                            }

                            Button {
                                let base = URL(fileURLWithPath: samplesDir)
                                let sampleSource = base.appendingPathComponent("XiaomiNew.jpg")
                                let tempTarget = FileManager.default.temporaryDirectory
                                    .appendingPathComponent("debug_\(UUID().uuidString).jpg")
                                if let data = try? Data(contentsOf: sampleSource) {
                                    try? data.write(to: tempTarget)
                                    viewModel.selectedImageURL = tempTarget
                                }
                            } label: {
                                Label("预览单张详情", systemImage: "photo")
                            }
                        }
                        #endif
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                            .liquidGlassControl(in: Circle(), interactive: true)
                    }
                    .accessibilityLabel(Localizable.string(.about))
                }
            }
        }
        .frame(height: 52)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - Unified Adaptive Editorial Stage (Preserves HeroPhotoDeckStage identity across fold/unfold)

    private func editorialStageLayout(metrics: AdaptiveLayoutMetrics) -> some View {
        let isHorizontalSplit = metrics.prefersHorizontalSplitAxis
        let splitSpacing: CGFloat = {
            if isHorizontalSplit {
                return metrics.containerSize.width >= 960 ? 56 : max(28, metrics.hingeAvoidanceGap)
            }
            if metrics.layoutMode == .hingeFlexSplit {
                return metrics.hingeAvoidanceGap
            }
            return metrics.isCompactShortScreen ? 8 : 16
        }()

        let layout = isHorizontalSplit
            ? AnyLayout(HStackLayout(alignment: .center, spacing: splitSpacing))
            : AnyLayout(VStackLayout(spacing: splitSpacing))

        return layout {
            HeroPhotoDeckStage(scale: metrics.heroDeckScale)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: isHorizontalSplit ? .infinity : nil)

            editorialControlCluster(metrics: metrics, isHorizontalSplit: isHorizontalSplit)
        }
        .frame(maxWidth: isHorizontalSplit ? 960 : .infinity, maxHeight: .infinity)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, isHorizontalSplit ? 0 : (metrics.isCompactShortScreen ? 4 : 10))
        .padding(.bottom, isHorizontalSplit ? 20 : metrics.dockBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared Editorial Pieces

    private func editorialControlCluster(metrics: AdaptiveLayoutMetrics, isHorizontalSplit: Bool) -> some View {
        VStack(alignment: isHorizontalSplit ? .leading : .center, spacing: isHorizontalSplit ? 24 : (metrics.isCompactShortScreen ? 12 : 18)) {
            if !isHorizontalSplit {
                Spacer(minLength: metrics.isCompactShortScreen ? 4 : 10)
            }

            editorialHeadline(alignment: isHorizontalSplit ? .leading : .center, isWide: isHorizontalSplit)

            if !isHorizontalSplit {
                Spacer(minLength: metrics.isCompactShortScreen ? 4 : 12)
            }

            VStack(alignment: isHorizontalSplit ? .leading : .center, spacing: isHorizontalSplit ? 12 : 10) {
                primarySelectButton
                    .frame(maxWidth: isHorizontalSplit ? 360 : metrics.floatingDockMaxWidth)

                Text(Localizable.string(.homeBrandFootnote))
                    .font(.system(size: isHorizontalSplit ? 12 : 11, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)
                    .multilineTextAlignment(isHorizontalSplit ? .leading : .center)
                    .lineLimit(isHorizontalSplit ? 2 : 1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, isHorizontalSplit ? 0 : 4)
        }
        .frame(maxWidth: isHorizontalSplit ? 420 : .infinity, alignment: isHorizontalSplit ? .leading : .center)
    }

    private func editorialHeadline(alignment: HorizontalAlignment, isWide: Bool) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(Localizable.string(.homeHeroHeadline))
                .font(.system(size: isWide ? 30 : 25, weight: .semibold))
                .tracking(-0.3)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)
                .minimumScaleFactor(0.78)
                .lineLimit(isWide ? 3 : 2)

            Text(Localizable.string(.homeHeroSubtitle))
                .font(.system(size: isWide ? 15 : 13, weight: .regular))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
    }

    private var primarySelectButton: some View {
        Button {
            AppHaptics.lightImpact()
            viewModel.selectPhoto()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "livephoto")
                    .font(.system(size: 18, weight: .semibold))
                Text(Localizable.string(.selectMotionPhoto))
            }
        }
        .buttonStyle(StudioPrimaryButtonStyle(height: 54))
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(AppTheme.accent)
                Text(Localizable.string(.analyzingPhotos, viewModel.analyzingCurrent, viewModel.analyzingTotal))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .studioCard(cornerRadius: 20, padding: 0)
        }
    }

    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Hero Deck Math & Models

enum HeroDeckMath {
    /// Computes the continuous cyclic relative slot in `[-count/2, +count/2]` for a card at `index`.
    static func cyclicRelativeSlot(
        for index: Int,
        activeIndex: Int,
        dragProgress: CGFloat = 0,
        count: Int = 3
    ) -> CGFloat {
        guard count > 0 else { return 0 }
        let normalizedActive = ((activeIndex % count) + count) % count
        let normalizedIndex = ((index % count) + count) % count
        var diff = normalizedIndex - normalizedActive
        let halfInt = count / 2
        if diff > halfInt {
            diff -= count
        } else if diff < -halfInt {
            diff += count
        }

        let half = CGFloat(count) / 2.0
        var slot = CGFloat(diff) + dragProgress
        while slot > half { slot -= CGFloat(count) }
        while slot < -half { slot += CGFloat(count) }
        return slot
    }

    /// Predicts the next active card index from drag translation and velocity-predicted end translation.
    static func predictedTargetIndex(
        currentActiveIndex: Int,
        translationX: CGFloat,
        predictedEndTranslationX: CGFloat,
        cardStepDistance: CGFloat = 110,
        count: Int = 3
    ) -> Int {
        guard count > 0 else { return 0 }
        let threshold = cardStepDistance * 0.45
        let effectiveDelta: CGFloat
        if abs(predictedEndTranslationX) > abs(translationX) {
            effectiveDelta = translationX * 0.35 + predictedEndTranslationX * 0.65
        } else {
            effectiveDelta = translationX
        }

        let stepDelta: Int
        if effectiveDelta > threshold {
            // Dragging right brings the left card (slot = -1) to center
            stepDelta = -1
        } else if effectiveDelta < -threshold {
            // Dragging left brings the right card (slot = +1) to center
            stepDelta = 1
        } else {
            stepDelta = 0
        }

        return ((currentActiveIndex + stepDelta) % count + count) % count
    }
}

private enum HeroPressPhase: Equatable {
    case idle
    case pressing
    case active
}

private struct HeroDeckCardItem: Identifiable {
    let id: String
    let image: Image
    let videoURL: URL?
    let durationLabel: String
}

// MARK: - Hero Photo Deck Stage (Interactive 3-Card Fanned Showcase + Long-Press Live)
private struct HeroPhotoDeckStage: View {
    let scale: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var recentStore = RecentConversionStore.shared
    @StateObject private var livePlayerController = HeroLivePlayerController()

    @State private var activeIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @GestureState private var pressPhase: HeroPressPhase = .idle
    @State private var isPlayingLive: Bool = false

    private var isPressing: Bool {
        pressPhase == .pressing && !isDragging
    }

    private let cardStepDistance: CGFloat = 110
    private let waveformHeights: [CGFloat] = [5, 10, 15, 9, 18, 13, 20, 11, 16, 8, 13, 17, 10, 7, 11, 6]

    private var activeEntries: [RecentConversionEntry] {
        recentStore.showRecentOnHome ? recentStore.entries : []
    }

    private var deckItems: [HeroDeckCardItem] {
        // Order: [0] Center, [1] Right (slot +1), [2] Left (slot -1)
        let mappings: [(entryIndex: Int, assetName: String)] = [
            (0, "HeroDemoCenter"),
            (2, "HeroDemoRight"),
            (1, "HeroDemoLeft")
        ]

        return mappings.map { mapping in
            if mapping.entryIndex < activeEntries.count {
                let entry = activeEntries[mapping.entryIndex]
                let img = recentStore.image(for: entry).map { Image(uiImage: $0) } ?? Image(mapping.assetName)
                let duration: String = {
                    if let sec = entry.durationSeconds, sec > 0 {
                        return String(format: "%.1fs", sec)
                    }
                    return "2.4s"
                }()
                let videoURL = recentStore.videoURL(for: entry)
                return HeroDeckCardItem(
                    id: "recent_\(entry.id.uuidString)",
                    image: img,
                    videoURL: videoURL,
                    durationLabel: duration
                )
            } else {
                let bundleVideoURL = Bundle.main.url(forResource: mapping.assetName, withExtension: "mp4")
                return HeroDeckCardItem(
                    id: "demo_\(mapping.assetName)",
                    image: Image(mapping.assetName),
                    videoURL: bundleVideoURL,
                    durationLabel: "2.4s"
                )
            }
        }
    }

    private var currentCenterItem: HeroDeckCardItem {
        let items = deckItems
        let safeIdx = ((activeIndex % items.count) + items.count) % items.count
        return items[safeIdx]
    }

    var body: some View {
        let items = deckItems
        let dragProgress = dragOffset / cardStepDistance
        let parallaxMultiplier: CGFloat = reduceMotion ? 0.02 : 0.08

        ZStack {
            // Ambient Cyan & Indigo Halos with subtle drag parallax
            Circle()
                .fill(Color(red: 0.220, green: 0.737, blue: 0.878).opacity(colorScheme == .dark ? 0.22 : 0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 62)
                .offset(x: -44 + dragOffset * parallaxMultiplier, y: -42)

            Circle()
                .fill(Color(red: 0.349, green: 0.341, blue: 0.922).opacity(colorScheme == .dark ? 0.18 : 0.12))
                .frame(width: 200, height: 200)
                .blur(radius: 66)
                .offset(x: 54 - dragOffset * parallaxMultiplier, y: 36)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let slot = HeroDeckMath.cyclicRelativeSlot(
                    for: index,
                    activeIndex: activeIndex,
                    dragProgress: dragProgress,
                    count: items.count
                )
                deckCardView(item: item, index: index, slot: slot)
            }
        }
        .frame(width: 351, height: 358)
        .contentShape(Rectangle())
        .simultaneousGesture(horizontalDeckDragGesture(count: items.count))
        .scaleEffect(scale)
        .frame(width: 351 * scale, height: 358 * scale)
        .animation(.easeInOut(duration: 0.25), value: activeEntries.map(\.id))
        .onAppear {
            prepareCurrentCenterVideo()
        }
        .onChange(of: pressPhase) { newPhase in
            switch newPhase {
            case .active:
                guard !isDragging else { return }
                if !isPlayingLive {
                    isPlayingLive = true
                    AppHaptics.mediumImpact()
                    livePlayerController.startPlayback()
                }
            case .idle, .pressing:
                if isPlayingLive {
                    isPlayingLive = false
                    livePlayerController.stopAndReset()
                }
            }
        }
        .onChange(of: activeIndex) { _ in
            prepareCurrentCenterVideo()
        }
        .onChange(of: activeEntries.map(\.id)) { _ in
            cancelPressAndResetLive()
            activeIndex = 0
            prepareCurrentCenterVideo()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase != .active {
                cancelPressAndResetLive()
                livePlayerController.teardown()
            } else {
                prepareCurrentCenterVideo()
            }
        }
        .onDisappear {
            cancelPressAndResetLive()
            livePlayerController.teardown()
        }
    }

    @ViewBuilder
    private func deckCardView(item: HeroDeckCardItem, index: Int, slot: CGFloat) -> some View {
        let absSlot = abs(slot)
        let t = min(absSlot, 1.0)
        let sign: CGFloat = slot >= 0 ? 1 : -1

        let baseX: CGFloat = absSlot <= 1.0
            ? slot * 78
            : (2.0 - absSlot) * 78 * sign
        let arcOutward: CGFloat = reduceMotion ? 0 : sin(t * .pi) * 14 * sign
        let xOffset = baseX + arcOutward

        let targetSideY: CGFloat = slot >= 0 ? 10 : 6
        let yOffset = targetSideY * t

        let baseRotation: CGFloat = absSlot <= 1.0
            ? slot * 8.0
            : (2.0 - absSlot) * 8.0 * sign
        let rotation = reduceMotion ? baseRotation * 0.5 : baseRotation

        let baseScale: CGFloat = absSlot <= 1.0
            ? 1.0 - (1.0 - 0.704) * t
            : max(0.64, 0.704 - (absSlot - 1.0) * 0.12)

        let isCenterSlot = absSlot < 0.08 && !isDragging
        let pressScale: CGFloat = {
            guard isCenterSlot else { return 1.0 }
            if isPlayingLive {
                return reduceMotion ? 1.01 : 1.035
            }
            if isPressing {
                return reduceMotion ? 0.99 : 0.975
            }
            return 1.0
        }()

        let cardOpacity: Double = absSlot <= 1.0
            ? 1.0 - 0.12 * Double(t)
            : max(0.72, 0.88 - Double(absSlot - 1.0) * 0.32)

        let zOrder: Double = 10.0 - Double(absSlot) - (slot > 0 ? 0.01 : 0.0)
        let centerVisibility = max(0.0, 1.0 - Double(absSlot) * 2.4)
        let shadowRadius: CGFloat = isCenterSlot && isPlayingLive ? 32 : (28 - 12 * t)
        let shadowY: CGFloat = isCenterSlot && isPlayingLive ? 20 : (18 - 8 * t)

        ZStack {
            item.image
                .resizable()
                .scaledToFill()
                .frame(width: 233, height: 326)
                .scaleEffect(isCenterSlot && isPlayingLive && !livePlayerController.isVideoVisible ? (reduceMotion ? 1.02 : 1.06) : 1.0)
                .animation(.easeInOut(duration: 1.6), value: isPlayingLive)
                .clipped()

            if isCenterSlot, livePlayerController.hasVideoSource {
                PlayerView(player: livePlayerController.player, videoGravity: .resizeAspectFill)
                    .frame(width: 233, height: 326)
                    .opacity(livePlayerController.isVideoVisible && isPlayingLive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.16), value: livePlayerController.isVideoVisible && isPlayingLive)
                    .allowsHitTesting(false)
            }

            // Bottom optical vignette (scales smoothly with C-slot visibility)
            if centerVisibility > 0.01 {
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, Color(red: 0.03, green: 0.04, blue: 0.05).opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 118)
                }
                .opacity(centerVisibility)

                centerOverlayChrome(item: item, isPlayingLive: isCenterSlot && isPlayingLive)
                    .opacity(centerVisibility)
            }
        }
        .frame(width: 233, height: 326)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45 - 0.25 * Double(t)),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.22 - 0.10 * Double(t))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(
            color: Color.black.opacity((colorScheme == .dark ? 0.62 : 0.24) * (1.0 - 0.35 * Double(t))),
            radius: shadowRadius,
            y: shadowY
        )
        .scaleEffect(baseScale * pressScale)
        .rotationEffect(.degrees(rotation))
        .offset(x: xOffset, y: yOffset)
        .opacity(cardOpacity)
        .zIndex(zOrder)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isPressing)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPlayingLive)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            guard absSlot > 0.4 else { return }
            switchToCard(index: index)
        }
        .simultaneousGesture(
            isCenterSlot ? centerLongPressGesture() : nil
        )
    }

    private func centerOverlayChrome(item: HeroDeckCardItem, isPlayingLive: Bool) -> some View {
        VStack {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.220, green: 0.737, blue: 0.878))
                        .scaleEffect(isPlayingLive && !reduceMotion ? 1.12 : 1.0)
                        .animation(
                            isPlayingLive && !reduceMotion
                                ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                                : .default,
                            value: isPlayingLive
                        )
                    Text("LIVE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.96))
                }
                .padding(.leading, 10)
                .padding(.trailing, 11)
                .frame(height: 28)
                .quietPhotoBadge(cornerRadius: 14)

                Spacer()

                Text(item.durationLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.94))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .quietPhotoBadge(cornerRadius: 14)
            }
            .padding(14)

            Spacer()

            // Quiet Waveform Pill (live animated during playback)
            if isPlayingLive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    waveformRow(phase: timeline.date.timeIntervalSinceReferenceDate, active: true)
                }
            } else {
                waveformRow(phase: 0, active: false)
            }
        }
    }

    private func waveformRow(phase: TimeInterval, active: Bool) -> some View {
        HStack(spacing: 4.5) {
            ForEach(Array(waveformHeights.enumerated()), id: \.offset) { idx, baseHeight in
                let barHeight: CGFloat = {
                    guard active else { return baseHeight }
                    let wave = sin(phase * 7.5 + Double(idx) * 0.65)
                    let harmonic = cos(phase * 4.2 - Double(idx) * 0.4)
                    let dynamic = baseHeight + CGFloat((wave * 4.5) + (harmonic * 2.5))
                    return min(22, max(4, dynamic))
                }()
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(
                        idx < 10
                            ? Color(red: 0.220, green: 0.780, blue: 0.961).opacity(0.96)
                            : Color.white.opacity(0.36)
                    )
                    .frame(width: 2.5, height: barHeight)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 201, height: 34)
        .quietPhotoBadge(cornerRadius: 14)
        .padding(.bottom, 16)
    }

    // MARK: - Gestures & Playback Lifecycle

    private func horizontalDeckDragGesture(count: Int) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    cancelPressAndResetLive()
                }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let targetIndex = HeroDeckMath.predictedTargetIndex(
                    currentActiveIndex: activeIndex,
                    translationX: value.translation.width,
                    predictedEndTranslationX: value.predictedEndTranslation.width,
                    cardStepDistance: cardStepDistance,
                    count: count
                )
                let didChange = targetIndex != activeIndex
                withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                    activeIndex = targetIndex
                    dragOffset = 0
                    isDragging = false
                }
                if didChange {
                    AppHaptics.selection()
                }
            }
    }

    private func centerLongPressGesture() -> some Gesture {
        LongPressGesture(minimumDuration: 0.22, maximumDistance: 14)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($pressPhase) { value, state, _ in
                switch value {
                case .first(true):
                    state = .pressing
                case .second(true, _):
                    state = .active
                default:
                    state = .idle
                }
            }
    }

    private func switchToCard(index: Int) {
        guard index != activeIndex else { return }
        cancelPressAndResetLive()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
            activeIndex = index
            dragOffset = 0
        }
        AppHaptics.selection()
    }

    private func cancelPressAndResetLive() {
        if isPlayingLive {
            isPlayingLive = false
        }
        livePlayerController.stopAndReset()
    }

    private func prepareCurrentCenterVideo() {
        livePlayerController.prepare(url: currentCenterItem.videoURL)
    }
}

// MARK: - About Sheet View
private struct AboutSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var appVersionText: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(short) (\(build))"
    }

    private var privacyPolicyURL: URL? {
        let base = "https://igloo302.github.io/MotionPhotoConverter/privacy-policy.html"
        let urlString = Language.current == .chinese ? base : "\(base)?lang=en"
        return URL(string: urlString)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveLayoutMetrics(
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                horizontalSizeClass: horizontalSizeClass,
                verticalSizeClass: verticalSizeClass
            )

            ZStack {
                AppTheme.canvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Nav Bar with Liquid Glass Close Button
                    ZStack {
                        Text(Localizable.string(.about))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        HStack {
                            Spacer()
                            StudioIconCircleButton(
                                systemName: "xmark",
                                accessibilityLabel: Localizable.string(.cancel),
                                size: 38
                            ) {
                                dismiss()
                            }
                        }
                    }
                    .frame(height: 54)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 4)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            // 1. App Identity Header
                            VStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppTheme.accent.opacity(0.22),
                                                    AppTheme.surface1
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .strokeBorder(AppTheme.accent.opacity(0.4), lineWidth: 1)
                                        )

                                    Image(systemName: "livephoto")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(AppTheme.accent)
                                }

                                VStack(spacing: 4) {
                                    Text(Localizable.string(.appTitle))
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)

                                    Text(Localizable.string(.homeHeroHeadline))
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Text(appVersionText)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(AppTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(AppTheme.surface1)
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.7)
                                            )
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                            // 2. Supported Brands Compatibility Matrix
                            SupportedBrandsView()

                            // 3. Highlights & Privacy Card
                            VStack(alignment: .leading, spacing: 14) {
                                Text(Localizable.string(.aboutSectionHighlights))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)

                                aboutFeatureRow(
                                    icon: "lock.shield",
                                    color: AppTheme.success,
                                    title: Localizable.string(.aboutPrivacyTitle),
                                    description: Localizable.string(.aboutPrivacyDesc)
                                )

                                Divider().overlay(AppTheme.borderSubtle)

                                aboutFeatureRow(
                                    icon: "calendar.badge.clock",
                                    color: AppTheme.accent,
                                    title: Localizable.string(.aboutMetadataTitle),
                                    description: Localizable.string(.aboutMetadataDesc)
                                )

                                Divider().overlay(AppTheme.borderSubtle)

                                aboutFeatureRow(
                                    icon: "square.stack.3d.up",
                                    color: AppTheme.warning,
                                    title: Localizable.string(.aboutFormatsTitle),
                                    description: Localizable.string(.aboutFormatsDesc)
                                )
                            }
                            .studioCard(cornerRadius: AppTheme.Radius.card, padding: 16)

                            // 4. Project Info & Open Source Links
                            VStack(alignment: .leading, spacing: 12) {
                                Text(Localizable.string(.aboutSectionProject))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)

                                aboutInfoRow(
                                    label: Localizable.string(.aboutDeveloperLabel),
                                    value: "Larry Shen (Igloo)"
                                )

                                Divider().overlay(AppTheme.borderSubtle)

                                aboutInfoRow(
                                    label: Localizable.string(.aboutLicenseLabel),
                                    value: "MPL-2.0"
                                )

                                if let privacyURL = privacyPolicyURL {
                                    Divider().overlay(AppTheme.borderSubtle)

                                    Link(destination: privacyURL) {
                                        HStack {
                                            Text(Localizable.string(.aboutPrivacyPolicyLabel))
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(AppTheme.accent)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                }

                                if let repoURL = URL(string: "https://github.com/Igloo302/MotionPhotoConverter") {
                                    Divider().overlay(AppTheme.borderSubtle)

                                    Link(destination: repoURL) {
                                        HStack {
                                            Text(Localizable.string(.aboutSourceCodeLabel))
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            HStack(spacing: 4) {
                                                Text("GitHub")
                                                    .font(.system(size: 13, weight: .medium))
                                                Image(systemName: "arrow.up.right")
                                                    .font(.system(size: 11, weight: .semibold))
                                            }
                                            .foregroundColor(AppTheme.accent)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                            .studioCard(cornerRadius: AppTheme.Radius.card, padding: 16)

                            Text("© 2024–2026 Igloo · Motion2Live")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.top, 4)
                                .padding(.bottom, 20)
                        }
                        .frame(maxWidth: metrics.readableContentMaxWidth)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func aboutFeatureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func aboutInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

#Preview {
    HomeView()
}
