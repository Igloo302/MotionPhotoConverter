//
//  MotionPhotoExportComponents.swift
//  Motion2Live
//
//  Shared UI and export presentation components for 7-brand Motion Photo (.jpg)
//  reverse encoding in LabView (CustomLivePhotoView) and LiveToMotionView.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum MotionPhotoExportDestination {
    case share
    case files
}

@MainActor
final class MotionPhotoExportCoordinator: ObservableObject {
    @Published var exportedFileURL: URL?
    @Published var exportDocument: MotionPhotoFileDocument?
    @Published var isShowingShareSheet = false
    @Published var isShowingFileExporter = false

    var isPresentingExportUI: Bool {
        isShowingShareSheet || isShowingFileExporter
    }

    func present(url: URL, destination: MotionPhotoExportDestination) {
        exportedFileURL = url
        switch destination {
        case .share:
            isShowingShareSheet = true
        case .files:
            exportDocument = MotionPhotoFileDocument(fileURL: url)
            isShowingFileExporter = true
        }
    }

    func cleanup() {
        exportDocument = nil
        MediaExportService.removeIfInTemporaryDirectory(exportedFileURL)
        exportedFileURL = nil
    }
}

struct MotionPhotoBrandPickerCard: View {
    @Binding var selectedBrand: MotionPhotoBrand
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localizable.string(.liveToMotionBrandTitle))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 115), spacing: 8)], spacing: 8) {
                ForEach(MotionPhotoEncoder.supportedBrands, id: \.self) { brand in
                    let isSelected = (brand == selectedBrand)
                    Button {
                        AppHaptics.selection()
                        selectedBrand = brand
                    } label: {
                        Text(brand.displayName)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? AppTheme.accent : AppTheme.surface1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(isSelected ? AppTheme.accent : AppTheme.borderSubtle, lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                }
            }
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
}

struct MotionPhotoExportNoticeBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.top, 1)

            Text(Localizable.string(.liveToMotionExportNotice))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct MotionPhotoExportActionBar: View {
    let canExport: Bool
    let isProcessing: Bool
    let onShare: () -> Void
    let onSaveToFiles: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onShare) {
                HStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(Localizable.string(.liveToMotionShare))
                        .lineLimit(1)
                }
            }
            .buttonStyle(StudioPrimaryButtonStyle(isDisabled: !canExport, height: 52))
            .disabled(!canExport)

            Button(action: onSaveToFiles) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 15, weight: .medium))
                    Text(Localizable.string(.liveToMotionSaveToFiles))
                        .lineLimit(1)
                }
                .frame(height: 52)
                .padding(.horizontal, 16)
                .foregroundColor(canExport ? AppTheme.textPrimary : AppTheme.textTertiary)
                .background(
                    Capsule()
                        .fill(AppTheme.surface1)
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.borderSubtle, lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canExport)
        }
    }
}

struct MotionPhotoFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.jpeg] }

    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: fileURL, options: .immediate)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MotionPhotoExportSheetsModifier: ViewModifier {
    @ObservedObject var coordinator: MotionPhotoExportCoordinator
    let onSavedToFiles: () -> Void
    let onError: (String) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $coordinator.isShowingShareSheet, onDismiss: {
                coordinator.cleanup()
            }) {
                if let fileURL = coordinator.exportedFileURL {
                    ActivityShareSheet(activityItems: [fileURL]) {
                        coordinator.cleanup()
                    }
                    .ignoresSafeArea()
                }
            }
            .fileExporter(
                isPresented: $coordinator.isShowingFileExporter,
                document: coordinator.exportDocument,
                contentType: .jpeg,
                defaultFilename: coordinator.exportedFileURL?.deletingPathExtension().lastPathComponent ?? "MotionPhoto"
            ) { result in
                coordinator.cleanup()
                switch result {
                case .success:
                    AppHaptics.success()
                    onSavedToFiles()
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError {
                        AppHaptics.error()
                        onError(error.localizedDescription)
                    }
                }
            }
    }
}

extension View {
    func motionPhotoExportSheets(
        coordinator: MotionPhotoExportCoordinator,
        onSavedToFiles: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) -> some View {
        modifier(
            MotionPhotoExportSheetsModifier(
                coordinator: coordinator,
                onSavedToFiles: onSavedToFiles,
                onError: onError
            )
        )
    }
}
