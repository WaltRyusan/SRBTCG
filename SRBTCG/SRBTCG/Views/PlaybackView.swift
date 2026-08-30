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
    /// 再生を開始するWave（インターバルがズレたときの復帰用）
    var startWave: Int = 1
    let waveCount: Int = WaveTiming.waveCount
    /// 実時刻ベースの経過時間
    @State private var clock = ElapsedClock()
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appStrings: AppStrings
    @State private var isPlaying = true
    /// 再生停止の確認
    @State private var showStopConfirmation = false
    @State private var progressWave = 0
    @State private var progressSecond = 0
    // 初期値に 14.5 がベタ書きされていた。3秒短縮した後の値と食い違い、
    // 画面が出た最初の1フレームだけ古い秒数が見えていた。
    @State private var countdownRemaining: Double = WaveTiming.initialCountdown
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

    /// 再生中のときだけ読み上げる
    ///
    /// speakはTaskで1フレーム後に走るため、停止ボタンを押した時点で
    /// 積まれていた読み上げが stop() の後に実行され、
    /// 止めたはずの音声が続けて流れていた。
    private func announce(_ text: String) {
        Task { @MainActor in
            guard isPlaying else { return }
            ttsManager.speak(text)
        }
    }

    private func startPlayback() {
        // 初期TTS設定
        ttsManager.rate = 0.5
        ttsManager.pitch = 0.8
        ttsManager.volume = 1.0

        // 開始アナウンス
        announce(appStrings.startingGuide)

        // カウントダウン開始
        startCountdown(duration: WaveTiming.initialCountdown, isInterval: false) {
            progressWave = startWave
            startWavePlayback()
        }
    }
    
    /// カウントダウン（Wave1開始前 / Wave間インターバル共通）
    ///
    /// 経過時間はElapsedClockで実時刻から求める。
    /// 以前はタイマー発火ごとに残り秒数を引いていたため、
    /// TTS読み上げで発火が遅れるとその分そのままズレていた。
    private func startCountdown(duration: TimeInterval, isInterval: Bool, then next: @escaping () -> Void) {
        self.isCountdown = !isInterval
        self.isInterval = isInterval
        clock.reset()
        countdownRemaining = duration
        var lastSpokenSecond = Int(ceil(duration)) + 1

        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: WaveTiming.tick, repeats: true) { timer in
            let remaining = max(0, duration - clock.elapsed)
            countdownRemaining = remaining

            // 3・2・1 の読み上げ。同じ秒を二重に読まないよう記録する
            let currentSecond = Int(ceil(remaining))
            if currentSecond <= WaveTiming.countdownSpeakFrom,
               currentSecond > 0,
               currentSecond < lastSpokenSecond {
                lastSpokenSecond = currentSecond
                announce("\(currentSecond)")
            }

            if remaining <= 0 {
                timer.invalidate()
                guard isPlaying else { return }
                next()
            }
        }
    }

    /// 現在の progressWave を再生する
    /// 呼び出し前に progressWave を設定しておくこと
    private func startWavePlayback(announceStart: Bool = true) {
        isCountdown = false
        isInterval = false
        progressSecond = 0
        clock.reset()

        if announceStart {
            let waveStartMsg = appStrings.waveStart(progressWave)
            announce(waveStartMsg)
            addToLog("Wave \(progressWave): \(waveStartMsg)")
        }

        var lastSpokenSlot = -1

        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: WaveTiming.tick, repeats: true) { timer in
            let elapsed = min(clock.elapsed, WaveTiming.waveDuration)
            progressSecond = Int(elapsed)

            // 2秒ごとの枠に入ったら、その枠のテキストを一度だけ読み上げる
            let slot = Int(elapsed / WaveTiming.textInterval)
            if slot > lastSpokenSlot, slot < WaveTiming.slotsPerWave {
                lastSpokenSlot = slot
                let textIndex = (progressWave - 1) * WaveTiming.slotsPerWave + slot
                if let text = waveTexts[textIndex], !text.isEmpty {
                    announce(text)
                    currentAnnouncement = text
                    addToLog("[残り\(Int(WaveTiming.waveDuration) - progressSecond)秒] \(text)")
                }
            }

            if clock.elapsed >= WaveTiming.waveDuration {
                timer.invalidate()
                guard isPlaying else { return }
                if progressWave < WaveTiming.waveCount {
                    startInterval()
                } else {
                    completePlayback()
                }
            }
        }
    }

    private func startInterval() {
        let waveEndMsg = appStrings.waveEnd(progressWave)
        announce(waveEndMsg)
        addToLog("Wave \(progressWave) 終了: \(waveEndMsg)")
        currentAnnouncement = ""

        startCountdown(duration: WaveTiming.interval, isInterval: true) {
            progressWave += 1
            let nextWaveMsg = appStrings.waveStart(progressWave)
            announce(nextWaveMsg)
            addToLog("Wave \(progressWave): \(nextWaveMsg)")
            // ここでアナウンス済みなので再度読み上げない
            startWavePlayback(announceStart: false)
        }
    }

    private func completePlayback() {
        playbackTimer?.invalidate()
        let completionMsg = appStrings.allClear
        announce(completionMsg)
        addToLog("完了: \(completionMsg)")
        currentAnnouncement = completionMsg

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            dismiss()
        }
    }

    private func stopPlayback() {
        // 先にフラグを倒す。
        // タイマーを止めても、既に積まれた読み上げTaskは後から走るため、
        // announce側で弾けるようにしておく必要がある。
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        ttsManager.stop()
        dismiss()
    }
    
    private func getCurrentText() -> String? {
        // 2秒ごとのインデックスで取得（100秒から2秒ごと）
        let slot = progressSecond / Int(WaveTiming.textInterval)
        let textIndex = (progressWave - 1) * WaveTiming.slotsPerWave + slot
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