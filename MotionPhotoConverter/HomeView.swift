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
    @State private var showPhotoAccessAlert = false
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
            .navigationTitle(L(.appTitle))
            .navigationBarTitleDisplayMode(.large)
            .alert(isPresented: $showAlert) {
                Alert(title: Text(L(.tip)), message: Text(alertMessage), dismissButton: .default(Text(L(.ok))))
            }
            .alert(L(.photoAccessDenied), isPresented: $showPhotoAccessAlert) {
                Button(L(.goToSettings)) {
                    viewModel.openAppSettings()
                }
                Button(L(.cancel), role: .cancel) { }
            } message: {
                Text(L(.photoNotAccessibleInLimitedMode))
            }
            .alert(L(.photoLibraryAccessPermission), isPresented: $viewModel.showPermissionAlert) {
                Button(L(.goToSettings)) {
                    viewModel.openAppSettings()
                }
                Button(L(.cancel), role: .cancel) { }
            } message: {
                Text(viewModel.permissionAlertMessage)
            }
            .sheet(isPresented: $viewModel.isShowingPhotoPicker) {
                PhotoPicker(
                    onImagePicked: { url, isMotionPhoto in
                        if isMotionPhoto {
                            selectedMotionPhotoURL = url
                        } else {
                            showAlert(message: L(.selectedPhotoIsNotMotionPhoto))
                        }
                    },
                    onNonMotionPhotoSelected: {
                        showAlert(message: L(.selectedPhotoIsNotMotionPhoto))
                    },
                    onPhotoAccessDenied: {
                        showPhotoAccessAlert = true
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
                    Text(L(.selectMotionPhoto))
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
            Text(L(.mainFeatures))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                FeatureRowView(
                    icon: "livephoto",
                    title: L(.convertToLivePhoto),
                    description: L(.convertToLivePhotoDescription),
                    color: .blue
                )
                
                FeatureRowView(
                    icon: "video.fill",
                    title: L(.extractVideo),
                    description: L(.extractVideoDescription),
                    color: .green
                )
                
                FeatureRowView(
                    icon: "rectangle.stack.fill",
                    title: L(.generateGIF),
                    description: L(.generateGIFDescription),
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
                    Text(L(.lab))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(L(.exploreMoreFeatures))
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
                    Text(L(.quickStart)).tag(0)
                    Text(L(.features)).tag(1)
                    Text(L(.faq)).tag(2)
                    Text(L(.troubleshooting)).tag(3)
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
            .navigationTitle(L(.help))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L(.done)) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Start Content
    private var quickStartContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: L(.aboutMotion2Live), icon: "info.circle.fill", color: .blue) {
                Text(L(.aboutMotion2LiveDescription))
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HelpSectionView(title: L(.systemRequirements), icon: "iphone", color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: L(.systemRequirementsIOS))
                    HelpBulletPoint(text: L(.systemRequirementsStorage))
                    HelpBulletPoint(text: L(.systemRequirementsPermission))
                }
            }
            
            HelpSectionView(title: L(.supportedMotionPhotoFormats), icon: "camera.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: L(.supportedXiaomi))
                    HelpBulletPoint(text: L(.supportedGoogle))
                    HelpBulletPoint(text: L(.supportedSamsung))
                    HelpBulletPoint(text: L(.supportedHuawei))
                }
            }
            
            HelpSectionView(title: L(.usageSteps), icon: "list.number", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    HelpStepView(step: "1", title: L(.step1Title), description: L(.step1Description))
                    HelpStepView(step: "2", title: L(.step2Title), description: L(.step2Description))
                    HelpStepView(step: "3", title: L(.step3Title), description: L(.step3Description))
                    HelpStepView(step: "4", title: L(.step4Title), description: L(.step4Description))
                }
            }
        }
    }
    
    // MARK: - Features Content
    private var featuresContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Multi-Brand Support
            HelpSectionView(title: L(.multiBrandSupport), icon: "iphone.and.arrow.forward", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L(.multiBrandSupportDescription))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FeatureDetailView(
                        icon: "iphone",
                        title: L(.xiaomiSupport),
                        description: L(.xiaomiSupportDescription),
                        color: .orange
                    )
                    
                    FeatureDetailView(
                        icon: "camera.fill",
                        title: L(.googlePixelSupport),
                        description: L(.googlePixelSupportDescription),
                        color: .green
                    )
                    
                    FeatureDetailView(
                        icon: "camera.macro",
                        title: L(.samsungSupport),
                        description: L(.samsungSupportDescription),
                        color: .blue
                    )
                    
                    FeatureDetailView(
                        icon: "camera.aperture",
                        title: L(.huaweiSupport),
                        description: L(.huaweiSupportDescription),
                        color: .red
                    )
                    
                    FeatureDetailView(
                        icon: "brain.head.profile",
                        title: L(.intelligentDetection),
                        description: L(.intelligentDetectionDescription),
                        color: .purple
                    )
                }
            }
            
            // Smart User Experience
            HelpSectionView(title: L(.smartUserExperience), icon: "hand.tap.fill", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L(.smartUserExperienceDescription))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FeatureDetailView(
                        icon: "lightbulb.fill",
                        title: L(.firstTimeGuidance),
                        description: L(.firstTimeGuidanceDescription),
                        color: .yellow
                    )
                    
                    FeatureDetailView(
                        icon: "hand.point.up.left.fill",
                        title: L(.intuitiveOperation),
                        description: L(.intuitiveOperationDescription),
                        color: .blue
                    )
                    
                    FeatureDetailView(
                        icon: "brain.fill",
                        title: L(.statusMemory),
                        description: L(.statusMemoryDescription),
                        color: .purple
                    )
                    
                    FeatureDetailView(
                        icon: "sparkles",
                        title: L(.streamlinedExperience),
                        description: L(.streamlinedExperienceDescription),
                        color: .pink
                    )
                }
            }
            
            // Video Processing
            HelpSectionView(title: L(.videoProcessing), icon: "video.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L(.videoProcessingDescription))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FeatureDetailView(
                        icon: "4k.tv.fill",
                        title: L(.highQualityExtraction),
                        description: L(.highQualityExtractionDescription),
                        color: .blue
                    )
                    
                    FeatureDetailView(
                        icon: "play.circle.fill",
                        title: L(.smartPlayback),
                        description: L(.smartPlaybackDescription),
                        color: .green
                    )
                    
                    FeatureDetailView(
                        icon: "info.circle.fill",
                        title: L(.metadataPreservation),
                        description: L(.metadataPreservationDescription),
                        color: .indigo
                    )
                }
            }
            
            // Live Photo Conversion
            HelpSectionView(title: L(.livePhotoConversion), icon: "livephoto", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L(.livePhotoConversionDescription))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FeatureDetailView(
                        icon: "checkmark.seal.fill",
                        title: L(.nativeCompatibility),
                        description: L(.nativeCompatibilityDescription),
                        color: .green
                    )
                    
                    FeatureDetailView(
                        icon: "clock.fill",
                        title: L(.timeSynchronization),
                        description: L(.timeSynchronizationDescription),
                        color: .blue
                    )
                    
                    FeatureDetailView(
                        icon: "slider.horizontal.3",
                        title: L(.qualityOptimization),
                        description: L(.qualityOptimizationDescription),
                        color: .orange
                    )
                }
            }
            
            // GIF Export
            HelpSectionView(title: L(.gifExport), icon: "rectangle.stack.fill", color: .pink) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L(.gifExportDescription))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FeatureDetailView(
                        icon: "wand.and.stars",
                        title: L(.highQualityConversion),
                        description: L(.highQualityConversionDescription),
                        color: .purple
                    )
                    
                    FeatureDetailView(
                        icon: "gearshape.fill",
                        title: L(.automaticOptimization),
                        description: L(.automaticOptimizationDescription),
                        color: .blue
                    )
                    
                    FeatureDetailView(
                        icon: "square.and.arrow.up.fill",
                        title: L(.socialSharing),
                        description: L(.socialSharingDescription),
                        color: .green
                    )
                }
            }
            
            // Modern Interface
            HelpSectionView(title: L(.modernInterface), icon: "paintbrush.fill", color: .indigo) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L(.modernInterfaceDescription))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FeatureDetailView(
                        icon: "swift",
                        title: L(.swiftUIDesign),
                        description: L(.swiftUIDesignDescription),
                        color: .orange
                    )
                    
                    FeatureDetailView(
                        icon: "moon.fill",
                        title: L(.darkModeSupport),
                        description: L(.darkModeSupportDescription),
                        color: .indigo
                    )
                    
                    FeatureDetailView(
                        icon: "sparkles",
                        title: L(.animationEffects),
                        description: L(.animationEffectsDescription),
                        color: .pink
                    )
                    
                    FeatureDetailView(
                        icon: "questionmark.circle.fill",
                        title: L(.helpSystem),
                        description: L(.helpSystemDescription),
                        color: .blue
                    )
                }
            }
        }
    }
    
    // MARK: - FAQ Content
    private var faqContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: L(.faq), icon: "questionmark.circle.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: L(.faqWhatIsMotionPhoto),
                        answer: L(.faqWhatIsMotionPhotoAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqWhatIsLivePhoto),
                        answer: L(.faqWhatIsLivePhotoAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqAppMainFunction),
                        answer: L(.faqAppMainFunctionAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqHowToSelectMotionPhoto),
                        answer: L(.faqHowToSelectMotionPhotoAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqHowToConvertToLivePhoto),
                        answer: L(.faqHowToConvertToLivePhotoAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqHowToConvertToGIF),
                        answer: L(.faqHowToConvertToGIFAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqSupportedDevices),
                        answer: L(.faqSupportedDevicesAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqGIFFileSize),
                        answer: L(.faqGIFFileSizeAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqBatchProcessing),
                        answer: L(.faqBatchProcessingAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqFileSaveLocation),
                        answer: L(.faqFileSaveLocationAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqExportFailureReasons),
                        answer: L(.faqExportFailureReasonsAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqLivePhotoCompatibility),
                        answer: L(.faqLivePhotoCompatibilityAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.faqVideoNoSound),
                        answer: L(.faqVideoNoSoundAnswer)
                    )
                }
            }
            
            HelpSectionView(title: L(.featureRequestsAndFeedback), icon: "envelope.fill", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: L(.newFeaturePlans),
                        answer: L(.newFeaturePlansAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.howToReportBugs),
                        answer: L(.howToReportBugsAnswer)
                    )
                    
                    FAQItemView(
                        question: L(.contactInformation),
                        answer: L(.contactInformationAnswer)
                    )
                }
            }
        }
    }
    
    // MARK: - Troubleshooting Content
    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: L(.troubleshooting), icon: "wrench.fill", color: .red) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: L(.troubleshootingInvalidMotionPhoto),
                        answer: L(.troubleshootingInvalidMotionPhotoSolution)
                    )
                    
                    FAQItemView(
                        question: L(.troubleshootingPhotoLibraryAccess),
                        answer: L(.troubleshootingPhotoLibraryAccessSolution)
                    )
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
