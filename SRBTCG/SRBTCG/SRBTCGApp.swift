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
            } else {
                HomeView()
                    .environmentObject(appStrings)
                    .environmentObject(purchaseManager)
                    .environmentObject(adManager)
                    .persistentSystemOverlays(.hidden) // フルスクリーン対応
                    .onAppear {
                        // 課金マネージャー初期化
                        Task {
                            await purchaseManager.loadProducts()
                            kDebugModePrint("課金商品ロード完了")
                        }
                        
                        // 広告マネージャー初期化
                        adManager.initialize()
                        kDebugModePrint("広告マネージャー初期化完了")
                    }
            }
        }
    }
}
