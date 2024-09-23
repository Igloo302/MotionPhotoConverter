import SwiftUI
import PhotosUI
import AVFoundation
import MobileCoreServices

struct LabView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(Localizable.string(.labDescription))) {
                    NavigationLink(destination: CustomLivePhotoView()) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text(Localizable.string(.customLivePhoto))
                                    .font(.headline)
                            }
                            Text(Localizable.string(.customLivePhotoDescription))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(Localizable.string(.lab))
        }
    }
}

struct CustomLivePhotoView: View {
    @State private var selectedImage: UIImage?
    @State private var selectedVideo: URL?
    @State private var isShowingImagePicker = false
    @State private var isShowingVideoPicker = false
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(Localizable.string(.customLivePhotoDescription))
                .padding()
                .multilineTextAlignment(.center)
            
            Button(action: {
                isShowingImagePicker = true
            }) {
                Text(selectedImage == nil ? Localizable.string(.selectImage) : Localizable.string(.changeImage))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.bordered)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
            }
            
            Button(action: {
                isShowingVideoPicker = true
            }) {
                Text(selectedVideo == nil ? Localizable.string(.selectVideo) : Localizable.string(.changeVideo))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.bordered)
            
            if selectedVideo != nil {
                Text(Localizable.string(.videoSelected))
                    .foregroundColor(.green)
            }
            
            Button(action: createLivePhoto) {
                Text(Localizable.string(.createLivePhoto))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImage == nil || selectedVideo == nil || isProcessing)
            
            if isProcessing {
                ProgressView()
            }
            
            Spacer()
        }
        .navigationTitle(Localizable.string(.customLivePhoto))
        .padding()
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $isShowingVideoPicker) {
            VideoPicker(videoURL: $selectedVideo)
        }
        .alert(isPresented: $showAlert) {
    Alert(
        title: Text(alertMessage.contains(Localizable.string(.livePhotoSaved)) ? Localizable.string(.success) : Localizable.string(.error)),
        message: Text(alertMessage),
        dismissButton: .default(Text(Localizable.string(.ok)))
    )
}
    }
    
    func createLivePhoto() {
        guard let image = selectedImage, let videoURL = selectedVideo else { return }
        
        isProcessing = true
        
        LivePhotoCreator.create(from: image, videoURL: videoURL) { result in
            DispatchQueue.main.async {
                isProcessing = false
                switch result {
                case .success:
                    alertMessage = Localizable.string(.livePhotoSaved)
                    showAlert = true
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<VideoPicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.videoQuality = .typeHigh
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<VideoPicker>) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let url = info[.mediaURL] as? URL else { return }
            parent.videoURL = url
        }
    }
}

import Foundation
import Photos
import MobileCoreServices
import AVFoundation

class LivePhotoCreator {
    
    static func create(from image: UIImage, videoURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let assetIdentifier = UUID().uuidString
        
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.imageConversionFailed)])))
            return
        }
        
        let tempImageURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(assetIdentifier).jpg")
        let tempVideoURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(assetIdentifier).mov")
        
        do {
            try imageData.write(to: tempImageURL)
            
            convertVideoToQuickTimeMovie(inputURL: videoURL, outputURL: tempVideoURL) { result in
                switch result {
                case .success:
                    self.writeMetadataToImage(imageURL: tempImageURL, assetIdentifier: assetIdentifier) { result in
                        switch result {
                        case .success:
                            self.saveLivePhoto(imageData: try! Data(contentsOf: tempImageURL), videoURL: tempVideoURL, creationDate: Date(), modificationDate: Date(), completion: completion)
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private static func convertVideoToQuickTimeMovie(inputURL: URL, outputURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.exportSessionCreationFailed)])))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(()))
            case .failed, .cancelled:
                completion(.failure(exportSession.error ?? NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.videoConversionFailed)])))
            default:
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.unknownError)])))
            }
        }
    }
    
    private static func writeMetadataToImage(imageURL: URL, assetIdentifier: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.imageSourceCreationFailed)])))
            return
        }
        
        guard let type = CGImageSourceGetType(source) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.imageTypeUnavailable)])))
            return
        }
        
        let metadata = NSMutableDictionary()
        metadata[kCGImagePropertyMakerAppleDictionary] = [
            "17": assetIdentifier
        ]
        
        guard let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, type, 1, nil) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.imageDestinationCreationFailed)])))
            return
        }
        
        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            completion(.success(()))
        } else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.metadataWriteFailed)])))
        }
    }
    
    private static func saveLivePhoto(imageData: Data, videoURL: URL, creationDate: Date, modificationDate: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        let assetIdentifier = UUID().uuidString
        
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.imageSourceCreationFailed)])))
            return
        }
        
        let imageData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(imageData, UTType.jpeg.identifier as CFString, 1, nil) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.imageDestinationCreationFailed)])))
            return
        }
        
        guard var mutableImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.imagePropertiesUnavailable)])))
            return
        }
        
        if var makerAppleDict = mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] {
            makerAppleDict["17"] = assetIdentifier
            mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerAppleDict
        } else {
            mutableImageProperties[kCGImagePropertyMakerAppleDictionary as String] = ["17": assetIdentifier]
        }
        
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, mutableImageProperties as CFDictionary)
        CGImageDestinationFinalize(imageDestination)
        
        let avAsset = AVAsset(url: videoURL)
        
        Task {
            do {
                let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough)
                guard let exporter = exportSession else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.exportSessionCreationFailed)])
                }
                
                let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
                exporter.outputURL = exportURL
                exporter.outputFileType = .mov
                
                let originalMetadata = try await avAsset.load(.metadata)
                let livePhotoMetadata: [AVMetadataItem] = [
                    {
                        let item = AVMutableMetadataItem()
                        item.key = "com.apple.quicktime.content.identifier" as NSString
                        item.keySpace = AVMetadataKeySpace.quickTimeMetadata
                        item.value = assetIdentifier as NSString
                        item.dataType = "com.apple.metadata.datatype.UTF-8"
                        return item
                    }(),
                    {
                        let item = AVMutableMetadataItem()
                        item.key = "com.apple.quicktime.still-image-time" as NSString
                        item.keySpace = AVMetadataKeySpace(rawValue: "mdta")
                        item.value = 0 as NSNumber
                        item.dataType = "com.apple.metadata.datatype.int8"
                        return item
                    }()
                ]
                exporter.metadata = originalMetadata + livePhotoMetadata
                
                await exporter.export()
                
                if exporter.status == .completed {
                    PHPhotoLibrary.shared().performChanges({
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: imageData as Data, options: nil)
                        creationRequest.addResource(with: .pairedVideo, fileURL: exportURL, options: nil)
                        creationRequest.creationDate = creationDate
                    }) { success, error in
                        if success {
                            completion(.success(()))
                        } else if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.unknownError)])))
                        }
                        
                        // 清理临时文件
                        try? FileManager.default.removeItem(at: exportURL)
                    }
                } else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: Localizable.string(.videoExportFailed)])
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}

struct LabView_Previews: PreviewProvider {
    static var previews: some View {
        LabView()
    }
}
