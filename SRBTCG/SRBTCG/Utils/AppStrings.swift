//
//  AppStrings.swift
//  SRBTCG
//
//  アプリ内文字列の多言語対応
//

import SwiftUI
import Combine

/// 対応言語
enum AppLanguage: String, CaseIterable {
    case ja
    case en
    case ko
    case zhCN
    
    var displayName: String {
        switch self {
        case .ja:
            return "日本語"
        case .en:
            return "English"
        case .ko:
            return "한국어"
        case .zhCN:
            return "中文(简体)"
        }
    }
    
    var ttsLocale: String {
        switch self {
        case .ja:
            return "ja-JP"
        case .en:
            return "en-US"
        case .ko:
            return "ko-KR"
        case .zhCN:
            return "zh-CN"
        }
    }
    
    var sttLocale: String {
        switch self {
        case .ja:
            return "ja_JP"
        case .en:
            return "en_US"
        case .ko:
            return "ko_KR"
        case .zhCN:
            return "zh_CN"
        }
    }
}

/// アプリ内文字列の多言語対応
class AppStrings: ObservableObject {
    static let shared = AppStrings()
    
    @Published var currentLanguage: AppLanguage = .ja
    var needsLanguageSelection = false
    
    private let prefsKey = "appLanguage"
    
    private init() {
        loadLanguage()
    }
    
    /// UserDefaultsから言語設定を読み込む
    /// 初回起動時は端末の言語設定から自動検出
    func loadLanguage() {
        if let langName = UserDefaults.standard.string(forKey: prefsKey),
           let language = AppLanguage(rawValue: langName) {
            currentLanguage = language
            return
        }
        
        // 初回起動: 端末の言語設定から自動検出
        if let detected = detectDeviceLanguage() {
            currentLanguage = detected
            saveLanguage(detected)
        } else {
            // 対応外の言語 → 選択画面を表示するフラグ
            needsLanguageSelection = true
            currentLanguage = .en // 一時的にEnglish
        }
    }
    
    /// 端末のロケールから対応言語を検出
    private func detectDeviceLanguage() -> AppLanguage? {
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        let langCode = String(preferredLanguage.prefix(2)).lowercased()
        
        switch langCode {
        case "ja":
            return .ja
        case "en":
            return .en
        case "ko":
            return .ko
        case "zh":
            return .zhCN
        default:
            return nil
        }
    }
    
    /// UserDefaultsに言語設定を保存する
    func saveLanguage(_ language: AppLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: prefsKey)
    }
    
    // MARK: - Localized Strings
    
    // --- MainView ---
    var instructionList: String { return get("instructionList") }
    var noSavedLists: String { return get("noSavedLists") }
    var loadError: String { return get("loadError") }
    var searchHint: String { return get("searchHint") }
    
    // --- WaveEditView ---
    var enterTitle: String { return get("enterTitle") }
    var enterInstructionText: String { return get("enterInstructionText") }
    var startingGuide: String { return get("startingGuide") }
    var startingRecording: String { return get("startingRecording") }
    func waveStart(_ wave: Int) -> String {
        get("waveStart").replacingOccurrences(of: "{wave}", with: "\(wave)")
    }
    func waveEnd(_ wave: Int) -> String {
        get("waveEnd").replacingOccurrences(of: "{wave}", with: "\(wave)")
    }
    /// 録音でカウントダウンが終わったときの読み上げ
    func waveRecordingStart(_ wave: Int) -> String {
        get("waveRecordingStart").replacingOccurrences(of: "{wave}", with: "\(wave)")
    }
    /// Waveが終わってインターバルに入るときの読み上げ
    func waveEndNext(_ wave: Int, _ next: Int) -> String {
        get("waveEndNext")
            .replacingOccurrences(of: "{wave}", with: "\(wave)")
            .replacingOccurrences(of: "{next}", with: "\(next)")
    }
    var recordingCompleted: String { return get("recordingCompleted") }
    var sttUnavailable: String { return get("sttUnavailable") }
    func secondLabel(_ sec: Int) -> String {
        get("secondLabel").replacingOccurrences(of: "{sec}", with: "\(sec)")
    }
    
    // --- Wave clear ---
    var clearWave: String { return get("clearWave") }
    func clearWaveConfirm(_ wave: Int) -> String {
        get("clearWaveConfirm").replacingOccurrences(of: "{wave}", with: "\(wave)")
    }
    
    // --- Progress / Countdown ---
    var playing: String { return get("playing") }
    var recording: String { return get("recording") }
    func countdownLabel(_ sec: Int) -> String {
        get("countdownLabel").replacingOccurrences(of: "{sec}", with: "\(sec)")
    }
    func progressLabel(_ wave: Int, _ sec: Int) -> String {
        get("progressLabel")
            .replacingOccurrences(of: "{wave}", with: "\(wave)")
            .replacingOccurrences(of: "{sec}", with: "\(sec)")
    }
    func intervalLabel(_ sec: Int) -> String {
        get("intervalLabel").replacingOccurrences(of: "{sec}", with: "\(sec)")
    }
    
    // --- Delete confirmation ---
    var deleteConfirmTitle: String { return get("deleteConfirmTitle") }
    func deleteConfirmMessage(_ count: Int) -> String {
        get("deleteConfirmMessage").replacingOccurrences(of: "{count}", with: "\(count)")
    }
    var cancel: String { return get("cancel") }
    var delete: String { return get("delete") }
    
    // --- List copy ---
    var duplicate: String { return get("duplicate") }
    
    // --- Export / Import ---
    var dataManagement: String { return get("dataManagement") }
    var exportData: String { return get("exportData") }
    var importData: String { return get("importData") }
    var exportSuccess: String { return get("exportSuccess") }
    func importSuccess(_ count: Int) -> String {
        get("importSuccess").replacingOccurrences(of: "{count}", with: "\(count)")
    }
    var importError: String { return get("importError") }
    var noDataToExport: String { return get("noDataToExport") }
    func importConfirm(_ count: Int) -> String {
        get("importConfirm").replacingOccurrences(of: "{count}", with: "\(count)")
    }
    
    // --- SettingsView ---
    var settings: String { return get("settings") }
    var languageSetting: String { return get("languageSetting") }
    var aboutApp: String { return get("aboutApp") }
    
    // --- Stop confirmation ---
    var stopPlaybackTitle: String { return get("stopPlaybackTitle") }
    var stopPlaybackMessage: String { return get("stopPlaybackMessage") }
    var stopPlayback: String { return get("stopPlayback") }
    var stopRecordingTitle: String { return get("stopRecordingTitle") }
    var stopRecordingMessage: String { return get("stopRecordingMessage") }
    var stopRecording: String { return get("stopRecording") }
    
    // --- Tab / Home ---
    var tabBigRun: String { return get("tabBigRun") }
    var tabSalmonRun: String { return get("tabSalmonRun") }
    var bigRunContestHeader: String { return get("bigRunContestHeader") }
    var salmonRunGuideHeader: String { return get("salmonRunGuideHeader") }
    
    // --- SalmonRunGuideView ---
    var hazardLevel: String { return get("hazardLevel") }
    var hazardLow: String { return get("hazardLow") }
    var hazardMid: String { return get("hazardMid") }
    var hazardHigh: String { return get("hazardHigh") }
    var hazardMax: String { return get("hazardMax") }
    var srGuideNote: String { return get("srGuideNote") }
    var srGuideLanding: String { return get("srGuideLanding") }
    var startPlayback: String { return get("startPlayback") }
    var spawnDirectionChange: String { return get("spawnDirectionChange") }
    var thirtySecondsLeft: String { return get("thirtySecondsLeft") }
    var finalSpawn: String { return get("finalSpawn") }
    var waveClear: String { return get("waveClear") }
    var allClear: String { return get("allClear") }
    
    // --- Recording UI ---
    var tapWhenLanding: String { return get("tapWhenLanding") }
    
    // --- PlaybackView ---
    var playbackTitle: String { return get("playbackTitle") }
    
    // --- Purchase ---
    var purchaseTitle: String { return get("purchaseTitle") }
    var purchaseSTTExport: String { return get("purchaseSTTExport") }
    var purchaseAdFree: String { return get("purchaseAdFree") }
    var purchasePremiumBundle: String { return get("purchasePremiumBundle") }
    var purchaseRestore: String { return get("purchaseRestore") }
    var purchaseSuccess: String { return get("purchaseSuccess") }
    var purchaseError: String { return get("purchaseError") }
    var purchaseCancelled: String { return get("purchaseCancelled") }
    var purchaseAlreadyOwned: String { return get("purchaseAlreadyOwned") }
    var purchaseRestoreSuccess: String { return get("purchaseRestoreSuccess") }
    var purchaseRestoreNotFound: String { return get("purchaseRestoreNotFound") }
    
    // MARK: - Private Methods
    
    private func get(_ key: String) -> String {
        strings[currentLanguage]?[key] ?? strings[.ja]?[key] ?? "Missing: \(key)"
    }
    
    // MARK: - String Data
    
    private let strings: [AppLanguage: [String: String]] = [
        .ja: [
            "instructionList": "指示リスト",
            "noSavedLists": "保存されたリストはありません。\n[＋]ボタンをタップして追加してください。",
            "loadError": "リストの読み込みに失敗しました",
            "searchHint": "リストを検索...",
            "enterTitle": "タイトルを入力してください。",
            "enterInstructionText": "指示テキストを入力してください。",
            "startingGuide": "ガイドをスタートします",
            "startingRecording": "録音をスタートします",
            "waveStart": "Wave {wave} 開始",
            "waveEnd": "Wave {wave} 終了",
            "waveRecordingStart": "Wave {wave} の録音を開始します",
            "waveEndNext": "Wave {wave} 終了です。次は Wave {next}",
            "recordingCompleted": "録音が完了しました",
            "sttUnavailable": "音声認識を利用できません。マイクの権限を確認してください。",
            "secondLabel": "{sec} 秒",
            "clearWave": "クリア",
            "clearWaveConfirm": "Wave {wave} のテキストをすべて削除しますか？",
            "playing": "再生中",
            "recording": "録音中",
            "countdownLabel": "開始まで {sec}秒",
            "progressLabel": "Wave {wave} - {sec}秒",
            "intervalLabel": "インターバル {sec}秒",
            "deleteConfirmTitle": "削除確認",
            "deleteConfirmMessage": "選択した{count}件のリストを削除しますか？",
            "cancel": "キャンセル",
            "delete": "削除",
            "duplicate": "複製",
            "dataManagement": "データ管理",
            "exportData": "データをエクスポート",
            "importData": "データをインポート",
            "exportSuccess": "エクスポートが完了しました",
            "importSuccess": "{count}件のリストをインポートしました",
            "importError": "インポートに失敗しました",
            "noDataToExport": "エクスポートするデータがありません",
            "importConfirm": "{count}件のリストをインポートしますか？",
            "settings": "設定",
            "languageSetting": "言語設定",
            "aboutApp": "アプリについて",
            "stopPlaybackTitle": "再生停止",
            "stopPlaybackMessage": "再生を停止しますか？\n停止すると最初からやり直しになります。",
            "stopPlayback": "停止する",
            "stopRecordingTitle": "録音停止",
            "stopRecordingMessage": "録音を停止しますか？\n停止すると最初からやり直しになります。",
            "stopRecording": "停止する",
            "tabBigRun": "バチコン",
            "tabSalmonRun": "ビッグラン/通常",
            "bigRunContestHeader": "バイトチームコンテスト",
            "salmonRunGuideHeader": "ビッグラン/通常",
            "hazardLevel": "キケン度",
            "hazardLow": "~199%",
            "hazardMid": "200~299%",
            "hazardHigh": "300~332%",
            "hazardMax": "MAX (333%)",
            "srGuideNote": "でんせつ以上を前提としたタイミングガイドです",
            "srGuideLanding": "地面に着地したタイミングで再生を開始してください",
            "startPlayback": "着地時に ▶ を再度タップで再生開始",
            "tapWhenLanding": "着地時に ▶ を再度タップで録音開始",
            "spawnDirectionChange": "湧き方向変更！",
            "thirtySecondsLeft": "残り30秒",
            "finalSpawn": "最終湧き",
            "waveClear": "Wave クリア！",
            "allClear": "全クリア！おつかれ！",
            "playbackTitle": "再生",
            "purchaseTitle": "アプリ内購入",
            "purchaseSTTExport": "STT+Export機能",
            "purchaseAdFree": "広告非表示",
            "purchasePremiumBundle": "プレミアムバンドル",
            "purchaseRestore": "購入を復元",
            "purchaseSuccess": "購入が完了しました",
            "purchaseError": "購入処理中にエラーが発生しました",
            "purchaseCancelled": "購入がキャンセルされました",
            "purchaseAlreadyOwned": "既に購入済みです",
            "purchaseRestoreSuccess": "購入履歴を復元しました",
            "purchaseRestoreNotFound": "復元できる購入履歴が見つかりませんでした"
        ],
        .en: [
            "instructionList": "Instruction List",
            "noSavedLists": "No saved lists.\nTap [+] to add one.",
            "loadError": "Failed to load lists",
            "searchHint": "Search lists...",
            "enterTitle": "Enter title",
            "enterInstructionText": "Enter instruction text",
            "startingGuide": "Starting guide",
            "startingRecording": "Starting recording",
            "waveStart": "Wave {wave} Start",
            "waveEnd": "Wave {wave} End",
            "waveRecordingStart": "Starting recording for Wave {wave}",
            "waveEndNext": "Wave {wave} finished. Next is Wave {next}",
            "recordingCompleted": "Recording completed",
            "sttUnavailable": "Speech recognition unavailable. Check microphone permissions.",
            "secondLabel": "{sec} sec",
            "clearWave": "Clear",
            "clearWaveConfirm": "Delete all text from Wave {wave}?",
            "playing": "Playing",
            "recording": "Recording",
            "countdownLabel": "Starting in {sec}",
            "progressLabel": "Wave {wave} - {sec}s",
            "intervalLabel": "Interval {sec}s",
            "deleteConfirmTitle": "Delete Confirmation",
            "deleteConfirmMessage": "Delete {count} selected list(s)?",
            "cancel": "Cancel",
            "delete": "Delete",
            "duplicate": "Duplicate",
            "dataManagement": "Data Management",
            "exportData": "Export Data",
            "importData": "Import Data",
            "exportSuccess": "Export completed",
            "importSuccess": "Imported {count} list(s)",
            "importError": "Import failed",
            "noDataToExport": "No data to export",
            "importConfirm": "Import {count} list(s)?",
            "settings": "Settings",
            "languageSetting": "Language",
            "aboutApp": "About",
            "stopPlaybackTitle": "Stop Playback",
            "stopPlaybackMessage": "Stop playback?\nYou'll need to start over.",
            "stopPlayback": "Stop",
            "stopRecordingTitle": "Stop Recording",
            "stopRecordingMessage": "Stop recording?\nYou'll need to start over.",
            "stopRecording": "Stop",
            "tabBigRun": "Contest",
            "tabSalmonRun": "Big Run/Normal",
            "bigRunContestHeader": "Big Run Contest",
            "salmonRunGuideHeader": "Big Run/Normal",
            "hazardLevel": "Hazard Level",
            "hazardLow": "~199%",
            "hazardMid": "200~299%",
            "hazardHigh": "300~332%",
            "hazardMax": "MAX (333%)",
            "srGuideNote": "Timing guide for Profreshional+",
            "srGuideLanding": "Start playback when landing",
            "startPlayback": "Tap ▶ again when landing",
            "tapWhenLanding": "Tap ▶ again when landing to record",
            "spawnDirectionChange": "Spawn direction change!",
            "thirtySecondsLeft": "30 seconds left",
            "finalSpawn": "Final spawn",
            "waveClear": "Wave Clear!",
            "allClear": "All Clear! Great job!",
            "playbackTitle": "Playback",
            "purchaseTitle": "In-App Purchase",
            "purchaseSTTExport": "STT+Export Features",
            "purchaseAdFree": "Remove Ads",
            "purchasePremiumBundle": "Premium Bundle",
            "purchaseRestore": "Restore Purchases",
            "purchaseSuccess": "Purchase completed",
            "purchaseError": "Purchase error occurred",
            "purchaseCancelled": "Purchase cancelled",
            "purchaseAlreadyOwned": "Already purchased",
            "purchaseRestoreSuccess": "Purchases restored",
            "purchaseRestoreNotFound": "No purchases to restore"
        ],
        .ko: [
            "instructionList": "지시 목록",
            "noSavedLists": "저장된 목록이 없습니다.\n[+]를 탭하여 추가하세요.",
            "loadError": "목록 불러오기 실패",
            "searchHint": "목록 검색...",
            "enterTitle": "제목 입력",
            "enterInstructionText": "지시 텍스트 입력",
            "startingGuide": "가이드 시작",
            "startingRecording": "녹음 시작",
            "waveStart": "웨이브 {wave} 시작",
            "waveEnd": "웨이브 {wave} 종료",
            "waveRecordingStart": "웨이브 {wave} 녹음을 시작합니다",
            "waveEndNext": "웨이브 {wave} 종료입니다. 다음은 웨이브 {next}",
            "recordingCompleted": "녹음 완료",
            "sttUnavailable": "음성 인식을 사용할 수 없습니다. 마이크 권한을 확인하세요.",
            "secondLabel": "{sec}초",
            "clearWave": "지우기",
            "clearWaveConfirm": "웨이브 {wave}의 모든 텍스트를 삭제하시겠습니까?",
            "playing": "재생 중",
            "recording": "녹음 중",
            "countdownLabel": "{sec}초 후 시작",
            "progressLabel": "웨이브 {wave} - {sec}초",
            "intervalLabel": "휴식 {sec}초",
            "deleteConfirmTitle": "삭제 확인",
            "deleteConfirmMessage": "선택한 {count}개 목록을 삭제하시겠습니까?",
            "cancel": "취소",
            "delete": "삭제",
            "duplicate": "복제",
            "dataManagement": "데이터 관리",
            "exportData": "데이터 내보내기",
            "importData": "데이터 가져오기",
            "exportSuccess": "내보내기 완료",
            "importSuccess": "{count}개 목록 가져오기 완료",
            "importError": "가져오기 실패",
            "noDataToExport": "내보낼 데이터가 없습니다",
            "importConfirm": "{count}개 목록을 가져오시겠습니까?",
            "settings": "설정",
            "languageSetting": "언어",
            "aboutApp": "정보",
            "stopPlaybackTitle": "재생 중지",
            "stopPlaybackMessage": "재생을 중지하시겠습니까?\n처음부터 다시 시작해야 합니다.",
            "stopPlayback": "중지",
            "stopRecordingTitle": "녹음 중지",
            "stopRecordingMessage": "녹음을 중지하시겠습니까?\n처음부터 다시 시작해야 합니다.",
            "stopRecording": "중지",
            "tabBigRun": "콘테스트",
            "tabSalmonRun": "빅런/일반",
            "bigRunContestHeader": "빅런 콘테스트",
            "salmonRunGuideHeader": "빅런/일반",
            "hazardLevel": "위험도",
            "hazardLow": "~199%",
            "hazardMid": "200~299%",
            "hazardHigh": "300~332%",
            "hazardMax": "MAX (333%)",
            "srGuideNote": "전설 이상 기준 타이밍 가이드",
            "srGuideLanding": "착지 시 재생 시작",
            "startPlayback": "착지 시 ▶ 다시 탭",
            "tapWhenLanding": "착지 시 ▶ 다시 탭하여 녹음 시작",
            "spawnDirectionChange": "스폰 방향 변경!",
            "thirtySecondsLeft": "30초 남음",
            "finalSpawn": "마지막 스폰",
            "waveClear": "웨이브 클리어!",
            "allClear": "올 클리어! 수고하셨습니다!",
            "playbackTitle": "재생",
            "purchaseTitle": "인앱 구매",
            "purchaseSTTExport": "STT+내보내기 기능",
            "purchaseAdFree": "광고 제거",
            "purchasePremiumBundle": "프리미엄 번들",
            "purchaseRestore": "구매 복원",
            "purchaseSuccess": "구매 완료",
            "purchaseError": "구매 오류 발생",
            "purchaseCancelled": "구매 취소됨",
            "purchaseAlreadyOwned": "이미 구매함",
            "purchaseRestoreSuccess": "구매 복원 완료",
            "purchaseRestoreNotFound": "복원할 구매 내역이 없습니다"
        ],
        .zhCN: [
            "instructionList": "指示列表",
            "noSavedLists": "没有保存的列表。\n点击[+]添加。",
            "loadError": "加载列表失败",
            "searchHint": "搜索列表...",
            "enterTitle": "输入标题",
            "enterInstructionText": "输入指示文本",
            "startingGuide": "开始指导",
            "startingRecording": "开始录音",
            "waveStart": "第{wave}波开始",
            "waveEnd": "第{wave}波结束",
            "waveRecordingStart": "开始录制第{wave}波",
            "waveEndNext": "第{wave}波结束。接下来是第{next}波",
            "recordingCompleted": "录音完成",
            "sttUnavailable": "语音识别不可用。请检查麦克风权限。",
            "secondLabel": "{sec}秒",
            "clearWave": "清除",
            "clearWaveConfirm": "删除第{wave}波的所有文本？",
            "playing": "播放中",
            "recording": "录音中",
            "countdownLabel": "{sec}秒后开始",
            "progressLabel": "第{wave}波 - {sec}秒",
            "intervalLabel": "间隔{sec}秒",
            "deleteConfirmTitle": "删除确认",
            "deleteConfirmMessage": "删除选中的{count}个列表？",
            "cancel": "取消",
            "delete": "删除",
            "duplicate": "复制",
            "dataManagement": "数据管理",
            "exportData": "导出数据",
            "importData": "导入数据",
            "exportSuccess": "导出完成",
            "importSuccess": "导入{count}个列表",
            "importError": "导入失败",
            "noDataToExport": "没有可导出的数据",
            "importConfirm": "导入{count}个列表？",
            "settings": "设置",
            "languageSetting": "语言",
            "aboutApp": "关于",
            "stopPlaybackTitle": "停止播放",
            "stopPlaybackMessage": "停止播放？\n需要从头开始。",
            "stopPlayback": "停止",
            "stopRecordingTitle": "停止录音",
            "stopRecordingMessage": "停止录音？\n需要从头开始。",
            "stopRecording": "停止",
            "tabBigRun": "竞赛",
            "tabSalmonRun": "大型鲑鱼跑/普通",
            "bigRunContestHeader": "大型鲑鱼跑竞赛",
            "salmonRunGuideHeader": "大型鲑鱼跑/普通",
            "hazardLevel": "危险等级",
            "hazardLow": "~199%",
            "hazardMid": "200~299%",
            "hazardHigh": "300~332%",
            "hazardMax": "MAX (333%)",
            "srGuideNote": "传说以上等级时机指南",
            "srGuideLanding": "着陆时开始播放",
            "startPlayback": "着陆时再次点击▶",
            "tapWhenLanding": "着陆时再次点击▶开始录音",
            "spawnDirectionChange": "刷新方向改变！",
            "thirtySecondsLeft": "剩余30秒",
            "finalSpawn": "最后刷新",
            "waveClear": "过关！",
            "allClear": "全部通关！辛苦了！",
            "playbackTitle": "播放",
            "purchaseTitle": "应用内购买",
            "purchaseSTTExport": "STT+导出功能",
            "purchaseAdFree": "去除广告",
            "purchasePremiumBundle": "高级套装",
            "purchaseRestore": "恢复购买",
            "purchaseSuccess": "购买完成",
            "purchaseError": "购买出错",
            "purchaseCancelled": "购买已取消",
            "purchaseAlreadyOwned": "已购买",
            "purchaseRestoreSuccess": "购买恢复成功",
            "purchaseRestoreNotFound": "没有可恢复的购买"
        ]
    ]
}