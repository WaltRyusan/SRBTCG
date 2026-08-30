//
//  AdManager.swift
//  SRBTCG
//
//  広告管理（Google AdMob）- スタブ実装
//

import SwiftUI
import Combine
import StoreKit

/// 広告管理クラス（スタブ実装）
///
/// 実際の広告機能を実装する場合：
/// 1. Google Mobile Ads SDKを追加（SPMまたはCocoaPods）
/// 2. Info.plistにGADApplicationIdentifierを追加
/// 3. このファイルのTODOコメント部分を実装
///
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    // 広告ID（本番環境では実際のIDに変更）
    #if DEBUG
    private let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // テスト用
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313" // テスト用
    #else
    private let bannerAdUnitID = "YOUR_BANNER_AD_UNIT_ID"
    private let interstitialAdUnitID = "YOUR_INTERSTITIAL_AD_UNIT_ID"
    private let rewardedAdUnitID = "YOUR_REWARDED_AD_UNIT_ID"
    #endif
    
    // 状態管理
    @Published var isBannerLoaded = false
    @Published var rewardedPending = false
    
    // SharedPreferencesキー
    private let usageCountKey = "adManager_usageCount"
    private let reviewShownKey = "adManager_reviewShown"
    private let rewardPendingKey = "adManager_rewardPending"
    
    // お試し回数
    private let trialCount = 3
    
    /// 初期化済みか
    ///
    /// init と SRBTCGApp の onAppear の両方から呼ばれていたため、
    /// 起動のたびに二重に走っていた。
    private var isInitialized = false

    private override init() {
        super.init()
        initialize()
    }

    /// 初期化（複数回呼ばれても一度しか実行しない）
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        // TODO: Google Mobile Ads SDK追加後、以下を実装
        // GADMobileAds.sharedInstance().start { _ in
        //     print("AdMob initialized")
        // }
        
        // リワード未視聴状態をロード
        rewardedPending = UserDefaults.standard.bool(forKey: rewardPendingKey)
    }
    
    // MARK: - Usage Count Management
    
    /// 使用回数を取得
    func getUsageCount() -> Int {
        UserDefaults.standard.integer(forKey: usageCountKey)
    }
    
    /// 使用回数をインクリメント
    @discardableResult
    func incrementUsageCount() -> Int {
        let count = getUsageCount() + 1
        UserDefaults.standard.set(count, forKey: usageCountKey)
        return count
    }
    
    /// お試し期間中か
    func isTrialPeriod() -> Bool {
        getUsageCount() < trialCount
    }
    
    /// 広告を表示すべきか（課金状態も考慮）
    func shouldShowAds() async -> Bool {
        // お試し期間中は広告なし
        if isTrialPeriod() {
            return false
        }
        
        // 広告非表示購入済みなら広告なし
        return await !PurchaseManager.shared.hasAdFree()
    }
    
    // MARK: - Banner Ad (Stub)
    
    /// バナー広告ビューを作成（スタブ）
    func createBannerView() -> AnyView? {
        // TODO: 実際のバナー広告実装
        // 現在はプレースホルダーを返す
        return AnyView(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 50)
                .overlay(
                    Text("広告スペース")
                        .foregroundColor(.gray)
                )
        )
    }
    
    // MARK: - Interstitial Ad (Stub)
    
    /// インタースティシャル広告を表示（スタブ）
    func showInterstitialAd() async {
        guard await shouldShowAds() else { return }
        
        // TODO: 実際のインタースティシャル広告を表示
        print("Interstitial ad would be shown here")
    }
    
    // MARK: - Rewarded Ad (Stub)
    
    /// リワード広告を表示（スタブ）
    func showRewardedAd() async -> Bool {
        guard await shouldShowAds() else {
            return true // 課金済みなら常に成功扱い
        }
        
        // TODO: 実際のリワード広告を表示
        print("Rewarded ad would be shown here")
        
        // スタブ実装：常に成功を返す
        rewardedPending = false
        UserDefaults.standard.set(false, forKey: rewardPendingKey)
        return true
    }
    
    /// リワード未視聴状態を設定
    func setRewardedPending(_ pending: Bool) {
        rewardedPending = pending
        UserDefaults.standard.set(pending, forKey: rewardPendingKey)
    }
    
    // MARK: - Event Handlers
    
    /// バチコン再生完了時
    func onBigRunPlaybackCompleted() async {
        let count = incrementUsageCount()
        
        // 3回目完了時はレビュー促進
        if count == trialCount {
            await showReviewPrompt()
        }
        // 4回目以降はインタースティシャル広告
        else if count > trialCount {
            await showInterstitialAd()
        }
    }
    
    /// バチコン録音完了時
    func onBigRunRecordingCompleted() async {
        guard !isTrialPeriod() else { return }
        
        // リワード広告を表示して視聴必須に
        setRewardedPending(true)
        _ = await showRewardedAd()
    }
    
    /// サーモンランガイド使用時
    func onSalmonRunGuideUsed() async {
        guard !isTrialPeriod() else { return }
        await showInterstitialAd()
    }
    
    // MARK: - Review Prompt
    
    /// レビュー促進を表示
    @MainActor
    private func showReviewPrompt() async {
        // iOS 18以降とそれ以前で処理を分岐
        if #available(iOS 18.0, *) {
            // iOS 18以降
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        } else {
            // iOS 17以前
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
        UserDefaults.standard.set(true, forKey: reviewShownKey)
    }
}