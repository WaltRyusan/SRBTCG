//
//  TTSManager.swift
//  SRBTCG
//
//  Text-to-Speech管理
//

import AVFoundation
import SwiftUI
import Combine

/// Text-to-Speech管理クラス
@MainActor
class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var rate: Float = 0.5
    @Published var pitch: Float = 1.0
    @Published var volume: Float = 1.0
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    /// オーディオセッションの設定
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    /// テキストを読み上げる
    func speak(_ text: String, language: AppLanguage = .ja) {
        // 既に読み上げ中の場合は停止
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.ttsLocale)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    /// 読み上げを停止
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    /// 読み上げを一時停止
    func pause() {
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    /// 読み上げを再開
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}