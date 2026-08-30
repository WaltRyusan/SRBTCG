//
//  STTManager.swift
//  SRBTCG
//
//  Speech-to-Text管理
//

import Speech
import AVFoundation
import SwiftUI
import Combine

/// Speech-to-Text管理クラス
class STTManager: NSObject, ObservableObject {
    static let shared = STTManager()
    
    // 音声認識エンジン
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    /// inputNode にタップを張っているか
    ///
    /// removeTap のために inputNode へ触ると、その時点の
    /// オーディオセッションでフォーマットが確定してしまう。
    /// セッションを .record にする前に触ると 0Hz のフォーマットを掴み、
    /// あとの installTap が例外で落ちる。張った時だけ外す。
    private var isTapInstalled = false
    
    // 状態
    @Published var isRecording = false
    @Published var recognizedText = ""
    /// 認識できた語を発話時刻つきで保持する
    ///
    /// 認識結果は後から前の語を訂正するため、
    /// 文字列の差分を一定間隔で切り出すと欠けたり重複したりする。
    /// 実際に発話された時刻が分かれば、正しい枠へ割り振れる。
    @Published var recognizedSegments: [RecognizedSegment] = []
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    // コールバック
    var onTextRecognized: ((String) -> Void)?
    
    private override init() {
        super.init()
        setupSpeechRecognizer()
        requestAuthorization()
    }
    
    /// 音声認識の初期設定
    private func setupSpeechRecognizer() {
        let language = AppStrings.shared.currentLanguage
        let locale = Locale(identifier: language.sttLocale.replacingOccurrences(of: "_", with: "-"))
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
    }
    
    /// 言語を変更
    func changeLanguage(_ language: AppLanguage) {
        stopRecording()
        let locale = Locale(identifier: language.sttLocale.replacingOccurrences(of: "_", with: "-"))
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
    }
    
    /// 録音に必要な許可をまとめて取得する
    ///
    /// マイクの許可は audioEngine.start() の時点で初めて要求されるため、
    /// 事前に取っておかないとカウントダウン後にOSダイアログが割り込み、
    /// 開始タイミングがずれる。
    func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        await MainActor.run { self.isAuthorized = speechGranted && micGranted }
        return speechGranted && micGranted
    }

    /// 権限リクエスト
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.isAuthorized = true
                case .denied:
                    self?.isAuthorized = false
                    self?.errorMessage = "音声認識の権限が拒否されました"
                case .restricted:
                    self?.isAuthorized = false
                    self?.errorMessage = "音声認識は制限されています"
                case .notDetermined:
                    self?.isAuthorized = false
                    self?.errorMessage = "音声認識の権限が未決定です"
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    /// 録音開始
    func startRecording() throws {
        // 前回の録音を確実に畳んでから始める。
        //
        // recognitionTask.cancel() だけでは engine の停止と removeTap が
        // 完了ハンドラ経由で非同期に走るため、この下の installTap に間に合わない。
        // タップが残ったまま同じバスへ installTap すると AVAudioEngine が
        // NSException を投げてアプリごと落ちる（Wave2の開始で発生していた）。
        stopRecording()

        // オーディオセッションの設定
        //
        // .record にすると録音中は再生が止まり、Wave開始・終了の
        // アナウンスが聞こえなくなる。録音と再生を両立させる必要がある。
        // .voiceChat はエコーキャンセルが入るので、
        // スピーカーから出た自分のアナウンスを認識してしまうのも防げる。
        // 以前の .measurement はノイズ抑制と自動ゲイン調整を切るモードで、
        // 静かな環境での測定用。ゲーム中の音声には向かない。
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 認識リクエストの作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode

        guard let recognitionRequest = recognitionRequest else {
            throw STTError.recognitionRequestCreationFailed
        }

        // リアルタイム結果を取得
        recognitionRequest.shouldReportPartialResults = true

        // 端末内で認識する。
        // サーバー認識は通信の往復ぶん遅れ、電波が悪いと精度も落ちる。
        // ゲーム中は通信が混みやすいので、使えるなら端末内で処理する。
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        // サーモンラン用語を渡して認識率を上げる
        recognitionRequest.contextualStrings =
            SalmonRunVocabulary.terms(for: AppStrings.shared.currentLanguage)
        recognitionRequest.taskHint = .dictation
        // 句読点の推定は遅延が増えるだけで、Wave指示には不要
        recognitionRequest.addsPunctuation = false
        
        // 認識タスクの開始
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                self?.recognizedText = text
                self?.recognizedSegments = result.bestTranscription.segments.map {
                    RecognizedSegment(text: $0.substring, timestamp: $0.timestamp)
                }
                self?.onTextRecognized?(text)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self?.audioEngine.stop()
                if self?.isTapInstalled == true {
                    inputNode.removeTap(onBus: 0)
                    self?.isTapInstalled = false
                }
                
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                self?.isRecording = false
            }
        }
        
        // 音声入力の設定
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // マイクが使えないとサンプルレートが0のフォーマットが返り、
        // installTap が ObjC 例外を投げてアプリごと落ちる（Swiftのcatchでは拾えない）。
        // 他アプリがマイクを掴んでいるときなどに起きるため、
        // 落とさずに throw して呼び出し側で止められるようにする。
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            stopRecording()
            throw STTError.audioEngineStartFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        isTapInstalled = true
        
        // オーディオエンジンの開始
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        recognizedText = ""
        recognizedSegments = []
    }
    
    /// 録音停止
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()

        // engine が先に止まっていてもタップは残るため、isRunning では判断しない。
        // ただし張っていないのに inputNode へ触るとフォーマットが
        // 不正なまま確定してしまうので、フラグで見分ける。
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension STTManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            errorMessage = "音声認識が利用できません"
        } else {
            errorMessage = nil
        }
    }
}

// MARK: - Segment

/// 認識できた語と、その語が発話された録音開始からの秒数
struct RecognizedSegment {
    let text: String
    let timestamp: TimeInterval
}

// MARK: - Error

enum STTError: Error {
    case recognitionRequestCreationFailed
    case audioEngineStartFailed
    
    var localizedDescription: String {
        switch self {
        case .recognitionRequestCreationFailed:
            return "音声認識リクエストの作成に失敗しました"
        case .audioEngineStartFailed:
            return "オーディオエンジンの開始に失敗しました"
        }
    }
}