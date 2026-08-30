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
    
    // 状態
    @Published var isRecording = false
    @Published var recognizedText = ""
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
        // 既存のタスクがあればキャンセル
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // オーディオセッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 認識リクエストの作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            throw STTError.recognitionRequestCreationFailed
        }
        
        // リアルタイム結果を取得
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // 認識タスクの開始
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                self?.recognizedText = text
                self?.onTextRecognized?(text)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self?.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                self?.isRecording = false
            }
        }
        
        // 音声入力の設定
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // オーディオエンジンの開始
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        recognizedText = ""
    }
    
    /// 録音停止
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
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