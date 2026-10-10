//
//  SalmonRunGuideView.swift
//  SRBTCG
//
//  サーモンランガイド画面
//

import SwiftUI

struct SalmonRunGuideView: View {
    @State private var selectedHazard = 0
    @State private var showSettings = false
    @State private var showPlayConfirmation = false
    /// 再生画面を出しているか
    @State private var showPlaybackView = false
    @AppStorage("announceSpawnDirectionChange") private var announceSpawnDirectionChange = true // 湧き方向変更アナウンス設定
    @EnvironmentObject var appStrings: AppStrings
    
    /// いま選んでいるキケン度
    private var hazard: HazardLevel {
        HazardLevel(rawValue: selectedHazard) ?? .low
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // MainViewと同じグラデーション背景
                AnimatedGradientBackground()

                LiquidShapeView()
                    .ignoresSafeArea()
                    .opacity(0.3)

                // 広告バナーのぶん縦が狭くなるので、ブロック間は詰めている。
                // 上端はナビゲーションバーのすぐ下から始める。
                VStack(spacing: 10) {
                    // キケン度選択
                    VStack(alignment: .leading, spacing: 10) {
                        Text(appStrings.hazardLevel)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            // ナビゲーションバーに重ならない程度に空ける
                            .padding(.top, 8)

                        Picker("", selection: $selectedHazard) {
                            ForEach(HazardLevel.allCases) { level in
                                Text(level.label)
                                    .tag(level.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .background(AppColors.surface)
                        .cornerRadius(8)
                        // SwiftUIのPickerは .font を受け付けないので、
                        // UIKit側の見た目を指定する。
                        // appearance はアプリ全体に効くが、
                        // セグメントを使っているのはこの画面だけ。
                        .onAppear {
                            let font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                            UISegmentedControl.appearance()
                                .setTitleTextAttributes([.font: font], for: .normal)
                            UISegmentedControl.appearance()
                                .setTitleTextAttributes([.font: font], for: .selected)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 湧き方向変更アナウンス設定
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("湧き方向変更アナウンス")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $announceSpawnDirectionChange)
                                .labelsHidden()
                                .tint(AppColors.primary)
                        }
                        
                        // 間隔はキケン度によって変わる（72 ÷ n 秒）
                        Text("※ \(hazard.rangeText) では約\(hazard.spawnDirectionIntervalText)ごとにアナウンスされます")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(AppColors.surface.opacity(0.5))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // 説明文とタイミング一覧はひと続きのものなので、
                    // 親のspacingを挟まずに近づける
                    VStack(spacing: 6) {
                        // 「キケン度」と並ぶ見出しとして扱う。
                        // 下の一覧を見れば流れるタイミングは分かるので、
                        // 何の表かだけを示す短い見出しにしている
                        Text("音声アナウンス内容")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // タイミング一覧だけをスクロールさせる。
                        // キケン度MAXでは項目が15個近くになり画面に収まらないが、
                        // キケン度の選択と再生ボタンは常に触れる位置に置いておきたい。
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
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
                        }
                        .background(AppColors.surface.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    // 一覧だけが伸び縮みし、下の再生ボタンは常に同じ位置に来る
                    .frame(maxHeight: .infinity)

                    // 球体の再生/停止ボタン（位置は固定）
                    HStack {
                        Spacer()

                        // 進行中の表示と停止は再生画面が受け持つので、
                        // ここは開始のきっかけだけを出す
                        SphericalButton(
                            icon: "play.fill",
                            color: AppColors.primary,
                            action: { showPlayConfirmation = true }
                        )
                        
                        Spacer()
                    }
                    .padding(.bottom, 20)

                    // 購入済み・お試し期間中は何も描かれない
                    AdBannerView()
                }
            }
            .navigationTitle("ビッグラン/通常")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.surface.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                plainToolbarItem(placement: .navigationBarTrailing) {
                    InfoToolbarButton { showSettings = true }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appStrings)
            }
            .alert("再生開始タイミング", isPresented: $showPlayConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("再生開始") {
                    showPlaybackView = true
                }
            } message: {
                Text("地面に着地したタイミングで再生を開始してください。")
            }
            // バチコンと同じ再生画面を使う。
            // 読み上げる中身が違うだけで、Wave進行の見せ方は共通。
            .fullScreenCover(isPresented: $showPlaybackView) {
                PlaybackView(
                    mode: .guide(hazard: hazard),
                    isPresented: $showPlaybackView
                )
                .environmentObject(appStrings)
            }
        }
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
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(isDisabled ? AppColors.golden.opacity(0.3) : AppColors.golden)
                .frame(width: 102, alignment: .leading)
                .strikethrough(isDisabled, color: AppColors.textSecondary)
            
            // メッセージ
            Text(message)
                .font(.system(size: 20))
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