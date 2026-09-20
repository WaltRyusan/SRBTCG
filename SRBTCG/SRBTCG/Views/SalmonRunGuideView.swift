//
//  SalmonRunGuideView.swift
//  SRBTCG
//
//  サーモンランガイド画面
//

import SwiftUI

struct SalmonRunGuideView: View {
    @State private var selectedHazard = 0
    @State private var isPlaying = false
    @State private var isWaitingForTap = false
    @State private var playbackTimer: Timer?
    @State private var currentSecond = 100
    @State private var showSettings = false
    @State private var showPlayConfirmation = false
    @State private var isInWaitPeriod = false // Wave開始前の待機時間フラグ
    @State private var waitTimeRemaining = 13 // 待機時間カウンタ
    @State private var currentWaveNumber = 1 // 現在のWave番号
    @AppStorage("announceSpawnDirectionChange") private var announceSpawnDirectionChange = true // 湧き方向変更アナウンス設定
    @StateObject private var ttsManager = TTSManager.shared
    @EnvironmentObject var appStrings: AppStrings
    
    /// いま選んでいるキケン度
    private var hazard: HazardLevel {
        HazardLevel(rawValue: selectedHazard) ?? .low
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MainViewと同じグラデーション背景
                AnimatedGradientBackground()
                
                LiquidShapeView()
                    .ignoresSafeArea()
                    .opacity(0.3)
                
                VStack(spacing: 16) {
                    // キケン度選択
                    VStack(alignment: .leading, spacing: 10) {
                        Text(appStrings.hazardLevel)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                            // ナビゲーションバーの下に潜り込んで文字が欠けていたため、
                            // バーの高さぶんの余白を確保する
                            .padding(.top, 52)

                        Picker("", selection: $selectedHazard) {
                            ForEach(HazardLevel.allCases) { level in
                                Text(level.label)
                                    .tag(level.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .background(AppColors.surface)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // 湧き方向変更アナウンス設定
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("湧き方向変更アナウンス")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $announceSpawnDirectionChange)
                                .labelsHidden()
                                .tint(AppColors.primary)
                        }
                        
                        // 間隔はキケン度によって変わる（72 ÷ n 秒）
                        Text("※ \(hazard.rangeText) では約\(hazard.spawnDirectionIntervalText)ごとにアナウンスされます")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(AppColors.surface.opacity(0.5))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // 説明文
                    // 広告バナーのぶん縦が狭くなるので、上下の間隔を詰めている
                    Text("※ 以下のタイミングで音声アナウンスが流れます")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, -4)
                    
                    // タイミング表示（高さを拡張してスクロールを最小限に）
                    VStack(alignment: .leading, spacing: 8) {
                        // タイミングリスト
                        ForEach(hazard.timings, id: \.second) { timing in
                            TimingRow(
                                seconds: timing.second,
                                messageKey: timing.key,
                                appStrings: appStrings,
                                isDisabled: timing.key.starts(with: "spawnDirectionChange") && !announceSpawnDirectionChange
                            )
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(AppColors.surface.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity)
                    
                    // 球体の再生/停止ボタン
                    HStack {
                        Spacer()
                        
                        SphericalButton(
                            icon: isPlaying ? "stop.fill" : "play.fill",
                            color: isPlaying ? AppColors.danger : AppColors.primary,
                            action: {
                                if isPlaying {
                                    // 停止（ダイアログなし）
                                    stopPlayback()
                                } else {
                                    // 再生確認ダイアログを表示
                                    showPlayConfirmation = true
                                }
                            }
                        )
                        
                        Spacer()
                    }
                    .padding(.bottom, 100) // タブバーの分
                }
            }
            .navigationTitle("ビッグラン/通常")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.surface.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appStrings)
            }
            .alert("再生開始タイミング", isPresented: $showPlayConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("再生開始") {
                    togglePlayback()
                }
            } message: {
                Text("地面に着地したタイミングで再生を開始してください。")
            }
        }
    }
    
    private func togglePlayback() {
        // ダイアログから呼ばれた時は直接再生開始
        startActualPlayback()
    }
    
    private func startActualPlayback() {
        isWaitingForTap = false
        isPlaying = true
        isInWaitPeriod = true
        waitTimeRemaining = 13
        currentSecond = 100
        
        // タイマー開始（待機時間から）
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isInWaitPeriod {
                // 待機時間中
                waitTimeRemaining -= 1
                if waitTimeRemaining <= 0 {
                    // 待機時間終了、Wave開始
                    isInWaitPeriod = false
                    ttsManager.speak("Wave\(currentWaveNumber)開始")
                }
            } else {
                // Wave進行中
                currentSecond -= 1
                
                // 現在の秒数に対応するアナウンスをチェック
                checkAndAnnounce()
                
                // 終了チェック（Wave繰り返し）
                if currentSecond <= 0 {
                    // Waveクリアアナウンス後、次のWaveへ
                    currentWaveNumber += 1
                    if currentWaveNumber > 5 {
                        currentWaveNumber = 1 // Wave5の後はWave1に戻る
                    }
                    isInWaitPeriod = true
                    waitTimeRemaining = 13
                    currentSecond = 100
                }
            }
        }
    }
    
    private func checkAndAnnounce() {
        for timing in hazard.timings {
            if timing.second == currentSecond {
                // アナウンスを実行
                switch timing.key {
                case let key where key.starts(with: "spawnDirectionChange"):
                    // 湧き方向変更アナウンスが有効な場合のみ
                    if announceSpawnDirectionChange {
                        ttsManager.speak(appStrings.spawnDirectionChange)
                    }
                case "thirtySecondsLeft":
                    ttsManager.speak("納品数を意識")
                case "finalSpawn":
                    ttsManager.speak(appStrings.finalSpawn)
                case "waveClear":
                    ttsManager.speak("Wave\(currentWaveNumber)クリア")
                default:
                    break
                }
                break
            }
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        isWaitingForTap = false
        isInWaitPeriod = false
        waitTimeRemaining = 13
        currentWaveNumber = 1
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentSecond = 100
        ttsManager.stop()
    }
}

struct TimingRow: View {
    let seconds: Int
    let messageKey: String
    let appStrings: AppStrings
    var isDisabled: Bool = false
    
    var message: String {
        switch messageKey {
        case let key where key.starts(with: "spawnDirectionChange"):
            // 湧き方向変更（15秒ごと）
            return appStrings.spawnDirectionChange
        case "thirtySecondsLeft":
            return appStrings.thirtySecondsLeft
        case "finalSpawn":
            return appStrings.finalSpawn
        case "waveClear":
            return appStrings.waveClear
        default:
            return messageKey
        }
    }
    
    var displayTime: String {
        // カウントダウン形式で表示（残り秒数）
        if seconds == 0 {
            return "終了"
        } else {
            return "残り\(seconds)秒"
        }
    }
    
    var iconName: String {
        switch messageKey {
        case let key where key.starts(with: "spawnDirectionChange"):
            return "arrow.left.arrow.right"
        case "thirtySecondsLeft":
            return "timer"
        case "finalSpawn":
            return "exclamationmark.triangle.fill"
        case "waveClear":
            return "checkmark.circle.fill"
        default:
            return "circle"
        }
    }
    
    var iconColor: Color {
        switch messageKey {
        case let key where key.starts(with: "spawnDirectionChange"):
            return AppColors.primary
        case "thirtySecondsLeft":
            return AppColors.golden
        case "finalSpawn":
            return AppColors.danger
        case "waveClear":
            return AppColors.accent
        default:
            return AppColors.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // アイコン
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(isDisabled ? iconColor.opacity(0.3) : iconColor)
                .frame(width: 24)
            
            // タイムスタンプ（カウントダウン形式）
            Text(displayTime)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isDisabled ? AppColors.golden.opacity(0.3) : AppColors.golden)
                .frame(width: 80, alignment: .leading)
                .strikethrough(isDisabled, color: AppColors.textSecondary)
            
            // メッセージ
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(isDisabled ? AppColors.textPrimary.opacity(0.3) : AppColors.textPrimary)
                .strikethrough(isDisabled, color: AppColors.textSecondary)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SalmonRunGuideView()
        .environmentObject(AppStrings.shared)
}