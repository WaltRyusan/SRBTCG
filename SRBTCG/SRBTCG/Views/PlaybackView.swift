//
//  PlaybackView.swift
//  SRBTCG
//
//  Wave再生専用画面
//

import SwiftUI
import AVFoundation

struct PlaybackView: View {
    let title: String
    let waveTexts: [Int: String]
    let waveCount: Int = 5
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appStrings: AppStrings
    @State private var isPlaying = true
    /// 再生停止の確認
    @State private var showStopConfirmation = false
    @State private var progressWave = 0
    @State private var progressSecond = 0
    @State private var countdownRemaining: Double = 14.5
    @State private var isCountdown = true
    @State private var isInterval = false
    @State private var playbackTimer: Timer?
    @State private var announcementLog: [String] = []
    @State private var currentAnnouncement = ""
    
    @StateObject private var ttsManager = TTSManager.shared
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [AppColors.background, AppColors.surface]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // タイトル
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.top, 60)
                
                Spacer()
                
                // メイン表示エリア
                if isCountdown {
                    // カウントダウン表示
                    VStack(spacing: 20) {
                        Text(appStrings.countdownLabel(Int(ceil(countdownRemaining))))
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.golden)
                            .animation(.spring(), value: countdownRemaining)
                        
                        Text("準備してください")
                            .font(.title2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else if isInterval {
                    // インターバル表示
                    VStack(spacing: 20) {
                        Text(appStrings.intervalLabel(Int(ceil(countdownRemaining))))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.accent)
                            .animation(.spring(), value: countdownRemaining)
                        
                        Text("次のWaveまで")
                            .font(.title2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    // Wave進行中表示
                    VStack(spacing: 20) {
                        // 進行状況
                        Text(appStrings.progressLabel(progressWave, progressSecond))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)
                        
                        // 現在のアナウンス内容
                        if !currentAnnouncement.isEmpty {
                            Text(currentAnnouncement)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.golden)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .animation(.easeIn, value: currentAnnouncement)
                        }
                        
                        // プログレスリング
                        ZStack {
                            Circle()
                                .stroke(AppColors.surface, lineWidth: 15)
                                .frame(width: 180, height: 180)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(progressSecond) / 100.0)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.golden, AppColors.primary]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                )
                                .frame(width: 180, height: 180)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: progressSecond)
                            
                            VStack {
                                Text("\(progressSecond)")
                                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppColors.textPrimary)
                                Text("/ 100")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        // 現在のテキスト表示
                        if let currentText = getCurrentText() {
                            Text(currentText)
                                .font(.title3)
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .frame(maxHeight: 100)
                        }
                        
                        // アナウンスログ（スクロール可能）
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(announcementLog.reversed(), id: \.self) { log in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.primary)
                                        Text(log)
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .background(AppColors.surface.opacity(0.3))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // 停止ボタン
                Button(action: { showStopConfirmation = true }) {
                    HStack {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                        Text(appStrings.stopPlayback)
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(width: 200, height: 60)
                    .background(AppColors.danger)
                    .cornerRadius(30)
                    .shadow(radius: 5)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startPlayback()
            UIApplication.shared.isIdleTimerDisabled = true // 画面スリープ防止
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            playbackTimer?.invalidate()
            ttsManager.stop()
        }
        .alert("再生を終了しますか？", isPresented: $showStopConfirmation) {
            Button("続ける", role: .cancel) { }
            Button("終了する", role: .destructive) { stopPlayback() }
        } message: {
            Text("再生を終了して一覧に戻ります。")
        }
    }
    
    // MARK: - Methods
    
    private func startPlayback() {
        // 初期TTS設定
        ttsManager.rate = 0.5
        ttsManager.pitch = 0.8
        ttsManager.volume = 1.0
        
        // 開始アナウンス
        Task { @MainActor in
            ttsManager.speak(appStrings.startingGuide)
        }
        
        // カウントダウン開始
        startCountdown()
    }
    
    private func startCountdown() {
        isCountdown = true
        countdownRemaining = 14.5
        
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if countdownRemaining > 0 {
                countdownRemaining -= 0.5
                
                // 3, 2, 1のカウント読み上げ（整数秒のみ）
                if countdownRemaining <= 3 && countdownRemaining > 0 {
                    let intValue = Int(countdownRemaining)
                    if countdownRemaining == Double(intValue) {
                        Task { @MainActor in
                            ttsManager.speak("\(intValue)")
                        }
                    }
                }
            } else {
                timer.invalidate()
                startWavePlayback()
            }
        }
    }
    
    private func startWavePlayback() {
        isCountdown = false
        isInterval = false
        progressWave = 1
        progressSecond = 0
        
        // Wave開始アナウンス
        let waveStartMsg = appStrings.waveStart(1)
        Task { @MainActor in
            ttsManager.speak(waveStartMsg)
        }
        addToLog("Wave 1: \(waveStartMsg)")
        
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            progressSecond += 1
            
            // 2秒ごとにテキストを読み上げ（100秒から2秒ごと）
            if progressSecond % 2 == 0 {
                let intervalIndex = (100 - progressSecond) / 2
                let textIndex = (progressWave - 1) * 50 + (50 - intervalIndex - 1)
                
                if let text = waveTexts[textIndex], !text.isEmpty {
                    Task { @MainActor in
                        ttsManager.speak(text)
                        currentAnnouncement = text
                        addToLog("[\(100 - progressSecond)秒] \(text)")
                    }
                }
            }
            
            // Wave終了チェック
            if progressSecond >= 100 {
                if progressWave < waveCount {
                    // 次のWaveへ
                    startInterval()
                } else {
                    // 全Wave完了
                    completePlayback()
                }
                timer.invalidate()
            }
        }
    }
    
    private func startInterval() {
        isInterval = true
        countdownRemaining = 19.5  // Wave間は19.5秒
        
        // Wave終了アナウンス
        let waveEndMsg = appStrings.waveEnd(progressWave)
        Task { @MainActor in
            ttsManager.speak(waveEndMsg)
        }
        addToLog("Wave \(progressWave) 終了: \(waveEndMsg)")
        currentAnnouncement = ""
        
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if countdownRemaining > 0 {
                countdownRemaining -= 0.5
                
                // 3, 2, 1のカウント読み上げ
                if countdownRemaining <= 3 && countdownRemaining > 0 {
                    let intValue = Int(countdownRemaining)
                    if countdownRemaining == Double(intValue) {
                        Task { @MainActor in
                            ttsManager.speak("\(intValue)")
                        }
                    }
                }
            } else {
                timer.invalidate()
                // 次のWave開始
                progressWave += 1
                progressSecond = 0
                isInterval = false
                
                let nextWaveMsg = appStrings.waveStart(progressWave)
                Task { @MainActor in
                    ttsManager.speak(nextWaveMsg)
                    addToLog("Wave \(progressWave): \(nextWaveMsg)")
                }
                startWavePlayback()
            }
        }
    }
    
    private func completePlayback() {
        playbackTimer?.invalidate()
        let completionMsg = appStrings.allClear
        Task { @MainActor in
            ttsManager.speak(completionMsg)
        }
        addToLog("完了: \(completionMsg)")
        currentAnnouncement = completionMsg
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            dismiss()
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        ttsManager.stop()
        dismiss()
    }
    
    private func getCurrentText() -> String? {
        // 2秒ごとのインデックスで取得（100秒から2秒ごと）
        let intervalIndex = (100 - progressSecond) / 2
        let textIndex = (progressWave - 1) * 50 + (50 - intervalIndex - 1)
        return waveTexts[textIndex]
    }
    
    private func addToLog(_ message: String) {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp)
        announcementLog.append("[\(timeString)] \(message)")
        
        // ログが多すぎる場合は古いものを削除
        if announcementLog.count > 50 {
            announcementLog.removeFirst()
        }
    }
}

#Preview {
    PlaybackView(
        title: "テストリスト",
        waveTexts: [
            10: "テスト1",
            30: "テスト2",
            50: "テスト3"
        ]
    )
    .environmentObject(AppStrings.shared)
}