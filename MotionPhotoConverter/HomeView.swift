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
    @State private var showingHelpSheet = false
    @State private var selectedMotionPhotoURL: URL?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Main image area
                    // heroSectionView
                    
                    // Core operation area
                    primaryActionView
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    
                    // Feature overview area
                    featuresOverviewView
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    
                    // Lab feature entrance
                    labEntryView
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle(Localizable.string(.appTitle))
            .navigationBarTitleDisplayMode(.large)
            .alert(isPresented: $showAlert) {
                Alert(title: Text(Localizable.string(.tip)), message: Text(alertMessage), dismissButton: .default(Text(Localizable.string(.ok))))
            }
            .alert("照片库访问权限", isPresented: $viewModel.showPermissionAlert) {
                Button("前往设置") {
                    viewModel.openAppSettings()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text(viewModel.permissionAlertMessage)
            }
            .sheet(isPresented: $viewModel.isShowingPhotoPicker) {
                PhotoPicker(
                    onImagePicked: { url, isMotionPhoto in
                        if isMotionPhoto {
                            selectedMotionPhotoURL = url
                        } else {
                            showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                        }
                    },
                    onNonMotionPhotoSelected: {
                        showAlert(message: Localizable.string(.selectedPhotoIsNotMotionPhoto))
                    },
                    onPhotoAccessDenied: {
                        showAlert(message: Localizable.string(.photoNotAccessibleInLimitedMode))
                    },
                    onCancelled: {
                        // User cancelled selection, no prompt displayed
                    }
                )
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedMotionPhotoURL != nil },
                set: { if !$0 { selectedMotionPhotoURL = nil } }
            )) {
                if let url = selectedMotionPhotoURL {
                    MotionPhotoView(sourceURL: url)
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        showingHelpSheet = true
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingLabView) {
                LabView()
            }
            .sheet(isPresented: $showingHelpSheet) {
                HelpSheetView()
            }
        }
    }
    
    private func showAlert(message: String) {
        print("Show alert: \(message)") // Add debug info
        alertMessage = message
        showAlert = true
        print("alertMessage: \(alertMessage), showAlert: \(showAlert)") // Add more debug info
    }
    
    // MARK: - Hero Section
    private var heroSectionView: some View {
        VStack(spacing: 20) {
            // Dynamic emoji grid background
            ZStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(viewModel.randomEmojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 35))
                            .opacity(0.8)
                    }
                }
                .padding(.horizontal, 30)
                
                // Main icon
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.blue)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 80, height: 80)
                    )
            }
            .frame(height: 50
            )
            
        }
        .padding(.vertical, 30)
//        .background(
//            LinearGradient(
//                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.clear]),
//                startPoint: .bottom,
//                endPoint: .top
//            )
//        )
    }
    
    // MARK: - Primary Action Section
    private var primaryActionView: some View {
        VStack(spacing: 16) {
            Button(action: {
                    viewModel.selectPhoto()
                }) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                    Text(Localizable.string(.selectMotionPhoto))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.borderedProminent)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: viewModel.isShowingPhotoPicker)
            
        }
    }
    
    // MARK: - Features Overview Section
    private var featuresOverviewView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(Localizable.string(.mainFeatures))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                FeatureRowView(
                    icon: "livephoto",
                    title: Localizable.string(.convertToLivePhoto),
                    description: Localizable.string(.convertToLivePhotoDescription),
                    color: .blue
                )
                
                FeatureRowView(
                    icon: "video.fill",
                    title: Localizable.string(.extractVideo),
                    description: Localizable.string(.extractVideoDescription),
                    color: .green
                )
                
                FeatureRowView(
                    icon: "rectangle.stack.fill",
                    title: Localizable.string(.generateGIF),
                    description: Localizable.string(.generateGIFDescription),
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(.thinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Lab Features Entry
    private var labEntryView: some View {
        Button(action: {
            showingLabView = true
        }) {
            HStack {
                Image(systemName: "flask.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(Localizable.string(.lab))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(Localizable.string(.exploreMoreFeatures))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(.thinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Row View
struct FeatureRowView: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Help Sheet
struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Help Type", selection: $selectedTab) {
                    Text("Quick Start").tag(0)
                    Text("Features").tag(1)
                    Text("FAQ").tag(2)
                    Text("Troubleshooting").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch selectedTab {
                        case 0:
                            quickStartContent
                        case 1:
                            featuresContent
                        case 2:
                            faqContent
                        case 3:
                            troubleshootingContent
                        default:
                            quickStartContent
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Start Content
    private var quickStartContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "About Motion2Live", icon: "info.circle.fill", color: .blue) {
                Text("Motion2Live is a professional motion photo converter that supports converting motion photos from various device brands to iOS native Live Photo format, making your memories more vivid.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HelpSectionView(title: "System Requirements", icon: "iphone", color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: "iOS 16.0 or later")
                    HelpBulletPoint(text: "Sufficient storage space for processing photos and videos")
                    HelpBulletPoint(text: "Photo library access permission")
                }
            }
            
            HelpSectionView(title: "Supported Motion Photo Formats", icon: "camera.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: "✅ Xiaomi Motion Photos (including MIUI and HyperOS versions)")
                    HelpBulletPoint(text: "✅ Google Pixel Motion Photo")
                    HelpBulletPoint(text: "✅ Samsung Motion Photos")
                }
            }
            
            HelpSectionView(title: "Usage Steps", icon: "list.number", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    HelpStepView(step: "1", title: "Select Motion Photo", description: "Tap the 'Select Motion Photo' button on the home page and choose the motion photo you want to convert from your album")
                    HelpStepView(step: "2", title: "Preview and Play", description: "View the static image and press and hold the screen to play the video portion")
                    HelpStepView(step: "3", title: "Choose Export Format", description: "Select to export as Live Photo, video, or GIF")
                    HelpStepView(step: "4", title: "Save to Album", description: "After conversion is complete, the file will be automatically saved to your photo album")
                }
            }
        }
    }
    
    // MARK: - Features Content
    private var featuresContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "Basic Features", icon: "star.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureDetailView(
                        icon: "livephoto",
                        title: "Convert to Live Photo",
                        description: "Convert motion photos to iOS native Live Photo format, supporting perfect playback across Apple devices",
                        color: .blue
                    )
                    
                    FeatureDetailView(
                        icon: "video.fill",
                        title: "Extract Video",
                        description: "Extract the video portion from motion photos and save as MP4 format for easy sharing and editing",
                        color: .green
                    )
                    
                    FeatureDetailView(
                        icon: "rectangle.stack.fill",
                        title: "Generate GIF",
                        description: "Convert motion photos to GIF format, supporting cross-platform sharing and social media use",
                        color: .orange
                    )
                }
            }
            
            HelpSectionView(title: "Lab Features", icon: "flask.fill", color: .purple) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: "Custom Live Photo: Create Live Photos using static images and video files")
                    HelpBulletPoint(text: "Batch Processing: Process multiple motion photos simultaneously")
                    HelpBulletPoint(text: "Advanced Export Options: Customize video quality and GIF parameters")
                }
            }
            
            HelpSectionView(title: "File Format Description", icon: "doc.fill", color: .indigo) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Motion Photo vs Live Photo")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("• Motion Photo: Android device motion photo format, typically a single JPEG file containing video data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("• Live Photo: Apple device proprietary format, consisting of a static image and MOV video")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - FAQ Content
    private var faqContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "Identification and Selection", icon: "questionmark.circle.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: "How do I know if my photo is a Motion Photo?",
                        answer: "In your photo album, Motion Photos usually display special icons or labels. In Motion2Live, if the selected photo is not a Motion Photo, the app will show a notification."
                    )
                    
                    FAQItemView(
                        question: "Why does the app say 'Not a valid Motion Photo'?",
                        answer: "This could be due to an unsupported format variant, the file being edited or modified, or corruption during transfer. We recommend using original, unedited files."
                    )
                }
            }
            
            HelpSectionView(title: "Conversion and Export", icon: "arrow.triangle.2.circlepath", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: "Where are the exported files saved?",
                        answer: "All exported files (Live Photos, GIFs, and videos) are saved to your device's photo library and can be viewed in the iOS Photos app."
                    )
                    
                    FAQItemView(
                        question: "What is the quality of exported Live Photos?",
                        answer: "The app tries to maintain original quality, but there may be slight quality loss due to format conversion. Quality depends on the resolution and bitrate of the original file."
                    )
                    
                    FAQItemView(
                        question: "Why do exported videos have no sound?",
                        answer: "This is normal. Most Motion Photo formats only capture video without audio, so extracted videos typically have no sound."
                    )
                }
            }
            
            HelpSectionView(title: "Compatibility", icon: "checkmark.shield.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: "Do Live Photos work properly on other devices?",
                        answer: "Live Photo is Apple's proprietary format, fully supported only on iOS 9+, macOS El Capitan+, and watchOS 2+ devices."
                    )
                    
                    FAQItemView(
                        question: "Does the app support batch processing?",
                        answer: "The current version does not support batch processing; files need to be converted individually. We plan to add batch processing functionality in future versions."
                    )
                }
            }
            
            HelpSectionView(title: "Performance Issues", icon: "speedometer", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: "What to do when processing large files is slow?",
                        answer: "Large files require more processing time. We recommend keeping the app in the foreground during processing and avoiding running other resource-intensive apps simultaneously."
                    )
                    
                    FAQItemView(
                        question: "Does the app drain battery quickly?",
                        answer: "Video processing is computationally intensive and consumes more power. We recommend performing bulk conversion operations while charging."
                    )
                }
            }
        }
    }
    
    // MARK: - Troubleshooting Content
    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "Permission Issues", icon: "lock.fill", color: .red) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("If the app cannot access photo library:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "Open Settings > Privacy > Photos")
                        HelpBulletPoint(text: "Find Motion2Live and set to 'All Photos'")
                        HelpBulletPoint(text: "Restart the app or device")
                    }
                }
            }
            
            HelpSectionView(title: "Export Failure", icon: "exclamationmark.triangle.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Possible solutions:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "Check if device has sufficient storage space")
                        HelpBulletPoint(text: "Close other apps to free up memory")
                        HelpBulletPoint(text: "Restart the application")
                        HelpBulletPoint(text: "Try processing smaller files")
                    }
                }
            }
            
            HelpSectionView(title: "Performance Optimization", icon: "speedometer", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestions to improve processing speed:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "Close unnecessary background apps")
                        HelpBulletPoint(text: "Ensure device has sufficient available storage space")
                        HelpBulletPoint(text: "Process large files when device is connected to power")
                        HelpBulletPoint(text: "Avoid processing when battery is low")
                    }
                }
            }
            
            HelpSectionView(title: "App Crashes", icon: "exclamationmark.octagon.fill", color: .red) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("If the app crashes while processing files:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "Restart the app and device")
                        HelpBulletPoint(text: "Try processing smaller files")
                        HelpBulletPoint(text: "Update the app to the latest version")
                        HelpBulletPoint(text: "Contact the developer to report the issue")
                    }
                }
            }
            
            HelpSectionView(title: "Contact Support", icon: "envelope.fill", color: .purple) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For further assistance, please contact:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("📧 Developer Email: shenjy302@live.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("🔗 GitHub: Motion2Live Project Page")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Motion2Live v1.2 © 2024 Igloo")
                          .font(.caption)
                          .foregroundColor(.secondary)
                          .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Help Step View
struct HelpStepView: View {
    let step: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Help Section View
struct HelpSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
              RoundedRectangle(cornerRadius: 12)
                  .fill(.regularMaterial)
          )
    }
}

// MARK: - Help Bullet Point View
struct HelpBulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Feature Detail View
struct FeatureDetailView: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// MARK: - FAQ Item View
struct FAQItemView: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView()
}
