#!/usr/bin/env swift

import Foundation

// 从现有的 Localizable.swift 提取的翻译数据
struct Translation {
    let key: String
    let translations: [String: String]
}

// 所有翻译数据
let translations: [Translation] = [
    Translation(key: "switchLanguage", translations: [
        "en": "Switch to English",
        "zh": "切换到英文",
        "fr": "Passer à l'anglais",
        "de": "Zu Englisch wechseln",
        "es": "Cambiar a inglés",
        "ja": "英語に切り替え",
        "ko": "영어로 전환"
    ]),
    Translation(key: "appTitle", translations: [
        "en": "Motion Photo Converter",
        "zh": "动态照片转换器",
        "fr": "Convertisseur Motion Photo",
        "de": "Motion Photo Converter",
        "es": "Convertidor de Motion Photo",
        "ja": "モーションフォトコンバーター",
        "ko": "모션 포토 변환기"
    ]),
    Translation(key: "convert", translations: [
        "en": "Convert",
        "zh": "转换",
        "fr": "Convertir",
        "de": "Konvertieren",
        "es": "Convertir",
        "ja": "変換",
        "ko": "변환"
    ]),
    Translation(key: "selectFile", translations: [
        "en": "Select File",
        "zh": "选择文件",
        "fr": "Sélectionner un fichier",
        "de": "Datei auswählen",
        "es": "Seleccionar archivo",
        "ja": "ファイルを選択",
        "ko": "파일 선택"
    ]),
    Translation(key: "processing", translations: [
        "en": "Processing...",
        "zh": "处理中...",
        "fr": "Traitement en cours...",
        "de": "Verarbeitung...",
        "es": "Procesando...",
        "ja": "処理中...",
        "ko": "처리 중..."
    ]),
    Translation(key: "success", translations: [
        "en": "Success",
        "zh": "成功",
        "fr": "Succès",
        "de": "Erfolg",
        "es": "Éxito",
        "ja": "成功",
        "ko": "성공"
    ]),
    Translation(key: "error", translations: [
        "en": "Error",
        "zh": "错误",
        "fr": "Erreur",
        "de": "Fehler",
        "es": "Error",
        "ja": "エラー",
        "ko": "오류"
    ]),
    Translation(key: "ok", translations: [
        "en": "OK",
        "zh": "确定",
        "fr": "OK",
        "de": "OK",
        "es": "OK",
        "ja": "OK",
        "ko": "확인"
    ]),
    Translation(key: "cancel", translations: [
        "en": "Cancel",
        "zh": "取消",
        "fr": "Annuler",
        "de": "Abbrechen",
        "es": "Cancelar",
        "ja": "キャンセル",
        "ko": "취소"
    ]),
    Translation(key: "selectMotionPhoto", translations: [
        "en": "Select Motion Photo",
        "zh": "选择动态照片",
        "fr": "Sélectionner Motion Photo",
        "de": "Motion Photo auswählen",
        "es": "Seleccionar Motion Photo",
        "ja": "モーションフォトを選択",
        "ko": "모션 포토 선택"
    ]),
    Translation(key: "help", translations: [
        "en": "Help",
        "zh": "帮助",
        "fr": "Aide",
        "de": "Hilfe",
        "es": "Ayuda",
        "ja": "ヘルプ",
        "ko": "도움말"
    ]),
    Translation(key: "done", translations: [
        "en": "Done",
        "zh": "完成",
        "fr": "Terminé",
        "de": "Fertig",
        "es": "Hecho",
        "ja": "完了",
        "ko": "완료"
    ])
]

// 生成 String Catalog JSON
func generateStringCatalog() -> String {
    var catalog: [String: Any] = [
        "sourceLanguage": "en",
        "version": "1.0",
        "strings": [:]
    ]
    
    var strings: [String: Any] = [:]
    
    for translation in translations {
        var localizations: [String: Any] = [:]
        
        for (language, value) in translation.translations {
            localizations[language] = [
                "stringUnit": [
                    "state": "translated",
                    "value": value
                ]
            ]
        }
        
        strings[translation.key] = [
            "extractionState": "manual",
            "localizations": localizations
        ]
    }
    
    catalog["strings"] = strings
    
    let jsonData = try! JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    return String(data: jsonData, encoding: .utf8)!
}

// 生成并输出 String Catalog
let catalogContent = generateStringCatalog()
print(catalogContent)