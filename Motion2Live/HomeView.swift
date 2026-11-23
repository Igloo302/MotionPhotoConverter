//
//  HomeView.swift
//  Motion2Live
//
//  Created by Igloo on 9/21/24.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingLabView = false
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                emojiGridView
                contentView
            }
            .edgesIgnoringSafeArea(.top)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(Localizable.string(.tip)),
                    message: Text(alertMessage),
                    dismissButton: .default(Text(Localizable.string(.ok)))
                )
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
                        DispatchQueue.main.async {
                            if totalCount <= 1 {
                                self.showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                            } else {
                                self.showAlert(message: Localizable.string(.noValidMotionPhotosInBatch, totalCount))
                            }
                        }
                    },
                    onAnalyzingProgress: { current, total in
                        viewModel.analyzingCurrent = current
                        viewModel.analyzingTotal = total
                        viewModel.isAnalyzingPhotos = (current < total)
                    }
                )
            }
            .sheet(isPresented: $viewModel.isShowingBatchView) {
                BatchConvertView(
                    motionPhotoURLs: viewModel.batchURLs,
                    ignoredCount: viewModel.ignoredCount,
                    onDismiss: {
                        viewModel.isShowingBatchView = false
                        viewModel.batchURLs = []
                        viewModel.ignoredCount = 0
                    }
                )
            }
            .sheet(isPresented: $showingLabView) {
                LabView()
            }
            .overlay {
                if viewModel.isAnalyzingPhotos {
                    ZStack {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text(Localizable.string(.analyzingPhotos, viewModel.analyzingCurrent, viewModel.analyzingTotal))
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(20)
                        .background(Color(UIColor.darkGray).opacity(0.85))
                        .cornerRadius(14)
                    }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingLabView = true
                        }) {
                            Label(Localizable.string(.lab), systemImage: "flask")
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
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private var emojiGridView: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.randomEmojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 34))
                }
            }
            .padding(.top, 40)
            
            Text("📷")
                .font(.system(size: 70))
                .offset(y: 20)
        }
        .frame(height: 240)
        .background(Color.gray.opacity(0.1))
    }
    
    private var contentView: some View {
        VStack(spacing: 18) {
            Text(Localizable.string(.homeTitle))
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
            
            Text(Localizable.string(.homeDescription))
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .foregroundColor(.secondary)
            
            SupportedBrandsView()
                .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: viewModel.selectPhoto) {
                Text(Localizable.string(.selectMotionPhoto))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
    }
}

#Preview {
    HomeView()
}
