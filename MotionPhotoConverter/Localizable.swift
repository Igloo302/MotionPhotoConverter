import Foundation

enum Language: String {
    case english = "en"
    case chinese = "zh"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case japanese = "ja"
    case korean = "ko"
    
    static var current: Language {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))
        return Language(rawValue: languageCode) ?? .english
    }
}

struct Localizable {
    static func string(_ key: LocalizableKey) -> String {
        switch Language.current {
        case .english:
            return key.english
        case .chinese:
            return key.chinese
        case .french:
            return key.french
        case .german:
            return key.german
        case .spanish:
            return key.spanish
        case .japanese:
            return key.japanese
        case .korean:
            return key.korean
        }
    }
}

enum LocalizableKey {
    case switchLanguage
    case appTitle
    case convert
    case selectFile
    case processing
    case success
    case error
    case ok
    case cancel
    case noFileSelected
    case conversionFailed
    case fileNotSupported
    case notMotionPhoto
    case export
    case livePhoto
    case gif
    case selectMotionPhoto
    case noVideoData
    case processingVideoData
    case creatingGIF
    case gifSaved
    case savingGIFFailed
    case livePhotoSaved
    case savingLivePhotoFailed
    case homeTitle
    case homeDescription
    case pleaseSelectMotionPhoto
    case selectedPhotoIsNotMotionPhoto
    case tip
    case cannotReadFile
    case errorProcessingVideoFile
    case invalidMotionPhotoOrUnsupportedFormat
    case missingData
    case videoConversionFailed
    case errorCreatingLivePhotoFile
    case cannotCreateExportSession
    case cannotCreateImageSource
    case cannotCreateImageDestination
    case cannotGetImageProperties
    case cannotCreateVideoExportSession
    case unknownError
    case cannotGetVideoData
    case failedToCreateGIF
    case failedToProcessVideoData
    case videoConversionFailedNoErrorInfo
    case videoExportFailed
    case cannotCreateGIFDestination
    case cannotFinalizeGIFCreation
    case gifSavedToPhotos
    case failedToSaveGIF
    case videoConversionCancelled
    case videoConversionUnknownStatus
    case errorProcessingVideoMetadata
    case lab
    case about
    case aboutDescription
    case labTitle
    case labDescription
    case customLivePhoto
    case customLivePhotoDescription
    case selectImage
    case selectVideo
    case createLivePhoto
    case changeImage
    case changeVideo
    case videoSelected
    case video
    case videoSaved
    case savingVideoFailed
    case invalidVideoData
    case cannotCreateCompositionTrack
    case videoExportCancelled
    case videoExportUnknownError
    case imageConversionFailed
    case exportSessionCreationFailed
    case imageSourceCreationFailed
    case imageTypeUnavailable
    case imageDestinationCreationFailed
    case metadataWriteFailed
    case imagePropertiesUnavailable
    
    var english: String {
        switch self {
        case .switchLanguage: return "Switch to Chinese"
        case .appTitle: return "Motion Photo Converter"
        case .convert: return "Convert"
        case .selectFile: return "Select File"
        case .processing: return "Processing..."
        case .success: return "Conversion Successful"
        case .error: return "Error"
        case .ok: return "OK"
        case .cancel: return "Cancel"
        case .noFileSelected: return "No file selected"
        case .conversionFailed: return "Conversion failed"
        case .fileNotSupported: return "File not supported"
        case .notMotionPhoto: return "Selected photo is not a Motion Photo"
        case .export: return "Export"
        case .livePhoto: return "Live Photo"
        case .gif: return "GIF"
        case .selectMotionPhoto: return "Select Motion Photo"
        case .noVideoData: return "Unable to get video data"
        case .processingVideoData: return "Processing video data failed"
        case .creatingGIF: return "Creating GIF..."
        case .gifSaved: return "GIF has been successfully saved to the album"
        case .savingGIFFailed: return "Failed to save GIF"
        case .livePhotoSaved: return "Live Photo has been successfully saved to the album"
        case .savingLivePhotoFailed: return "Failed to save Live Photo"
        case .homeTitle: return "Motion Photo Converter"
        case .homeDescription: return "Transform your Motion Photos into Live Photos or GIFs with ease. Capture the magic of movement and share your memories in dynamic formats."
        case .pleaseSelectMotionPhoto: return "Please select a Motion Photo"
        case .selectedPhotoIsNotMotionPhoto: return "The selected photo is not a Motion Photo"
        case .tip: return "Tip"
        case .cannotReadFile: return "Cannot read file"
        case .errorProcessingVideoFile: return "Error processing video file"
        case .invalidMotionPhotoOrUnsupportedFormat: return "Invalid Motion Photo or unsupported format"
        case .missingData: return "Missing data"
        case .videoConversionFailed: return "Video conversion failed"
        case .errorCreatingLivePhotoFile: return "Error creating Live Photo file"
        case .cannotCreateExportSession: return "Cannot create export session"
        case .cannotCreateImageSource: return "Cannot create image source"
        case .cannotCreateImageDestination: return "Cannot create image destination"
        case .cannotGetImageProperties: return "Cannot get image properties"
        case .cannotCreateVideoExportSession: return "Cannot create video export session"
        case .unknownError: return "Unknown error"
        case .cannotGetVideoData: return "Cannot get video data"
        case .failedToCreateGIF: return "Failed to create GIF"
        case .failedToProcessVideoData: return "Failed to process video data"
        case .videoConversionFailedNoErrorInfo: return "Video conversion failed without error information"
        case .videoExportFailed: return "Video export failed"
        case .cannotCreateGIFDestination: return "Cannot create GIF destination"
        case .cannotFinalizeGIFCreation: return "Cannot finalize GIF creation"
        case .gifSavedToPhotos: return "GIF saved to photos"
        case .failedToSaveGIF: return "Failed to save GIF"
        case .videoConversionCancelled: return "Video conversion cancelled"
        case .videoConversionUnknownStatus: return "Video conversion status unknown"
        case .errorProcessingVideoMetadata: return "Error processing video metadata"
        case .lab: return "Lab"
        case .about: return "About"
        case .aboutDescription: return "Motion Photo Converter\nVersion 1.1\n© 2024 Igloo. All rights reserved."
        case .labTitle: return "Experimental Lab"
        case .labDescription: return "This is an experimental area for future features. Stay tuned!"
        case .customLivePhoto: return "Custom Live Photo"
        case .customLivePhotoDescription: return "Create a custom Live Photo by selecting a still image and a video."
        case .selectImage: return "Select Image"
        case .selectVideo: return "Select Video"
        case .createLivePhoto: return "Create Live Photo"
        case .changeImage: return "Change Image"
        case .changeVideo: return "Change Video"
        case .videoSelected: return "Video Selected"
        case .video: return "Video"
        case .videoSaved: return "Video has been successfully saved to the album"
        case .savingVideoFailed: return "Failed to save video"
        case .invalidVideoData: return "Invalid video data"
        case .cannotCreateCompositionTrack: return "Cannot create composition track"
        case .videoExportCancelled: return "Video export was cancelled"
        case .videoExportUnknownError: return "Unknown error during video export"
        case .imageConversionFailed: return "Failed to convert image"
        case .exportSessionCreationFailed: return "Failed to create export session"
        case .imageSourceCreationFailed: return "Failed to create image source"
        case .imageTypeUnavailable: return "Image type is unavailable"
        case .imageDestinationCreationFailed: return "Failed to create image destination"
        case .metadataWriteFailed: return "Failed to write metadata"
        case .imagePropertiesUnavailable: return "Image properties are unavailable"
        }
    }
    
    var chinese: String {
        switch self {
        case .switchLanguage: return "切换到英文"
        case .appTitle: return "动态照片转换器"
        case .convert: return "转换"
        case .selectFile: return "选择文件"
        case .processing: return "处中..."
        case .success: return "转换成功"
        case .error: return "错误"
        case .ok: return "确定"
        case .cancel: return "取消"
        case .noFileSelected: return "未选择文件"
        case .conversionFailed: return "转换失败"
        case .fileNotSupported: return "不支持的文件格式"
        case .notMotionPhoto: return "所选照片不是动态照片"
        case .export: return "导出"
        case .livePhoto: return "实况照片"
        case .gif: return "GIF"
        case .selectMotionPhoto: return "选择动态照片"
        case .noVideoData: return "无法获取视频数据"
        case .processingVideoData: return "处理视频数据失败"
        case .creatingGIF: return "正在创建 GIF..."
        case .gifSaved: return "GIF 已成功保存到相册"
        case .savingGIFFailed: return "保存 GIF 失败"
        case .livePhotoSaved: return "实况照片已成功保存到相册"
        case .savingLivePhotoFailed: return "保存况照片失败"
        case .homeTitle: return "动态照片转换器"
        case .homeDescription: return "轻松将您的动态照片转换为实况照片或 GIF。捕捉动态的魅力,以动态格式分享您的回忆。"
        case .pleaseSelectMotionPhoto: return "请选择一张动态照片"
        case .selectedPhotoIsNotMotionPhoto: return "所选照片不是动态照片"
        case .tip: return "提示"
        case .cannotReadFile: return "无法读取文件"
        case .errorProcessingVideoFile: return "处理视频文件时出错"
        case .invalidMotionPhotoOrUnsupportedFormat: return "无效的动态照片或不支持的格式"
        case .missingData: return "缺少数据"
        case .videoConversionFailed: return "视频转换失败"
        case .errorCreatingLivePhotoFile: return "创建实况照片文件时出错"
        case .cannotCreateExportSession: return "无法创建导出会话"
        case .cannotCreateImageSource: return "无法创建图像源"
        case .cannotCreateImageDestination: return "无法创建图像目标"
        case .cannotGetImageProperties: return "无法获取图像属性"
        case .cannotCreateVideoExportSession: return "无法创建视频导出会话"
        case .unknownError: return "未知错误"
        case .cannotGetVideoData: return "无法获取视频数据"
        case .failedToCreateGIF: return "创建 GIF 失败"
        case .failedToProcessVideoData: return "处理视频数据失败"
        case .videoConversionFailedNoErrorInfo: return "视频转换失败，无错误信息"
        case .videoExportFailed: return "视频导出失败"
        case .cannotCreateGIFDestination: return "无法 GIF 目标"
        case .cannotFinalizeGIFCreation: return "无法完成 GIF 创建"
        case .gifSavedToPhotos: return "GIF 已保存到照片"
        case .failedToSaveGIF: return "保存 GIF 失败"
        case .videoConversionCancelled: return "视频转换已取消"
        case .videoConversionUnknownStatus: return "视频转换状态未知"
        case .errorProcessingVideoMetadata: return "处理视频元数据时出错"
        case .lab: return "实验室"
        case .about: return "关于"
        case .aboutDescription: return "动态照片转换器\n版本 1.1\n© 2024 Igloo。保留所有权利。"
        case .labTitle: return "实验室"
        case .labDescription: return "这是未来功能的实验区域。敬请期待！"
        case .customLivePhoto: return "自定义实况照片"
        case .customLivePhotoDescription: return "通过选择静态图像和视频来创建自定义实况照片。"
        case .selectImage: return "选择图片"
        case .selectVideo: return "选择视频"
        case .createLivePhoto: return "创建实况照片"
        case .changeImage: return "更改图片"
        case .changeVideo: return "更改视频"
        case .videoSelected: return "已选择视频"
        case .video: return "视频"
        case .videoSaved: return "视频已成功保存到相册"
        case .savingVideoFailed: return "保存视频失败"
        case .invalidVideoData: return "无效的视频数据"
        case .cannotCreateCompositionTrack: return "无法创建合成轨道"
        case .cannotCreateExportSession: return "无法创建导出会话"
        case .videoExportFailed: return "视频导出失败"
        case .videoExportCancelled: return "视频导出已取消"
        case .videoExportUnknownError: return "视频导出时发生未知错误"
        case .imageConversionFailed: return "图像转换失败"
        case .exportSessionCreationFailed: return "创建导出会话失败"
        case .imageSourceCreationFailed: return "创建图像源失败"
        case .imageTypeUnavailable: return "图像类型不可用"
        case .imageDestinationCreationFailed: return "创建图像目标失败"
        case .metadataWriteFailed: return "写入元数据失败"
        case .imagePropertiesUnavailable: return "图像属性不可用"
        }
    }
    
    var french: String {
        switch self {
        case .switchLanguage: return "Passer à l'anglais"
        case .appTitle: return "Convertisseur de Photos en Mouvement"
        case .convert: return "Convertir"
        case .selectFile: return "Sélectionner un fichier"
        case .processing: return "Traitement en cours..."
        case .success: return "Conversion réussie"
        case .error: return "Erreur"
        case .ok: return "OK"
        case .cancel: return "Annuler"
        case .noFileSelected: return "Aucun fichier sélectionné"
        case .conversionFailed: return "La conversion a échoué"
        case .fileNotSupported: return "Format de fichier non pris en charge"
        case .notMotionPhoto: return "La photo sélectionnée n'est pas une Photo en Mouvement"
        case .export: return "Exporter"
        case .livePhoto: return "Photo Live"
        case .gif: return "GIF"
        case .selectMotionPhoto: return "Sélectionner une Photo en Mouvement"
        case .noVideoData: return "Impossible d'obtenir les données vidéo"
        case .processingVideoData: return "Le traitement des données vidéo a échoué"
        case .creatingGIF: return "Création du GIF..."
        case .gifSaved: return "Le GIF a été enregistré avec succès dans l'album"
        case .savingGIFFailed: return "Échec de l'enregistrement du GIF"
        case .livePhotoSaved: return "La Photo Live a été enregistrée avec succès dans l'album"
        case .savingLivePhotoFailed: return "Échec de l'enregistrement de la Photo Live"
        case .homeTitle: return "Convertisseur de Photos en Mouvement"
        case .homeDescription: return "Transformez facilement vos Photos en Mouvement en Photos Live ou en GIF. Capturez la magie du mouvement et partagez vos souvenirs dans des formats dynamiques."
        case .pleaseSelectMotionPhoto: return "Veuillez sélectionner une Photo en Mouvement"
        case .selectedPhotoIsNotMotionPhoto: return "La photo sélectionnée n'est pas une Photo en Mouvement"
        case .tip: return "Conseil"
        case .cannotReadFile: return "Impossible de lire le fichier"
        case .errorProcessingVideoFile: return "Erreur lors du traitement du fichier vidéo"
        case .invalidMotionPhotoOrUnsupportedFormat: return "Photo en Mouvement invalide ou format non pris en charge"
        case .missingData: return "Données manquantes"
        case .videoConversionFailed: return "La conversion vidéo a échoué"
        case .errorCreatingLivePhotoFile: return "Erreur lors de la création du fichier Photo Live"
        case .cannotCreateExportSession: return "Impossible de créer une session d'exportation"
        case .cannotCreateImageSource: return "Impossible de créer une source d'image"
        case .cannotCreateImageDestination: return "Impossible de créer une destination d'image"
        case .cannotGetImageProperties: return "Impossible d'obtenir les propriétés de l'image"
        case .cannotCreateVideoExportSession: return "Impossible de créer une session d'exportation vidéo"
        case .unknownError: return "Erreur inconnue"
        case .cannotGetVideoData: return "Impossible d'obtenir les données vidéo"
        case .failedToCreateGIF: return "Échec de la création du GIF"
        case .failedToProcessVideoData: return "Échec du traitement des données vidéo"
        case .videoConversionFailedNoErrorInfo: return "La conversion vidéo a échoué sans information d'erreur"
        case .videoExportFailed: return "L'exportation vidéo a échoué"
        case .cannotCreateGIFDestination: return "Impossible de créer une destination GIF"
        case .cannotFinalizeGIFCreation: return "Impossible de finaliser la création du GIF"
        case .gifSavedToPhotos: return "Le GIF a été enregistré dans les photos"
        case .failedToSaveGIF: return "Échec de l'enregistrement du GIF"
        case .videoConversionCancelled: return "Conversion vidéo annulée"
        case .videoConversionUnknownStatus: return "Statut de conversion vidéo inconnu"
        case .errorProcessingVideoMetadata: return "Erreur lors du traitement des métadonnées vidéo"
        case .lab: return "Laboratoire"
        case .about: return "À propos"
        case .aboutDescription: return "Convertisseur de Photos en Mouvement\nVersion 1.1\n© 2024 Igloo. Tous droits réservés."
        case .labTitle: return "Laboratoire expérimental"
        case .labDescription: return "C'est une zone expérimentale pour les fonctionnalités futures. À suivre !"
        case .customLivePhoto: return "Photo Live personnalisée"
        case .customLivePhotoDescription: return "Créez une Photo Live personnalisée en sélectionnant une image fixe et une vidéo."
        case .selectImage: return "Sélectionner une image"
        case .selectVideo: return "Sélectionner une vidéo"
        case .createLivePhoto: return "Créer une Photo Live"
        case .changeImage: return "Changer l'image"
        case .changeVideo: return "Changer la vidéo"
        case .videoSelected: return "Vidéo sélectionnée"
        case .video: return "Vidéo"
        case .videoSaved: return "La vidéo a été enregistrée avec succès dans l'album"
        case .savingVideoFailed: return "Échec de l'enregistrement de la vidéo"
        case .invalidVideoData: return "Données vidéo invalides"
        case .cannotCreateCompositionTrack: return "Impossible de créer une piste de composition"
        case .cannotCreateExportSession: return "Impossible de créer une session d'exportation"
        case .videoExportFailed: return "L'exportation vidéo a échoué"
        case .videoExportCancelled: return "L'exportation vidéo a été annulée"
        case .videoExportUnknownError: return "Erreur inconnue lors de l'exportation vidéo"
        case .imageConversionFailed: return "Échec de la conversion de l'image"
        case .exportSessionCreationFailed: return "Échec de la création de la session d'exportation"
        case .imageSourceCreationFailed: return "Échec de la création de la source d'image"
        case .imageTypeUnavailable: return "Le type d'image n'est pas disponible"
        case .imageDestinationCreationFailed: return "Échec de la création de la destination d'image"
        case .metadataWriteFailed: return "Échec de l'écriture des métadonnées"
        case .imagePropertiesUnavailable: return "Les propriétés de l'image ne sont pas disponibles"
        }
    }
    
    var german: String {
        switch self {
        case .switchLanguage: return "Zu Englisch wechseln"
        case .appTitle: return "Bewegungsfoto-Konverter"
        case .convert: return "Konvertieren"
        case .selectFile: return "Datei auswählen"
        case .processing: return "Verarbeitung..."
        case .success: return "Konvertierung erfolgreich"
        case .error: return "Fehler"
        case .ok: return "OK"
        case .cancel: return "Abbrechen"
        case .noFileSelected: return "Keine Datei ausgewählt"
        case .conversionFailed: return "Konvertierung fehlgeschlagen"
        case .fileNotSupported: return "Dateiformat nicht unterstützt"
        case .notMotionPhoto: return "Ausgewähltes Foto ist kein Bewegungsfoto"
        case .export: return "Exportieren"
        case .livePhoto: return "Live-Foto"
        case .gif: return "GIF"
        case .selectMotionPhoto: return "Bewegungsfoto auswählen"
        case .noVideoData: return "Videodaten konnten nicht abgerufen werden"
        case .processingVideoData: return "Verarbeitung der Videodaten fehlgeschlagen"
        case .creatingGIF: return "GIF wird erstellt..."
        case .gifSaved: return "GIF wurde erfolgreich im Album gespeichert"
        case .savingGIFFailed: return "Speichern des GIFs fehlgeschlagen"
        case .livePhotoSaved: return "Live-Foto wurde erfolgreich im Album gespeichert"
        case .savingLivePhotoFailed: return "Speichern des Live-Fotos fehlgeschlagen"
        case .homeTitle: return "Bewegungsfoto-Konverter"
        case .homeDescription: return "Verwandeln Sie Ihre Bewegungsfotos mühelos in Live-Fotos oder GIFs. Fangen Sie den Zauber der Bewegung ein und teilen Sie Ihre Erinnerungen in dynamischen Formaten."
        case .pleaseSelectMotionPhoto: return "Bitte wählen Sie ein Bewegungsfoto aus"
        case .selectedPhotoIsNotMotionPhoto: return "Das ausgewählte Foto ist kein Bewegungsfoto"
        case .tip: return "Tipp"
        case .cannotReadFile: return "Datei kann nicht gelesen werden"
        case .errorProcessingVideoFile: return "Fehler beim Verarbeiten der Videodatei"
        case .invalidMotionPhotoOrUnsupportedFormat: return "Ungültiges Bewegungsfoto oder nicht unterstütztes Format"
        case .missingData: return "Fehlende Daten"
        case .videoConversionFailed: return "Videokonvertierung fehlgeschlagen"
        case .errorCreatingLivePhotoFile: return "Fehler beim Erstellen der Live-Fotodatei"
        case .cannotCreateExportSession: return "Export-Sitzung kann nicht erstellt werden"
        case .cannotCreateImageSource: return "Bildquelle kann nicht erstellt werden"
        case .cannotCreateImageDestination: return "Bildziel kann nicht erstellt werden"
        case .cannotGetImageProperties: return "Bildeigenschaften können nicht abgerufen werden"
        case .cannotCreateVideoExportSession: return "Videoexport-Sitzung kann nicht erstellt werden"
        case .unknownError: return "Unbekannter Fehler"
        case .cannotGetVideoData: return "Videodaten können nicht abgerufen werden"
        case .failedToCreateGIF: return "GIF-Erstellung fehlgeschlagen"
        case .failedToProcessVideoData: return "Verarbeitung der Videodaten fehlgeschlagen"
        case .videoConversionFailedNoErrorInfo: return "Videokonvertierung fehlgeschlagen, keine Fehlerinformationen"
        case .videoExportFailed: return "Videoexport fehlgeschlagen"
        case .cannotCreateGIFDestination: return "GIF-Ziel kann nicht erstellt werden"
        case .cannotFinalizeGIFCreation: return "GIF-Erstellung kann nicht abgeschlossen werden"
        case .gifSavedToPhotos: return "GIF in Fotos gespeichert"
        case .failedToSaveGIF: return "Speichern des GIFs fehlgeschlagen"
        case .videoConversionCancelled: return "Videokonvertierung abgebrochen"
        case .videoConversionUnknownStatus: return "Videokonvertierungsstatus unbekannt"
        case .errorProcessingVideoMetadata: return "Fehler bei der Verarbeitung der Video-Metadaten"
        case .lab: return "Labor"
        case .about: return "Info"
        case .aboutDescription: return "Bewegungsfoto-Konverter\nVersion 1.1\n© 2024 Igloo. Alle Rechte vorbehalten."
        case .labTitle: return "Experimentelles Labor"
        case .labDescription: return "Dies ist ein experimenteller Bereich für zukünftige Funktionen. Bleiben Sie dran!"
        case .customLivePhoto: return "Benutzerdefiniertes Live-Foto"
        case .customLivePhotoDescription: return "Erstellen Sie ein benutzerdefiniertes Live-Foto, indem Sie ein stilles Bild und eine Videoaufnahme auswählen."
        case .selectImage: return "Bild auswählen"
        case .selectVideo: return "Video auswählen"
        case .createLivePhoto: return "Live-Foto erstellen"
        case .changeImage: return "Bild ändern"
        case .changeVideo: return "Video ändern"
        case .videoSelected: return "Video ausgewählt"
        case .video: return "Video"
        case .videoSaved: return "Video wurde erfolgreich im Album gespeichert"
        case .savingVideoFailed: return "Speichern des Videos fehlgeschlagen"
        case .invalidVideoData: return "Ungültige Videodaten"
        case .cannotCreateCompositionTrack: return "Kann keine Kompositionsspur erstellen"
        case .cannotCreateExportSession: return "Kann keine Exportsitzung erstellen"
        case .videoExportFailed: return "Videoexport fehlgeschlagen"
        case .videoExportCancelled: return "Videoexport abgebrochen"
        case .videoExportUnknownError: return "Unbekannter Fehler beim Videoexport"
        case .imageConversionFailed: return "Bildkonvertierung fehlgeschlagen"
        case .exportSessionCreationFailed: return "Erstellung der Exportsitzung fehlgeschlagen"
        case .imageSourceCreationFailed: return "Erstellung der Bildquelle fehlgeschlagen"
        case .imageTypeUnavailable: return "Bildtyp nicht verfügbar"
        case .imageDestinationCreationFailed: return "Erstellung des Bildziels fehlgeschlagen"
        case .metadataWriteFailed: return "Schreiben der Metadaten fehlgeschlagen"
        case .imagePropertiesUnavailable: return "Bildeigenschaften nicht verfügbar"
        }
    }
    
    var spanish: String {
        switch self {
        case .switchLanguage: return "Cambiar a inglés"
        case .appTitle: return "Conversor de Fotos en Movimiento"
        case .convert: return "Convertir"
        case .selectFile: return "Seleccionar archivo"
        case .processing: return "Procesando..."
        case .success: return "Conversión exitosa"
        case .error: return "Error"
        case .ok: return "Aceptar"
        case .cancel: return "Cancelar"
        case .noFileSelected: return "Ningún archivo seleccionado"
        case .conversionFailed: return "La conversión falló"
        case .fileNotSupported: return "Formato de archivo no compatible"
        case .notMotionPhoto: return "La foto seleccionada no es una Foto en Movimiento"
        case .export: return "Exportar"
        case .livePhoto: return "Foto en vivo"
        case .gif: return "GIF"
        case .selectMotionPhoto: return "Seleccionar Foto en Movimiento"
        case .noVideoData: return "No se pueden obtener los datos de video"
        case .processingVideoData: return "Falló el procesamiento de los datos de video"
        case .creatingGIF: return "Creando GIF..."
        case .gifSaved: return "El GIF se ha guardado con éxito en el álbum"
        case .savingGIFFailed: return "Error al guardar el GIF"
        case .livePhotoSaved: return "La Foto en vivo se ha guardado con éxito en el álbum"
        case .savingLivePhotoFailed: return "Error al guardar la Foto en vivo"
        case .homeTitle: return "Conversor de Fotos en Movimiento"
        case .homeDescription: return "Transforma fácilmente tus Fotos en Movimiento en Fotos en vivo o GIFs. Captura la magia del movimiento y comparte tus recuerdos en formatos dinámicos."
        case .pleaseSelectMotionPhoto: return "Por favor, seleccione una Foto en Movimiento"
        case .selectedPhotoIsNotMotionPhoto: return "La foto seleccionada no es una Foto en Movimiento"
        case .tip: return "Consejo"
        case .cannotReadFile: return "No se puede leer el archivo"
        case .errorProcessingVideoFile: return "Error al procesar el archivo de video"
        case .invalidMotionPhotoOrUnsupportedFormat: return "Foto en Movimiento inválida o formato no compatible"
        case .missingData: return "Faltan datos"
        case .videoConversionFailed: return "La conversión de video falló"
        case .errorCreatingLivePhotoFile: return "Error al crear el archivo de Foto en vivo"
        case .cannotCreateExportSession: return "No se puede crear una sesión de exportación"
        case .cannotCreateImageSource: return "No se puede crear una fuente de imagen"
        case .cannotCreateImageDestination: return "No se puede crear un destino de imagen"
        case .cannotGetImageProperties: return "No se pueden obtener las propiedades de la imagen"
        case .cannotCreateVideoExportSession: return "No se puede crear una sesión de exportación de video"
        case .unknownError: return "Error desconocido"
        case .cannotGetVideoData: return "No se pueden obtener los datos de video"
        case .failedToCreateGIF: return "Error al crear el GIF"
        case .failedToProcessVideoData: return "Error al procesar los datos de video"
        case .videoConversionFailedNoErrorInfo: return "La conversión de video falló sin información de error"
        case .videoExportFailed: return "La exportación de video falló"
        case .cannotCreateGIFDestination: return "No se puede crear un destino GIF"
        case .cannotFinalizeGIFCreation: return "No se puede finalizar la creación del GIF"
        case .gifSavedToPhotos: return "El GIF se ha guardado en las fotos"
        case .failedToSaveGIF: return "Error al guardar el GIF"
        case .videoConversionCancelled: return "Conversión de video cancelada"
        case .videoConversionUnknownStatus: return "Estado de conversión de video desconocido"
        case .errorProcessingVideoMetadata: return "Error al procesar los metadatos del video"
        case .lab: return "Laboratorio"
        case .about: return "Acerca de"
        case .aboutDescription: return "Conversor de Fotos en Movimiento\nVersión 1.1\n© 2024 Igloo. Todos los derechos reservados."
        case .labTitle: return "Laboratorio Experimental"
        case .labDescription: return "Esta es una zona experimental para futuras características. ¡Manténgase atento!"
        case .customLivePhoto: return "Foto en vivo personalizada"
        case .customLivePhotoDescription: return "Crea una Foto en vivo personalizada seleccionando una imagen estática y un video."
        case .selectImage: return "Seleccionar imagen"
        case .selectVideo: return "Seleccionar video"
        case .createLivePhoto: return "Crear Foto en vivo"
        case .changeImage: return "Cambiar imagen"
        case .changeVideo: return "Cambiar video"
        case .videoSelected: return "Video seleccionado"
        case .video: return "Video"
        case .videoSaved: return "El video se ha guardado con éxito en el álbum"
        case .savingVideoFailed: return "Error al guardar el video"
        case .invalidVideoData: return "Datos de video inválidos"
        case .cannotCreateCompositionTrack: return "No se puede crear una pista de composición"
        case .cannotCreateExportSession: return "No se puede crear una sesión de exportación"
        case .videoExportFailed: return "La exportación de video falló"
        case .videoExportCancelled: return "La exportación de video fue cancelada"
        case .videoExportUnknownError: return "Error desconocido durante la exportación de video"
        case .imageConversionFailed: return "Error al convertir la imagen"
        case .exportSessionCreationFailed: return "Error al crear la sesión de exportación"
        case .imageSourceCreationFailed: return "Error al crear la fuente de imagen"
        case .imageTypeUnavailable: return "El tipo de imagen no está disponible"
        case .imageDestinationCreationFailed: return "Error al crear el destino de imagen"
        case .metadataWriteFailed: return "Error al escribir los metadatos"
        case .imagePropertiesUnavailable: return "Las propiedades de la imagen no están disponibles"
        }
    }
    
    var japanese: String {
        switch self {
        case .switchLanguage: return "英語に切り替え"
        case .appTitle: return "モーションフォト変換ツール"
        case .convert: return "変換"
        case .selectFile: return "ファイルを選択"
        case .processing: return "処理中..."
        case .success: return "変換成功"
        case .error: return "エラ"
        case .ok: return "OK"
        case .cancel: return "キャンセル"
        case .noFileSelected: return "ファイルが選択されていません"
        case .conversionFailed: return "変換に失敗しました"
        case .fileNotSupported: return "サポートされていないフイル形式です"
        case .notMotionPhoto: return "選択された写真はモーションフォトではありません"
        case .export: return "エクスポート"
        case .livePhoto: return "ライブフォト"
        case .gif: return "GIF"
        case .selectMotionPhoto: return "モーションフォトを選択"
        case .noVideoData: return "ビデオデータを取得できません"
        case .processingVideoData: return "ビデオデータの処理に失敗しました"
        case .creatingGIF: return "GIFを作成中..."
        case .gifSaved: return "GIFがアルバムに正常に保存されました"
        case .savingGIFFailed: return "GIFの保存に失敗しました"
        case .livePhotoSaved: return "ライブフォトがアルバムに正常に保存されました"
        case .savingLivePhotoFailed: return "ライブフォトの保存に失敗しました"
        case .homeTitle: return "モーションフォト変換ツール"
        case .homeDescription: return "モーションフォトを簡単にライブフォトやGIFに変換できます。動きの魔法を捉え、ダイナミックな形式で思い出を共有しましょう。"
        case .pleaseSelectMotionPhoto: return "モーションフォトを選択してください"
        case .selectedPhotoIsNotMotionPhoto: return "選択された写真はモーションフォトではありません"
        case .tip: return "ヒント"
        case .cannotReadFile: return "ファイルを読み取れません"
        case .errorProcessingVideoFile: return "ビデオファイルの処理中にエラーが発生しました"
        case .invalidMotionPhotoOrUnsupportedFormat: return "無効なモーションフォトまたはサポートされていない形式"
        case .missingData: return "データがありません"
        case .videoConversionFailed: return "ビデオ変換に失敗しました"
        case .errorCreatingLivePhotoFile: return "ライブフォトファイルの作成中にエラーが発生しました"
        case .cannotCreateExportSession: return "エクスポートセッションを作成できません"
        case .cannotCreateImageSource: return "画像ソースを作成できません"
        case .cannotCreateImageDestination: return "画像の宛先を作成できません"
        case .cannotGetImageProperties: return "画像のプロパティを取得できません"
        case .cannotCreateVideoExportSession: return "ビデオエクスポートセッションを作成できません"
        case .unknownError: return "不明なエラー"
        case .cannotGetVideoData: return "ビデオデータを取得できません"
        case .failedToCreateGIF: return "GIFの作成に失敗しました"
        case .failedToProcessVideoData: return "ビデオデータの処理に失敗しました"
        case .videoConversionFailedNoErrorInfo: return "ビデオ変換に失敗しました（エラー情報なし）"
        case .videoExportFailed: return "ビデオエクスポートに失敗しました"
        case .cannotCreateGIFDestination: return "GIFの宛先を作成できません"
        case .cannotFinalizeGIFCreation: return "GIFの作成を完了できません"
        case .gifSavedToPhotos: return "GIFが写真に保存されました"
        case .failedToSaveGIF: return "GIFの保存に失敗しました"
        case .videoConversionCancelled: return "ビデオ変換がキャンセルされました"
        case .videoConversionUnknownStatus: return "ビデオ変換の状態が不明です"
        case .errorProcessingVideoMetadata: return "ビデオメタデータの処理中にエラーが発生しました"
        case .lab: return "実験室"
        case .about: return "情報"
        case .aboutDescription: return "モーションフォト変換ツール\nバージョン 1.1\n© 2024 Igloo。全著作権所有。"
        case .labTitle: return "実験室"
        case .labDescription: return "これは将来の機能の実験エリアです。続くところお楽しみに！"
        case .customLivePhoto: return "カスタムライブフォト"
        case .customLivePhotoDescription: return "静止画とビデオを選択してカスタムライブフォトを作成します。"
        case .selectImage: return "画像を選択"
        case .selectVideo: return "ビデオを選択"
        case .createLivePhoto: return "ライブフォトを作成"
        case .changeImage: return "画像を変更"
        case .changeVideo: return "ビデオを変更"
        case .videoSelected: return "ビデオが選択されました"
        case .video: return "ビデオ"
        case .videoSaved: return "ビデオがアルバムに正常に保存されました"
        case .savingVideoFailed: return "ビデオの保存に失敗しました"
        case .invalidVideoData: return "無効なビデオデータ"
        case .cannotCreateCompositionTrack: return "コンポジショントラックを作成できません"
        case .cannotCreateExportSession: return "エクスポートセッションを作成できません"
        case .videoExportFailed: return "ビデオエクスポートに失敗しました"
        case .videoExportCancelled: return "ビデオエクスポートがキャンセルされました"
        case .videoExportUnknownError: return "ビデオエクスポート中に不明なエラーが発生しました"
        case .imageConversionFailed: return "画像の変換に失敗しました"
        case .exportSessionCreationFailed: return "エクスポートセッションの作成に失敗しました"
        case .imageSourceCreationFailed: return "画像ソースの作成に失敗しました"
        case .imageTypeUnavailable: return "画像タイプが利用できません"
        case .imageDestinationCreationFailed: return "画像の宛先の作成に失敗しました"
        case .metadataWriteFailed: return "メタデータの書き込みに失敗しました"
        case .imagePropertiesUnavailable: return "画像のプロパティが利用できません"
        }
    }
    
    var korean: String {
        switch self {
        case .switchLanguage: return "영어로 전환"
        case .appTitle: return "모션 포토 변환기"
        case .convert: return "변환"
        case .selectFile: return "파일 선택"
        case .processing: return "처리 중..."
        case .success: return "변환 성공"
        case .error: return "오류"
        case .ok: return "확인"
        case .cancel: return "취소"
        case .noFileSelected: return "선택된 파일 없음"
        case .conversionFailed: return "변환 실패"
        case .fileNotSupported: return "지원되지 않는 파일 형식"
        case .notMotionPhoto: return "선택한 사진이 모션 포토가 아닙니다"
        case .export: return "내보내기"
        case .livePhoto: return "라이브 포토"
        case .gif: return "GIF"
        case .selectMotionPhoto: return "모션 포토 선택"
        case .noVideoData: return "비디오 데이터를 가져올 수 없습니다"
        case .processingVideoData: return "비디오 데이터 처리 실패"
        case .creatingGIF: return "GIF 생성 중..."
        case .gifSaved: return "GIF가 앨범에 성공적으로 저장되었습니다"
        case .savingGIFFailed: return "GIF 저장 실패"
        case .livePhotoSaved: return "라이브 포토가 앨범에 성공적으로 저장되었습니다"
        case .savingLivePhotoFailed: return "라이브 포토 저장 실패"
        case .homeTitle: return "모션 포토 변환기"
        case .homeDescription: return "모션 포토를 쉽게 라이브 포토나 GIF로 변환하세요. 움직임의 마법을 포착하고 역동적인 형식으로 추억을 공유하세요."
        case .pleaseSelectMotionPhoto: return "모션 포토를 선택해주세요"
        case .selectedPhotoIsNotMotionPhoto: return "선택한 사진이 모션 포토가 아닙니다"
        case .tip: return "팁"
        case .cannotReadFile: return "파일을 읽을 수 없습니다"
        case .errorProcessingVideoFile: return "비디오 파일 처리 중 오류 발생"
        case .invalidMotionPhotoOrUnsupportedFormat: return "유효하지 않은 모션 포토 또는 지원되지 않는 형식"
        case .missingData: return "데이터 누락"
        case .videoConversionFailed: return "비디오 변환 실패"
        case .errorCreatingLivePhotoFile: return "라이브 포토 파일 생성 중 오류 발생"
        case .cannotCreateExportSession: return "내보내기 세션을 만들 수 없습니다"
        case .cannotCreateImageSource: return "이미지 소스를 만들 수 없습니다"
        case .cannotCreateImageDestination: return "이미지 대상을 만들 수 없습니다"
        case .cannotGetImageProperties: return "이미지 속성을 가져올 수 없습니다"
        case .cannotCreateVideoExportSession: return "비디오 내보내기 세션을 만들 수 없습니다"
        case .unknownError: return "알 수 없는 오류"
        case .cannotGetVideoData: return "비디오 데이터를 가져올 수 없습니다"
        case .failedToCreateGIF: return "GIF 생성 실패"
        case .failedToProcessVideoData: return "비디오 데이터 처리 실패"
        case .videoConversionFailedNoErrorInfo: return "비디오 변환 실패 (오류 정보 없음)"
        case .videoExportFailed: return "비디오 내보내기 실패"
        case .cannotCreateGIFDestination: return "GIF 대상을 만들 수 없습니다"
        case .cannotFinalizeGIFCreation: return "GIF 생성을 완료할 수 없습니다"
        case .gifSavedToPhotos: return "GIF가 사진에 저장되었습니다"
        case .failedToSaveGIF: return "GIF 저장 실패"
        case .videoConversionCancelled: return "비디오 변환이 취소되었습니다"
        case .videoConversionUnknownStatus: return "비디오 변환 상 알 수 없음"
        case .errorProcessingVideoMetadata: return "비디오 메타데이터 처리 중 오류 발생"
        case .lab: return "실험실"
        case .about: return "정보"
        case .aboutDescription: return "모션 포토 변환기\n버전 1.1\n© 2024 Igloo. 모든 권리 보유."
        case .labTitle: return "실험실"
        case .labDescription: return "이 곳은 미래 기능을 위한 실험 영역입니다. 곧 공개될 예정입니다!"
        case .customLivePhoto: return "커스텀 라이브 포토"
        case .customLivePhotoDescription: return "정지 이미지와 비디오를 선택하여 커스텀 라이브 포토를 만듭니다."
        case .selectImage: return "이미지 선택"
        case .selectVideo: return "비디오 선택"
        case .createLivePhoto: return "라이브 포토 만들기"
        case .changeImage: return "이미지 변경"
        case .changeVideo: return "비디오 변경"
        case .videoSelected: return "비디오 선택됨"
        case .video: return "비디오"
        case .videoSaved: return "비디오가 앨범에 성공적으로 저장되었습니다"
        case .savingVideoFailed: return "비디오 저장 실패"
        case .invalidVideoData: return "유효하지 않은 비디오 데이터"
        case .cannotCreateCompositionTrack: return "합성 트랙을 만들 수 없습니다"
        case .cannotCreateExportSession: return "내보내기 세션을 만들 수 없습니다"
        case .videoExportFailed: return "비디오 내보내기 실패"
        case .videoExportCancelled: return "비디오 내보내기가 취소되었습니다"
        case .videoExportUnknownError: return "비디오 내보내기 중 알 수 없는 오류 발생"
        case .imageConversionFailed: return "이미지 변환 실패"
        case .exportSessionCreationFailed: return "내보내기 세션 생성 실패"
        case .imageSourceCreationFailed: return "이미지 소스 생성 실패"
        case .imageTypeUnavailable: return "이미지 유형 사용 불가"
        case .imageDestinationCreationFailed: return "이미지 대상 생성 실패"
        case .metadataWriteFailed: return "메타데이터 쓰기 실패"
        case .imagePropertiesUnavailable: return "이미지 속성 사용 불가"
        }
    }
}
