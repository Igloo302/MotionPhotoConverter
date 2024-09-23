//
//  HomeView.swift
//  MotionPhotoConverter
//
//  Created by Igloo on 9/21/24.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingLabView = false
    @State private var showingAboutAlert = false

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                emojiGridView
                contentView
            }
            .edgesIgnoringSafeArea(.top)
            .alert(isPresented: $showAlert) {
                Alert(title: Text(Localizable.string(.tip)), message: Text(alertMessage), dismissButton: .default(Text(Localizable.string(.ok))))
            }
            .sheet(isPresented: $viewModel.isShowingPhotoPicker) {
                PhotoPicker(onImagePicked: { url, isMotionPhoto in
                    if isMotionPhoto {
                        viewModel.selectedImageURL = url
                    } else {
                        print("错误: 所选照片不是 Motion Photo")
                        DispatchQueue.main.async {
                            self.showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                        }
                    }
                }, onNonMotionPhotoSelected: {
                    print("错误: 所选照片不是 Motion Photo")
                    DispatchQueue.main.async {
                        self.showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                    }
                })
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
                        
                        // Button(action: {
                        //     showingAboutAlert = true
                        // }) {
                        //     Label(Localizable.string(.about), systemImage: "info.circle")
                        // }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingLabView) {
                LabView()
            }
//            .alert(isPresented: $showingAboutAlert) {
//                Alert(
//                    title: Text(Localizable.string(.about)),
//                    message: Text(Localizable.string(.aboutDescription)),
//                    dismissButton: .default(Text(Localizable.string(.ok)))
//                )
//            }
        }
    }
    
    private func showAlert(message: String) {
        print("显示警告: \(message)") // 添加调试信息
        alertMessage = message
        showAlert = true
        print("alertMessage: \(alertMessage), showAlert: \(showAlert)") // 添加更多调试信息
    }
    
    private var emojiGridView: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.randomEmojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 40))
                }
            }
            .padding(.top, 40)
            
            Text("📷")
                .font(.system(size: 80))
                .offset(y: 20)
        }
        .frame(height: UIScreen.main.bounds.height * 0.35)
        .background(Color.gray.opacity(0.1))
    }
    
    private var contentView: some View {
        VStack(spacing: 30) {
            Text(Localizable.string(.homeTitle))
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            
            Text(Localizable.string(.homeDescription))
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .foregroundColor(.secondary)
            
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
            .padding(.bottom, 40)
        }
        .padding(.top, 40)
    }
}

#Preview {
    HomeView()
}
