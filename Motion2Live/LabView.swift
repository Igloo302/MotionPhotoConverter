import SwiftUI
import PhotosUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

struct LabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
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
                        // Top Nav Bar with centered title & Liquid Glass circular close button
                        ZStack {
                            Text(Localizable.string(.lab))
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
                            VStack(alignment: .leading, spacing: 16) {
                                Text(Localizable.string(.labExploreSubtitle))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)

                                // Standard Content-Layer Feature Card (surface0, r=24, no glass per HIG)
                                NavigationLink(destination: CustomLivePhotoView()) {
                                    labFeatureCard(
                                        icon: "livephoto",
                                        title: Localizable.string(.customLivePhoto),
                                        description: Localizable.string(.customLivePhotoDescription)
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink(destination: LiveToMotionView()) {
                                    labFeatureCard(
                                        icon: "arrow.triangle.2.circlepath",
                                        title: Localizable.string(.liveToMotionTitle),
                                        description: Localizable.string(.liveToMotionDescription)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: metrics.readableContentMaxWidth, alignment: .leading)
                            .padding(.horizontal, metrics.horizontalPadding)
                            .padding(.top, 14)
                            .padding(.bottom, 24)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func labFeatureCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.16))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(AppTheme.accent.opacity(0.35), lineWidth: 0.8)
                    )

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(AppTheme.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                        .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
                )
        )
    }
}

enum CustomPairExportTarget: String, CaseIterable, Identifiable {
    case livePhoto
    case motionPhoto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .livePhoto: return Localizable.string(.customPairTargetLivePhoto)
        case .motionPhoto: return Localizable.string(.customPairTargetMotionPhoto)
        }
    }

    var icon: String {
        switch self {
        case .livePhoto: return "livephoto"
        case .motionPhoto: return "arrow.triangle.2.circlepath"
        }
    }

    var description: String {
        switch self {
        case .livePhoto: return Localizable.string(.customPairTargetLiveDesc)
        case .motionPhoto: return Localizable.string(.customPairTargetMotionDesc)
        }
    }
}

struct CustomLivePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var targetAnimation

    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedImagePixelSize: CGSize?
    @State private var selectedVideo: URL?
    @State private var selectedVideoDuration: Double?
    @State private var exportTarget: CustomPairExportTarget = .livePhoto
    @State private var selectedBrand: MotionPhotoBrand = .pixel
    @StateObject private var motionExport = MotionPhotoExportCoordinator()

    @State private var isShowingImagePicker = false
    @State private var isShowingVideoPicker = false
    @State private var isShowingImageFileImporter = false
    @State private var isShowingVideoFileImporter = false
    @State private var isImageDropTargeted = false
    @State private var isVideoDropTargeted = false
    @State private var isProcessing = false
    @State private var hasDisappeared = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertIsSuccess = false

    private var canCreate: Bool {
        (selectedImageData != nil || selectedImage != nil) && selectedVideo != nil && !isProcessing
    }

    private var resolvedImageData: Data? {
        selectedImageData ?? selectedImage?.jpegData(compressionQuality: 1.0)
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
                    // Top Nav Bar: Liquid Glass Back Pill + Centered Title
                    ZStack {
                        Text(Localizable.string(.customLivePhoto))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        HStack {
                            Button {
                                AppHaptics.lightImpact()
                                dismiss()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(Localizable.string(.lab))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.leading, 10)
                                .padding(.trailing, 13)
                                .frame(height: 36)
                                .contentShape(Capsule())
                                .liquidGlassControl(in: Capsule(), interactive: true)
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                    .frame(height: 54)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 4)

                    // Scrollable Step Cards & Bidirectional Export Config
                    ScrollView(showsIndicators: false) {
                        Group {
                            if metrics.isWideSplit {
                                HStack(alignment: .top, spacing: max(16, metrics.hingeAvoidanceGap)) {
                                    VStack(spacing: 16) {
                                        stepOneImageCard
                                        stepTwoVideoCard
                                    }
                                    VStack(spacing: 16) {
                                        exportTargetCard
                                        if exportTarget == .motionPhoto {
                                            MotionPhotoBrandPickerCard(
                                                selectedBrand: $selectedBrand,
                                                isDisabled: isProcessing
                                            )
                                            MotionPhotoExportNoticeBanner()
                                        }
                                    }
                                }
                                .frame(maxWidth: 840)
                            } else {
                                VStack(spacing: 16) {
                                    stepOneImageCard
                                    stepTwoVideoCard
                                    exportTargetCard
                                    if exportTarget == .motionPhoto {
                                        MotionPhotoBrandPickerCard(
                                            selectedBrand: $selectedBrand,
                                            isDisabled: isProcessing
                                        )
                                        MotionPhotoExportNoticeBanner()
                                    }
                                }
                                .frame(maxWidth: metrics.readableContentMaxWidth)
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.isCompactShortScreen ? 10 : 14)
                        .padding(.bottom, metrics.isCompactShortScreen ? 14 : 20)
                        .frame(maxWidth: .infinity)
                    }

                    // Bottom Prominent Liquid Glass CTA / Motion Photo Export Actions
                    VStack(spacing: 0) {
                        if exportTarget == .livePhoto {
                            Button(action: createLivePhoto) {
                                HStack(spacing: 9) {
                                    if isProcessing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "livephoto")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                    Text(Localizable.string(.createLivePhoto))
                                }
                            }
                            .buttonStyle(StudioPrimaryButtonStyle(isDisabled: !canCreate, height: 54))
                            .disabled(!canCreate)
                        } else {
                            MotionPhotoExportActionBar(
                                canExport: canCreate,
                                isProcessing: isProcessing,
                                onShare: { exportMotionPhoto(destination: .share) },
                                onSaveToFiles: { exportMotionPhoto(destination: .files) }
                            )
                        }
                    }
                    .frame(maxWidth: metrics.floatingDockMaxWidth)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, metrics.dockBottomPadding)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(
                image: $selectedImage,
                imageData: $selectedImageData,
                pixelSize: $selectedImagePixelSize,
                onError: { message in
                    alertIsSuccess = false
                    alertMessage = message
                    showAlert = true
                }
            )
        }
        .sheet(isPresented: $isShowingVideoPicker) {
            VideoPicker(
                videoURL: $selectedVideo,
                videoDuration: $selectedVideoDuration,
                onError: { message in
                    alertIsSuccess = false
                    alertMessage = message
                    showAlert = true
                }
            )
        }
        .fileImporter(
            isPresented: $isShowingImageFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadImageFromLocalURL(url)
                }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    alertIsSuccess = false
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingVideoFileImporter,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadVideoFromLocalURL(url)
                }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    alertIsSuccess = false
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
        .motionPhotoExportSheets(
            coordinator: motionExport,
            onSavedToFiles: {
                alertIsSuccess = true
                alertMessage = Localizable.string(.liveToMotionSavedToFiles)
                showAlert = true
            },
            onError: { message in
                alertIsSuccess = false
                alertMessage = message
                showAlert = true
            }
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertIsSuccess ? Localizable.string(.success) : Localizable.string(.error)),
                message: Text(alertMessage),
                dismissButton: .default(Text(Localizable.string(.ok)))
            )
        }
        .onDisappear {
            hasDisappeared = true
            if !isProcessing {
                MediaExportService.removeIfInTemporaryDirectory(selectedVideo)
                if !motionExport.isPresentingExportUI {
                    motionExport.cleanup()
                }
            }
        }
    }

    // MARK: - Step 01: Still Cover Card

    private var stepOneImageCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(Localizable.string(.customLiveStep1))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                if let size = selectedImagePixelSize, size.width > 0, size.height > 0 {
                    Text("\(Int(size.width)) × \(Int(size.height))")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            if let image = selectedImage {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.stageBackground)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 172)
                        .clipped()
                }
                .frame(height: 172)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 8) {
                Button {
                    AppHaptics.lightImpact()
                    isShowingImagePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 15, weight: .medium))
                        Text(selectedImage == nil ? Localizable.string(.selectImage) : Localizable.string(.changeImage))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioSecondaryCapsuleButtonStyle())
                .disabled(isProcessing)

                Button {
                    AppHaptics.lightImpact()
                    isShowingImageFileImporter = true
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 24)
                }
                .buttonStyle(StudioSecondaryCapsuleButtonStyle())
                .disabled(isProcessing)
                .accessibilityLabel(Localizable.string(.selectFromFiles))
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(isImageDropTargeted ? AppTheme.accent.opacity(0.08) : AppTheme.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                        .strokeBorder(
                            isImageDropTargeted ? AppTheme.accent : AppTheme.borderSubtle,
                            style: isImageDropTargeted ? StrokeStyle(lineWidth: 2, dash: [7, 5]) : StrokeStyle(lineWidth: 0.8)
                        )
                )
        )
        .overlay {
            if isImageDropTargeted {
                Text(Localizable.string(.dropImageHereHint))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule(style: .continuous).fill(AppTheme.surface0.opacity(0.95)))
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isImageDropTargeted) { providers in
            handleDroppedImageProviders(providers)
            return true
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 02: Motion Video Card

    private var stepTwoVideoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(Localizable.string(.customLiveStep2))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                if selectedVideo != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        if let duration = selectedVideoDuration, duration > 0 {
                            Text(String(format: "%@ · %.1fs", Localizable.string(.customLiveVideoReady), duration))
                                .font(.system(size: 12, weight: .semibold))
                        } else {
                            Text(Localizable.string(.customLiveVideoReady))
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(AppTheme.success)
                }
            }

            HStack(spacing: 8) {
                Button {
                    AppHaptics.lightImpact()
                    isShowingVideoPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "video")
                            .font(.system(size: 15, weight: .medium))
                        Text(selectedVideo == nil ? Localizable.string(.selectVideo) : Localizable.string(.changeVideo))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioSecondaryCapsuleButtonStyle())
                .disabled(isProcessing)

                Button {
                    AppHaptics.lightImpact()
                    isShowingVideoFileImporter = true
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 24)
                }
                .buttonStyle(StudioSecondaryCapsuleButtonStyle())
                .disabled(isProcessing)
                .accessibilityLabel(Localizable.string(.selectFromFiles))
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(isVideoDropTargeted ? AppTheme.accent.opacity(0.08) : AppTheme.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                        .strokeBorder(
                            isVideoDropTargeted ? AppTheme.accent : AppTheme.borderSubtle,
                            style: isVideoDropTargeted ? StrokeStyle(lineWidth: 2, dash: [7, 5]) : StrokeStyle(lineWidth: 0.8)
                        )
                )
        )
        .overlay {
            if isVideoDropTargeted {
                Text(Localizable.string(.dropVideoHereHint))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule(style: .continuous).fill(AppTheme.surface0.opacity(0.95)))
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL, .movie, .mpeg4Movie, .quickTimeMovie], isTargeted: $isVideoDropTargeted) { providers in
            handleDroppedVideoProviders(providers)
            return true
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 03: Export Target Switcher

    private var exportTargetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizable.string(.customPairTargetTitle))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 0) {
                ForEach(CustomPairExportTarget.allCases) { target in
                    let isSelected = (exportTarget == target)
                    Button {
                        AppHaptics.selection()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            exportTarget = target
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: target.icon)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            Text(target.displayName)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .padding(.horizontal, 8)
                        .contentShape(Capsule())
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(AppTheme.surface0)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.6)
                                    )
                                    .shadow(
                                        color: Color.black.opacity(colorScheme == .light ? 0.06 : 0),
                                        radius: 3,
                                        y: 1
                                    )
                                    .matchedGeometryEffect(id: "customPairTargetHighlight", in: targetAnimation)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            }
            .padding(3)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.surface1)
            )

            Text(exportTarget.description)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(AppTheme.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                        .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
                )
        )
        .frame(maxWidth: .infinity)
    }

    private func createLivePhoto() {
        guard let videoURL = selectedVideo, let imageData = resolvedImageData else { return }

        AppHaptics.mediumImpact()
        isProcessing = true
        Task {
            defer {
                isProcessing = false
                if hasDisappeared {
                    MediaExportService.removeIfInTemporaryDirectory(videoURL)
                }
            }
            do {
                let creationDate = ISOBMFFHelper.extractExifCreationDate(from: imageData) ?? Date()
                try await MediaExportService.exportCustomLivePhoto(
                    imageData: imageData,
                    videoURL: videoURL,
                    creationDate: creationDate
                )
                AppHaptics.success()
                alertIsSuccess = true
                alertMessage = Localizable.string(.livePhotoSaved)
                showAlert = true
            } catch {
                AppHaptics.error()
                alertIsSuccess = false
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func exportMotionPhoto(destination: MotionPhotoExportDestination) {
        guard let videoURL = selectedVideo, let imageData = resolvedImageData else { return }

        AppHaptics.mediumImpact()
        isProcessing = true
        motionExport.cleanup()

        Task {
            defer {
                isProcessing = false
                if hasDisappeared {
                    MediaExportService.removeIfInTemporaryDirectory(videoURL)
                }
            }
            do {
                let creationDate = ISOBMFFHelper.extractExifCreationDate(from: imageData)
                let outputURL = try await MediaExportService.exportMotionPhoto(
                    imageData: imageData,
                    videoURL: videoURL,
                    targetBrand: selectedBrand,
                    creationDate: creationDate
                )

                if hasDisappeared {
                    MediaExportService.removeIfInTemporaryDirectory(outputURL)
                    return
                }

                AppHaptics.success()
                motionExport.present(url: outputURL, destination: destination)
            } catch {
                AppHaptics.error()
                alertIsSuccess = false
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func loadImageFromLocalURL(_ url: URL) {
        Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try LocalMediaImportHelper.loadStillImageData(from: url)
                }.value
                selectedImage = loaded.image
                selectedImageData = loaded.data
                selectedImagePixelSize = loaded.pixelSize
            } catch {
                alertIsSuccess = false
                alertMessage = Localizable.string(.imageLoadFailed)
                showAlert = true
            }
        }
    }

    private func loadVideoFromLocalURL(_ url: URL) {
        Task {
            do {
                let loaded = try await LocalMediaImportHelper.loadVideoToTemp(from: url)
                let oldURL = selectedVideo
                selectedVideo = loaded.tempURL
                selectedVideoDuration = loaded.duration
                MediaExportService.removeIfInTemporaryDirectory(oldURL)
            } catch {
                alertIsSuccess = false
                alertMessage = Localizable.string(.videoLoadFailed)
                showAlert = true
            }
        }
    }

    private func handleDroppedImageProviders(_ providers: [NSItemProvider]) {
        guard let first = providers.first else { return }
        Task {
            let copied = await LocalMediaImportHelper.copyDroppedProvidersToTemp([first], acceptedTypes: [.image])
            guard let tempURL = copied.first else {
                alertIsSuccess = false
                alertMessage = Localizable.string(.imageLoadFailed)
                showAlert = true
                return
            }
            defer { MediaExportService.removeIfInTemporaryDirectory(tempURL) }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try LocalMediaImportHelper.loadStillImageData(from: tempURL)
                }.value
                selectedImage = loaded.image
                selectedImageData = loaded.data
                selectedImagePixelSize = loaded.pixelSize
            } catch {
                alertIsSuccess = false
                alertMessage = Localizable.string(.imageLoadFailed)
                showAlert = true
            }
        }
    }

    private func handleDroppedVideoProviders(_ providers: [NSItemProvider]) {
        guard let first = providers.first else { return }
        Task {
            let copied = await LocalMediaImportHelper.copyDroppedProvidersToTemp(
                [first],
                acceptedTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                defaultExtension: "mov"
            )
            guard let tempURL = copied.first else {
                alertIsSuccess = false
                alertMessage = Localizable.string(.videoLoadFailed)
                showAlert = true
                return
            }
            let asset = AVAsset(url: tempURL)
            let duration = try? await asset.load(.duration)
            let seconds = duration.map { CMTimeGetSeconds($0) }
            let oldURL = selectedVideo
            selectedVideo = tempURL
            selectedVideoDuration = (seconds?.isFinite == true && (seconds ?? 0) > 0) ? seconds : nil
            MediaExportService.removeIfInTemporaryDirectory(oldURL)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var imageData: Data?
    @Binding var pixelSize: CGSize?
    var onError: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider else { return }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    guard let data = data, error == nil else {
                        AppLogger.picker.error("Failed to load lab image: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                        Task { @MainActor in
                            self.parent.onError?(Localizable.string(.imageLoadFailed))
                        }
                        return
                    }
                    let dimensions = Self.readPixelDimensions(from: data)
                    let previewImage = Self.makePreviewThumbnail(from: data) ?? UIImage(data: data)
                    Task { @MainActor in
                        self.parent.imageData = data
                        self.parent.image = previewImage
                        self.parent.pixelSize = dimensions
                    }
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    guard let loaded = image as? UIImage, error == nil else {
                        AppLogger.picker.error("Failed to load lab UIImage: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                        Task { @MainActor in
                            self.parent.onError?(Localizable.string(.imageLoadFailed))
                        }
                        return
                    }
                    let jpegData = loaded.jpegData(compressionQuality: 1.0)
                    let dimensions = CGSize(width: loaded.size.width * loaded.scale, height: loaded.size.height * loaded.scale)
                    Task { @MainActor in
                        self.parent.image = loaded
                        self.parent.imageData = jpegData
                        self.parent.pixelSize = dimensions
                    }
                }
            }
        }

        private static func readPixelDimensions(from data: Data) -> CGSize? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
                  let h = props[kCGImagePropertyPixelHeight] as? CGFloat else {
                return nil
            }
            return CGSize(width: w, height: h)
        }

        private static func makePreviewThumbnail(from data: Data) -> UIImage? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 600
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Binding var videoDuration: Double?
    var onError: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    AppLogger.picker.error("Failed to load lab video: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                    Task { @MainActor in
                        self.parent.onError?(Localizable.string(.videoLoadFailed))
                    }
                    return
                }
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("lab_video_\(UUID().uuidString).\(ext)")
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    Task {
                        let asset = AVAsset(url: tempURL)
                        let duration = try? await asset.load(.duration)
                        let seconds = duration.map { CMTimeGetSeconds($0) }
                        await MainActor.run {
                            let oldURL = self.parent.videoURL
                            self.parent.videoURL = tempURL
                            self.parent.videoDuration = (seconds?.isFinite == true) ? seconds : nil
                            MediaExportService.removeIfInTemporaryDirectory(oldURL)
                        }
                    }
                } catch {
                    AppLogger.picker.error("Failed to copy lab video: \(error.localizedDescription, privacy: .public)")
                    Task { @MainActor in
                        self.parent.onError?(Localizable.string(.videoLoadFailed))
                    }
                }
            }
        }
    }
}

#Preview {
    LabView()
}
