import Foundation

/// 本地化管理器，使用 String Catalogs 进行多语言支持
struct LocalizationManager {
    
    /// 获取本地化字符串
    /// - Parameter key: 本地化键
    /// - Returns: 本地化后的字符串
    static func localizedString(for key: LocalizableKey) -> String {
        return NSLocalizedString(key.rawValue, comment: "")
    }
}

/// 本地化键枚举
enum LocalizableKey: String, CaseIterable {
    // MARK: - 基础界面
    case switchLanguage = "switchLanguage"
    case appTitle = "appTitle"
    case convert = "convert"
    case selectFile = "selectFile"
    case processing = "processing"
    case success = "success"
    case error = "error"
    case ok = "ok"
    case cancel = "cancel"
    
    // MARK: - 文件处理
    case noFileSelected = "noFileSelected"
    case conversionFailed = "conversionFailed"
    case fileNotSupported = "fileNotSupported"
    case notMotionPhoto = "notMotionPhoto"
    case export = "export"
    case livePhoto = "livePhoto"
    case gif = "gif"
    case selectMotionPhoto = "selectMotionPhoto"
    case noVideoData = "noVideoData"
    case processingVideoData = "processingVideoData"
    
    // MARK: - GIF 相关
    case creatingGIF = "creatingGIF"
    case gifSaved = "gifSaved"
    case savingGIFFailed = "savingGIFFailed"
    case gifSavedToPhotos = "gifSavedToPhotos"
    case failedToSaveGIF = "failedToSaveGIF"
    case failedToCreateGIF = "failedToCreateGIF"
    case cannotCreateGIFDestination = "cannotCreateGIFDestination"
    case cannotFinalizeGIFCreation = "cannotFinalizeGIFCreation"
    
    // MARK: - Live Photo 相关
    case livePhotoSaved = "livePhotoSaved"
    case savingLivePhotoFailed = "savingLivePhotoFailed"
    case createLivePhoto = "createLivePhoto"
    case customLivePhoto = "customLivePhoto"
    case customLivePhotoDescription = "customLivePhotoDescription"
    
    // MARK: - 主页面
    case homeTitle = "homeTitle"
    case homeDescription = "homeDescription"
    case pleaseSelectMotionPhoto = "pleaseSelectMotionPhoto"
    case selectedPhotoIsNotMotionPhoto = "selectedPhotoIsNotMotionPhoto"
    case tip = "tip"
    
    // MARK: - 错误信息
    case cannotReadFile = "cannotReadFile"
    case errorProcessingVideoFile = "errorProcessingVideoFile"
    case invalidMotionPhotoOrUnsupportedFormat = "invalidMotionPhotoOrUnsupportedFormat"
    case missingData = "missingData"
    case videoConversionFailed = "videoConversionFailed"
    case errorCreatingLivePhotoFile = "errorCreatingLivePhotoFile"
    case cannotCreateExportSession = "cannotCreateExportSession"
    case cannotCreateImageSource = "cannotCreateImageSource"
    case cannotCreateImageDestination = "cannotCreateImageDestination"
    case cannotGetImageProperties = "cannotGetImageProperties"
    case cannotCreateVideoExportSession = "cannotCreateVideoExportSession"
    case unknownError = "unknownError"
    case cannotGetVideoData = "cannotGetVideoData"
    case failedToProcessVideoData = "failedToProcessVideoData"
    case videoConversionFailedNoErrorInfo = "videoConversionFailedNoErrorInfo"
    case videoExportFailed = "videoExportFailed"
    case videoConversionCancelled = "videoConversionCancelled"
    case videoConversionUnknownStatus = "videoConversionUnknownStatus"
    case errorProcessingVideoMetadata = "errorProcessingVideoMetadata"
    
    // MARK: - 实验室功能
    case lab = "lab"
    case labTitle = "labTitle"
    case labDescription = "labDescription"
    
    // MARK: - 关于页面
    case about = "about"
    case aboutDescription = "aboutDescription"
    
    // MARK: - 媒体选择
    case selectImage = "selectImage"
    case selectVideo = "selectVideo"
    case changeImage = "changeImage"
    case changeVideo = "changeVideo"
    case videoSelected = "videoSelected"
    case video = "video"
    case videoSaved = "videoSaved"
    case savingVideoFailed = "savingVideoFailed"
    
    // MARK: - 视频处理错误
    case invalidVideoData = "invalidVideoData"
    case cannotCreateCompositionTrack = "cannotCreateCompositionTrack"
    case videoExportCancelled = "videoExportCancelled"
    case videoExportUnknownError = "videoExportUnknownError"
    case imageConversionFailed = "imageConversionFailed"
    case exportSessionCreationFailed = "exportSessionCreationFailed"
    case imageSourceCreationFailed = "imageSourceCreationFailed"
    case imageTypeUnavailable = "imageTypeUnavailable"
    case imageDestinationCreationFailed = "imageDestinationCreationFailed"
    case metadataWriteFailed = "metadataWriteFailed"
    case imagePropertiesUnavailable = "imagePropertiesUnavailable"
    
    // MARK: - 主要功能
    case mainFeatures = "mainFeatures"
    case exploreMoreFeatures = "exploreMoreFeatures"
    case convertToLivePhoto = "convertToLivePhoto"
    case convertToLivePhotoDescription = "convertToLivePhotoDescription"
    case extractVideo = "extractVideo"
    case extractVideoDescription = "extractVideoDescription"
    case generateGIF = "generateGIF"
    case generateGIFDescription = "generateGIFDescription"
    
    // MARK: - 权限相关
    case photoAccessDenied = "photoAccessDenied"
    case photoNotAccessibleInLimitedMode = "photoNotAccessibleInLimitedMode"
    case goToSettings = "goToSettings"
    case photoLibraryAccessPermission = "photoLibraryAccessPermission"
    
    // MARK: - 帮助页面
    case help = "help"
    case done = "done"
    case quickStart = "quickStart"
    case features = "features"
    case faq = "faq"
    case troubleshooting = "troubleshooting"
    case aboutMotion2Live = "aboutMotion2Live"
    case aboutMotion2LiveDescription = "aboutMotion2LiveDescription"
    case aboutApp = "aboutApp"
    case aboutAppDescription = "aboutAppDescription"
    
    // MARK: - 系统要求
    case systemRequirements = "systemRequirements"
    case systemRequirementsDescription = "systemRequirementsDescription"
    case systemRequirementsIOS = "systemRequirementsIOS"
    case systemRequirementsStorage = "systemRequirementsStorage"
    case systemRequirementsPermission = "systemRequirementsPermission"
    
    // MARK: - 支持的格式
    case supportedFormats = "supportedFormats"
    case supportedFormatsDescription = "supportedFormatsDescription"
    case supportedXiaomi = "supportedXiaomi"
    case supportedGoogle = "supportedGoogle"
    case supportedSamsung = "supportedSamsung"
    case supportedHuawei = "supportedHuawei"
    case supportedMotionPhotoFormats = "supportedMotionPhotoFormats"
    
    // MARK: - 使用步骤
    case usageSteps = "usageSteps"
    case usageStep1 = "usageStep1"
    case usageStep2 = "usageStep2"
    case usageStep3 = "usageStep3"
    case usageStep4 = "usageStep4"
    case usageStep5 = "usageStep5"
    case step1Title = "step1Title"
    case step1Description = "step1Description"
    case step2Title = "step2Title"
    case step2Description = "step2Description"
    case step3Title = "step3Title"
    case step3Description = "step3Description"
    case step4Title = "step4Title"
    case step4Description = "step4Description"
    
    // MARK: - 功能描述
    case basicFeatures = "basicFeatures"
    case basicFeaturesDescription = "basicFeaturesDescription"
    case labFeatures = "labFeatures"
    case labFeaturesDescription = "labFeaturesDescription"
    case labFeaturesCustomLivePhoto = "labFeaturesCustomLivePhoto"
    case convertToLivePhotoFeature = "convertToLivePhotoFeature"
    case convertToLivePhotoFeatureDescription = "convertToLivePhotoFeatureDescription"
    case extractVideoFeature = "extractVideoFeature"
    case extractVideoFeatureDescription = "extractVideoFeatureDescription"
    case generateGIFFeature = "generateGIFFeature"
    case generateGIFFeatureDescription = "generateGIFFeatureDescription"
    case labFeaturesBatchProcessing = "labFeaturesBatchProcessing"
    case labFeaturesAdvancedExport = "labFeaturesAdvancedExport"
    
    // MARK: - 多品牌支持功能
    case multiBrandSupport = "multiBrandSupport"
    case multiBrandSupportDescription = "multiBrandSupportDescription"
    case xiaomiSupport = "xiaomiSupport"
    case xiaomiSupportDescription = "xiaomiSupportDescription"
    case googlePixelSupport = "googlePixelSupport"
    case googlePixelSupportDescription = "googlePixelSupportDescription"
    case samsungSupport = "samsungSupport"
    case samsungSupportDescription = "samsungSupportDescription"
    case huaweiSupport = "huaweiSupport"
    case huaweiSupportDescription = "huaweiSupportDescription"
    case intelligentDetection = "intelligentDetection"
    case intelligentDetectionDescription = "intelligentDetectionDescription"
    
    // MARK: - 智能用户体验功能
    case smartUserExperience = "smartUserExperience"
    case smartUserExperienceDescription = "smartUserExperienceDescription"
    case firstTimeGuidance = "firstTimeGuidance"
    case firstTimeGuidanceDescription = "firstTimeGuidanceDescription"
    case intuitiveOperation = "intuitiveOperation"
    case intuitiveOperationDescription = "intuitiveOperationDescription"
    case statusMemory = "statusMemory"
    case statusMemoryDescription = "statusMemoryDescription"
    case streamlinedExperience = "streamlinedExperience"
    case streamlinedExperienceDescription = "streamlinedExperienceDescription"
    
    // MARK: - 视频处理功能
    case videoProcessing = "videoProcessing"
    case videoProcessingDescription = "videoProcessingDescription"
    case highQualityExtraction = "highQualityExtraction"
    case highQualityExtractionDescription = "highQualityExtractionDescription"
    case smartPlayback = "smartPlayback"
    case smartPlaybackDescription = "smartPlaybackDescription"
    case metadataPreservation = "metadataPreservation"
    case metadataPreservationDescription = "metadataPreservationDescription"
    
    // MARK: - Live Photo 转换功能
    case livePhotoConversion = "livePhotoConversion"
    case livePhotoConversionDescription = "livePhotoConversionDescription"
    case nativeCompatibility = "nativeCompatibility"
    case nativeCompatibilityDescription = "nativeCompatibilityDescription"
    case timeSynchronization = "timeSynchronization"
    case timeSynchronizationDescription = "timeSynchronizationDescription"
    case qualityOptimization = "qualityOptimization"
    case qualityOptimizationDescription = "qualityOptimizationDescription"
    
    // MARK: - GIF 导出功能
    case gifExport = "gifExport"
    case gifExportDescription = "gifExportDescription"
    case highQualityConversion = "highQualityConversion"
    case highQualityConversionDescription = "highQualityConversionDescription"
    case automaticOptimization = "automaticOptimization"
    case automaticOptimizationDescription = "automaticOptimizationDescription"
    case socialSharing = "socialSharing"
    case socialSharingDescription = "socialSharingDescription"
    
    // MARK: - 现代化界面功能
    case modernInterface = "modernInterface"
    case modernInterfaceDescription = "modernInterfaceDescription"
    case swiftUIDesign = "swiftUIDesign"
    case swiftUIDesignDescription = "swiftUIDesignDescription"
    case darkModeSupport = "darkModeSupport"
    case darkModeSupportDescription = "darkModeSupportDescription"
    case animationEffects = "animationEffects"
    case animationEffectsDescription = "animationEffectsDescription"
    case helpSystem = "helpSystem"
    case helpSystemDescription = "helpSystemDescription"
    
    // MARK: - 文件格式说明
    case fileFormatDescription = "fileFormatDescription"
    case fileFormatDescriptionText = "fileFormatDescriptionText"
    case motionPhotoVsLivePhoto = "motionPhotoVsLivePhoto"
    case motionPhotoDescription = "motionPhotoDescription"
    case livePhotoDescription = "livePhotoDescription"
    case identificationAndSelection = "identificationAndSelection"
    case identificationAndSelectionText = "identificationAndSelectionText"
    case conversionAndExport = "conversionAndExport"
    case conversionAndExportText = "conversionAndExportText"
    
    // MARK: - 常见问题
    case faqWhatIsMotionPhoto = "faqWhatIsMotionPhoto"
    case faqWhatIsMotionPhotoAnswer = "faqWhatIsMotionPhotoAnswer"
    case faqMotionPhotoAnswer = "faqMotionPhotoAnswer"
    case faqWhatIsLivePhoto = "faqWhatIsLivePhoto"
    case faqWhatIsLivePhotoAnswer = "faqWhatIsLivePhotoAnswer"
    case faqAppMainFunction = "faqAppMainFunction"
    case faqAppMainFunctionAnswer = "faqAppMainFunctionAnswer"
    case faqGIFFileSize = "faqGIFFileSize"
    case faqGIFFileSizeAnswer = "faqGIFFileSizeAnswer"
    case faqFileSaveLocation = "faqFileSaveLocation"
    case faqFileSaveLocationAnswer = "faqFileSaveLocationAnswer"
    case faqExportFailureReasons = "faqExportFailureReasons"
    case faqExportFailureReasonsAnswer = "faqExportFailureReasonsAnswer"
    case faqLivePhotoCompatibility = "faqLivePhotoCompatibility"
    case faqLivePhotoCompatibilityAnswer = "faqLivePhotoCompatibilityAnswer"
    case faqVideoNoSound = "faqVideoNoSound"
    case faqVideoNoSoundAnswer = "faqVideoNoSoundAnswer"
    case faqDifferenceLivePhoto = "faqDifferenceLivePhoto"
    case faqDifferenceAnswer = "faqDifferenceAnswer"
    case faqSupportedFormats = "faqSupportedFormats"
    case faqSupportedFormatsAnswer = "faqSupportedFormatsAnswer"
    case faqMainFunctions = "faqMainFunctions"
    case faqMainFunctionsAnswer = "faqMainFunctionsAnswer"
    case faqHowToSelectMotionPhoto = "faqHowToSelectMotionPhoto"
    case faqHowToSelectMotionPhotoAnswer = "faqHowToSelectMotionPhotoAnswer"
    case faqHowToKnowMotionPhoto = "faqHowToKnowMotionPhoto"
    case faqHowToKnowMotionPhotoAnswer = "faqHowToKnowMotionPhotoAnswer"
    case faqHowToConvertToLivePhoto = "faqHowToConvertToLivePhoto"
    case faqHowToConvertToLivePhotoAnswer = "faqHowToConvertToLivePhotoAnswer"
    case faqHowToConvertToGIF = "faqHowToConvertToGIF"
    case faqHowToConvertToGIFAnswer = "faqHowToConvertToGIFAnswer"
    case faqSupportedDevices = "faqSupportedDevices"
    case faqSupportedDevicesAnswer = "faqSupportedDevicesAnswer"
    case faqExportedLivePhotoQuality = "faqExportedLivePhotoQuality"
    case faqExportedLivePhotoQualityAnswer = "faqExportedLivePhotoQualityAnswer"
    case faqGIFFileSizeControl = "faqGIFFileSizeControl"
    case faqGIFFileSizeControlAnswer = "faqGIFFileSizeControlAnswer"
    case faqBatchProcessing = "faqBatchProcessing"
    case faqBatchProcessingAnswer = "faqBatchProcessingAnswer"
    case faqWhereAreFilesSaved = "faqWhereAreFilesSaved"
    case faqWhereAreFilesSavedAnswer = "faqWhereAreFilesSavedAnswer"
    case faqWhyExportFailed = "faqWhyExportFailed"
    case faqWhyExportFailedAnswer = "faqWhyExportFailedAnswer"
    case faqWhyLivePhotoNotWorking = "faqWhyLivePhotoNotWorking"
    case faqWhyLivePhotoNotWorkingAnswer = "faqWhyLivePhotoNotWorkingAnswer"
    case faqWhyNoSoundInVideo = "faqWhyNoSoundInVideo"
    case faqWhyNoSoundInVideoAnswer = "faqWhyNoSoundInVideoAnswer"
    
    // MARK: - 兼容性
    case compatibility = "compatibility"
    case compatibilityText = "compatibilityText"
    
    // MARK: - 性能问题
    case performanceIssues = "performanceIssues"
    case performanceIssuesText = "performanceIssuesText"
    
    // MARK: - 故障排除
    case troubleshootingInvalidMotionPhoto = "troubleshootingInvalidMotionPhoto"
    case troubleshootingInvalidMotionPhotoSolution = "troubleshootingInvalidMotionPhotoSolution"
    case troubleshootingPhotoLibraryAccess = "troubleshootingPhotoLibraryAccess"
    case troubleshootingPhotoLibraryAccessSolution = "troubleshootingPhotoLibraryAccessSolution"
    case troubleshootingNotValidMotionPhoto = "troubleshootingNotValidMotionPhoto"
    case troubleshootingNotValidMotionPhotoAnswer = "troubleshootingNotValidMotionPhotoAnswer"
    case troubleshootingCannotAccessPhotos = "troubleshootingCannotAccessPhotos"
    case troubleshootingCannotAccessPhotosAnswer = "troubleshootingCannotAccessPhotosAnswer"
    case troubleshootingNotRecognized = "troubleshootingNotRecognized"
    case troubleshootingExportFailed = "troubleshootingExportFailed"
    case troubleshootingSlowProcessing = "troubleshootingSlowProcessing"
    case troubleshootingLivePhotoCompatibility = "troubleshootingLivePhotoCompatibility"
    
    // MARK: - 功能请求和反馈
    case featureRequestsAndFeedback = "featureRequestsAndFeedback"
    case newFeaturePlans = "newFeaturePlans"
    case newFeaturePlansAnswer = "newFeaturePlansAnswer"
    case howToReportBugs = "howToReportBugs"
    case howToReportBugsAnswer = "howToReportBugsAnswer"
    case contactInformation = "contactInformation"
    case contactInformationAnswer = "contactInformationAnswer"
    case featureRequests = "featureRequests"
    case featureRequestsAnswer = "featureRequestsAnswer"
    case canRequestNewFeatures = "canRequestNewFeatures"
    case canRequestNewFeaturesAnswer = "canRequestNewFeaturesAnswer"
    case plannedNewFeatures = "plannedNewFeatures"
    case plannedNewFeaturesAnswer = "plannedNewFeaturesAnswer"
    case howToReportBug = "howToReportBug"
    case howToReportBugAnswer = "howToReportBugAnswer"
    case contactUs = "contactUs"
    case contactUsAnswer = "contactUsAnswer"
    
    // MARK: - 导出选项页面
    case exportOptions = "exportOptions"
    case fileInformation = "fileInformation"
    case fileName = "fileName"
    case fileSize = "fileSize"
    case creationDate = "creationDate"
    case videoDuration = "videoDuration"
    case chooseExportFormat = "chooseExportFormat"
    case saveAsVideo = "saveAsVideo"
    case saveAsVideoDescription = "saveAsVideoDescription"
    case saveAsLivePhoto = "saveAsLivePhoto"
    case saveAsLivePhotoDescription = "saveAsLivePhotoDescription"
    case saveAsGIF = "saveAsGIF"
    case saveAsGIFDescription = "saveAsGIFDescription"
    
    // MARK: - 权限问题
    case permissionIssues = "permissionIssues"
    case permissionIssuesDescription = "permissionIssuesDescription"
    case permissionIssuesStep1 = "permissionIssuesStep1"
    case permissionIssuesStep2 = "permissionIssuesStep2"
    case permissionIssuesStep3 = "permissionIssuesStep3"
    case permissionIssuesText = "permissionIssuesText"
    
    // MARK: - 导出失败
    case exportFailure = "exportFailure"
    case exportFailureSolutions = "exportFailureSolutions"
    case exportFailureCheckStorage = "exportFailureCheckStorage"
    case exportFailureCloseApps = "exportFailureCloseApps"
    case exportFailureRestartApp = "exportFailureRestartApp"
    case exportFailureTrySmaller = "exportFailureTrySmaller"
    case exportFailureText = "exportFailureText"
    
    // MARK: - 性能优化
    case performanceOptimization = "performanceOptimization"
    case performanceOptimizationSuggestions = "performanceOptimizationSuggestions"
    case performanceCloseApps = "performanceCloseApps"
    case performanceEnsureStorage = "performanceEnsureStorage"
    case performanceProcessOnPower = "performanceProcessOnPower"
    case performanceAvoidLowBattery = "performanceAvoidLowBattery"
    case performanceOptimizationText = "performanceOptimizationText"
    
    // MARK: - 应用崩溃
    case appCrash = "appCrash"
    case appCrashes = "appCrashes"
    case appCrashesDescription = "appCrashesDescription"
    case appCrashesRestart = "appCrashesRestart"
    case appCrashesTrySmaller = "appCrashesTrySmaller"
    case appCrashesUpdate = "appCrashesUpdate"
    case appCrashesContact = "appCrashesContact"
    case appCrashText = "appCrashText"
    
    // MARK: - 联系支持
    case contactSupport = "contactSupport"
    case contactSupportDescription = "contactSupportDescription"
    case developerEmail = "developerEmail"
    case githubProject = "githubProject"
    case appVersion = "appVersion"
    
    // MARK: - 预览页面
    case preview = "preview"
    case back = "back"
}

// MARK: - 便利扩展
extension String {
    /// 使用本地化键初始化字符串
    init(localized key: LocalizableKey) {
        self = LocalizationManager.localizedString(for: key)
    }
}

// MARK: - 全局便利函数
/// 获取本地化字符串的便利函数
/// - Parameter key: 本地化键
/// - Returns: 本地化后的字符串
func L(_ key: LocalizableKey) -> String {
    return LocalizationManager.localizedString(for: key)
}