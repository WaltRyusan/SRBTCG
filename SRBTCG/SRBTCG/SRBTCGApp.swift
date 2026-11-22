//
//  SRBTCGApp.swift
//  SRBTCG
//
//  Created by Ryuzo Hiruma on 2026/05/10.
//

import SwiftUI
import AVFoundation

@main
struct SRBTCGApp: App {
    @StateObject private var appStrings = AppStrings.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var adManager = AdManager.shared
    @Environment(\.scenePhase) private var scenePhase
    /// 起動時の全画面広告を待つ読み込み画面を出しているか
    ///
    /// 最初から出しておき、広告を出す条件を満たさない起動では HomeView の onAppear ですぐ外す。
    /// あとから被せると、本編の画面が見えてから広告が出ることになる。
    @State private var isWaitingLaunchAd = true
    
    init() {
        // オーディオセッションの設定
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
        } catch {
            kDebugErrorPrint(error, message: "オーディオセッション設定エラー")
        }
        
        // ナビゲーションバーの外観設定
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.surface)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // タブバーの外観設定
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.surface)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = UIColor(AppColors.primary) // アクティブ色をオレンジに
        
        kDebugModePrint("アプリケーション初期化完了")
    }
    
    var body: some Scene {
        WindowGroup {
            if appStrings.needsLanguageSelection {
                LanguageSelectView()
                    .environmentObject(appStrings)
                    .environmentObject(purchaseManager)
                    .environmentObject(adManager)
                    .persistentSystemOverlays(.hidden) // フルスクリーン対応
                    // 独自の配色（AppColors）を使っているため、
                    // システムがライトモードだと背景だけ明るくなり文字が読めなくなる。
                    // 端末の設定にかかわらずダークで固定する。
                    .preferredColorScheme(.dark)
            } else {
                HomeView()
                    .environmentObject(appStrings)
                    .environmentObject(purchaseManager)
                    .environmentObject(adManager)
                    .overlay {
                        if isWaitingLaunchAd {
                            LaunchAdLoadingView()
                        }
                    }
                    .persistentSystemOverlays(.hidden) // フルスクリーン対応
                    // 独自の配色（AppColors）を使っているため、
                    // システムがライトモードだと背景だけ明るくなり文字が読めなくなる。
                    // 端末の設定にかかわらずダークで固定する。
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // 課金マネージャー初期化
                        Task {
                            await purchaseManager.loadProducts()
                            kDebugModePrint("課金商品ロード完了")
                        }
                        
                        // 広告マネージャー初期化
                        adManager.initialize()
                        kDebugModePrint("広告マネージャー初期化完了")

                        // 起動回数を数える。
                        // レビュー催促と広告の解禁はこの回数で決まる。
                        AppLaunchManager.shared.onAppLaunch()

                        // 起動時の全画面広告（アプリ起動広告、1日1回まで）。
                        // 読み込み画面を出したまま、読み込めた場合だけ表示し、閉じられるまで待つ。
                        // 本編の画面に入ってからは出さない。
                        // 条件を満たさない起動では読み込み画面をすぐ外す。
                        if adManager.shouldWaitForLaunchAd {
                            Task {
                                await adManager.showAppOpenAdOnLaunch()
                                isWaitingLaunchAd = false
                            }
                        } else {
                            isWaitingLaunchAd = false
                        }
                    }
                    // 全画面広告は起動時と復帰時だけ。1日1回に収める。
                    // 画面の遷移では出さない。操作の途中で割り込まれると使い物にならない。
                    .onChange(of: scenePhase) { _, phase in
                        Task { await adManager.handleScenePhase(phase) }
                    }
            }
        }
    }
}

/// 起動時の全画面広告を待つ間に出す読み込み画面
///
/// このアプリには専用の起動画面が無いので、本編と同じ背景に小さなインジケータだけを出す。
private struct LaunchAdLoadingView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            ProgressView()
        }
    }
}
