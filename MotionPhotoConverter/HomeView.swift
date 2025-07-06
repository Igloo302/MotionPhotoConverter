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
                    // 主图区
                    // heroSectionView
                    
                    // 核心操作区
                    primaryActionView
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    
                    // 功能概览区
                    featuresOverviewView
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    
                    // 实验室功能入口
                    labEntryView
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Motion2Live")
            .navigationBarTitleDisplayMode(.large)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
            }
            .sheet(isPresented: $viewModel.isShowingPhotoPicker) {
                PhotoPicker(
                    onImagePicked: { url, isMotionPhoto in
                        if isMotionPhoto {
                            selectedMotionPhotoURL = url
                        } else {
                            showAlert(message: "所选照片不是动态照片")
                        }
                    },
                    onNonMotionPhotoSelected: {
                        showAlert(message: "所选照片不是动态照片")
                    },
                    onCancelled: {
                        // 用户取消选择，不显示任何提示
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
                Text("实验室功能即将推出")
                    .font(.title2)
                    .padding()
            }
            .sheet(isPresented: $showingHelpSheet) {
                HelpSheetView()
            }
        }
    }
    
    private func showAlert(message: String) {
        print("显示警告: \(message)") // 添加调试信息
        alertMessage = message
        showAlert = true
        print("alertMessage: \(alertMessage), showAlert: \(showAlert)") // 添加更多调试信息
    }
    
    // MARK: - 主图区
    private var heroSectionView: some View {
        VStack(spacing: 20) {
            // 动态表情网格背景
            ZStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(viewModel.randomEmojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 35))
                            .opacity(0.8)
                    }
                }
                .padding(.horizontal, 30)
                
                // 主图标
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
    
    // MARK: - 核心操作区
    private var primaryActionView: some View {
        VStack(spacing: 16) {
            Button(action: {
                    viewModel.selectPhoto()
                }) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                    Text("选择动态照片")
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
    
    // MARK: - 功能概览区
    private var featuresOverviewView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("主要功能")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                FeatureRowView(
                    icon: "livephoto",
                    title: "转换 Live Photo",
                    description: "将动态照片转换为 iOS 原生实况照片格式",
                    color: .blue
                )
                
                FeatureRowView(
                    icon: "video.fill",
                    title: "提取独立视频",
                    description: "从动态照片中提取视频部分并保存",
                    color: .green
                )
                
                FeatureRowView(
                    icon: "rectangle.stack.fill",
                    title: "生成 GIF 动图",
                    description: "将动态照片转换为可分享的 GIF 格式",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(.thinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - 实验室功能入口
    private var labEntryView: some View {
        Button(action: {
            showingLabView = true
        }) {
            HStack {
                Image(systemName: "flask.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("实验室功能")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("探索更多创新功能")
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

// MARK: - 功能行视图
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

// MARK: - 帮助页面
struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标签选择器
                Picker("帮助类型", selection: $selectedTab) {
                    Text("快速开始").tag(0)
                    Text("功能介绍").tag(1)
                    Text("常见问题").tag(2)
                    Text("故障排除").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // 内容区域
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
            .navigationTitle("帮助")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 快速开始内容
    private var quickStartContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "关于 Motion2Live", icon: "info.circle.fill", color: .blue) {
                Text("Motion2Live 是一款专业的动态照片转换工具，支持将各种品牌设备拍摄的动态照片转换为 iOS 原生的 Live Photo 格式，让您的回忆更加生动。")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HelpSectionView(title: "系统要求", icon: "iphone", color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: "iOS 16.0 或更高版本")
                    HelpBulletPoint(text: "足够的存储空间用于处理照片和视频")
                    HelpBulletPoint(text: "照片库访问权限")
                }
            }
            
            HelpSectionView(title: "支持的动态照片格式", icon: "camera.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: "✅ 小米动态照片（包括 MIUI 和 HyperOS 版本）")
                    HelpBulletPoint(text: "✅ Google Pixel Motion Photo")
                    HelpBulletPoint(text: "✅ 三星动态照片")
                }
            }
            
            HelpSectionView(title: "使用步骤", icon: "list.number", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    HelpStepView(step: "1", title: "选择动态照片", description: "点击主页的'选择动态照片'按钮，从相册中选择您要转换的动态照片")
                    HelpStepView(step: "2", title: "预览和播放", description: "查看静态图像，按住屏幕播放视频部分")
                    HelpStepView(step: "3", title: "选择导出格式", description: "选择导出为 Live Photo、视频或 GIF")
                    HelpStepView(step: "4", title: "保存到相册", description: "转换完成后，文件将自动保存到您的相册中")
                }
            }
        }
    }
    
    // MARK: - 功能介绍内容
    private var featuresContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "基本功能", icon: "star.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureDetailView(
                        icon: "livephoto",
                        title: "转换 Live Photo",
                        description: "将动态照片转换为 iOS 原生实况照片格式，支持在 Apple 设备间完美播放",
                        color: .blue
                    )
                    
                    FeatureDetailView(
                        icon: "video.fill",
                        title: "提取独立视频",
                        description: "从动态照片中提取视频部分并保存为 MP4 格式，便于分享和编辑",
                        color: .green
                    )
                    
                    FeatureDetailView(
                        icon: "rectangle.stack.fill",
                        title: "生成 GIF 动图",
                        description: "将动态照片转换为 GIF 格式，支持跨平台分享和社交媒体使用",
                        color: .orange
                    )
                }
            }
            
            HelpSectionView(title: "实验室功能", icon: "flask.fill", color: .purple) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpBulletPoint(text: "自定义 Live Photo：使用静态照片和视频文件创建 Live Photo")
                    HelpBulletPoint(text: "批量处理：同时处理多个动态照片")
                    HelpBulletPoint(text: "高级导出选项：自定义视频质量和 GIF 参数")
                }
            }
            
            HelpSectionView(title: "文件格式说明", icon: "doc.fill", color: .indigo) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Motion Photo vs Live Photo")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("• Motion Photo：Android 设备的动态照片格式，通常是单个 JPEG 文件包含视频数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("• Live Photo：Apple 设备的专有格式，由静态图像和 MOV 视频组成")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 常见问题内容
    private var faqContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "识别和选择", icon: "questionmark.circle.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: "如何知道我的照片是否是 Motion Photo？",
                        answer: "在相册中，Motion Photo 通常会显示特殊图标或标签。在 Motion2Live 中，如果选择的不是 Motion Photo，应用会显示提示信息。"
                    )
                    
                    FAQItemView(
                        question: "为什么应用提示'不是有效的 Motion Photo'？",
                        answer: "可能是不支持的格式变体、文件已被编辑修改，或文件在传输过程中损坏。建议使用原始未编辑的文件。"
                    )
                }
            }
            
            HelpSectionView(title: "转换和导出", icon: "arrow.triangle.2.circlepath", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: "导出的文件保存在哪里？",
                        answer: "所有导出的文件（Live Photo、GIF 和视频）都保存在您设备的照片库中，可在 iOS 的'照片'应用中查看。"
                    )
                    
                    FAQItemView(
                        question: "导出的 Live Photo 质量如何？",
                        answer: "应用会尽量保持原始质量，但由于格式转换可能有轻微质量损失。质量取决于原始文件的分辨率和比特率。"
                    )
                    
                    FAQItemView(
                        question: "为什么导出的视频没有声音？",
                        answer: "这是正常的。大多数 Motion Photo 格式只捕捉视频而不包含音频，因此提取的视频通常没有声音。"
                    )
                }
            }
            
            HelpSectionView(title: "兼容性", icon: "checkmark.shield.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    FAQItemView(
                        question: "Live Photo 在其他设备上能正常工作吗？",
                        answer: "Live Photo 是 Apple 专有格式，仅在 iOS 9+、macOS El Capitan+ 和 watchOS 2+ 设备上完全支持。"
                    )
                    
                    FAQItemView(
                        question: "应用支持批量处理吗？",
                        answer: "当前版本不支持批量处理，需要逐个转换。我们计划在未来版本中添加批量处理功能。"
                    )
                }
            }
        }
    }
    
    // MARK: - 故障排除内容
    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(title: "权限问题", icon: "lock.fill", color: .red) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("如果应用无法访问照片库：")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "打开设置 > 隐私 > 照片")
                        HelpBulletPoint(text: "找到 Motion2Live 并设置为'所有照片'")
                        HelpBulletPoint(text: "重启应用或设备")
                    }
                }
            }
            
            HelpSectionView(title: "导出失败", icon: "exclamationmark.triangle.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("可能的解决方案：")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "检查设备存储空间是否充足")
                        HelpBulletPoint(text: "关闭其他应用释放内存")
                        HelpBulletPoint(text: "重新启动应用")
                        HelpBulletPoint(text: "尝试处理较小的文件")
                    }
                }
            }
            
            HelpSectionView(title: "性能优化", icon: "speedometer", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("提升处理速度的建议：")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "关闭不必要的后台应用")
                        HelpBulletPoint(text: "确保设备有足够的可用存储空间")
                        HelpBulletPoint(text: "在设备连接电源时处理大文件")
                        HelpBulletPoint(text: "避免在电池电量低时处理")
                    }
                }
            }
            
            HelpSectionView(title: "应用崩溃", icon: "exclamationmark.octagon.fill", color: .red) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("如果应用在处理文件时崩溃：")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpBulletPoint(text: "重启应用和设备")
                        HelpBulletPoint(text: "尝试处理较小的文件")
                        HelpBulletPoint(text: "更新应用到最新版本")
                        HelpBulletPoint(text: "联系开发者报告问题")
                    }
                }
            }
            
            HelpSectionView(title: "联系支持", icon: "envelope.fill", color: .purple) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("如需进一步帮助，请联系：")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("📧 开发者邮箱：shenjy302@live.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("🔗 GitHub：Motion2Live 项目页面")
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

// MARK: - 帮助步骤视图
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

// MARK: - 帮助区块视图
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

// MARK: - 帮助要点视图
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

// MARK: - 功能详情视图
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

// MARK: - FAQ 项目视图
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
