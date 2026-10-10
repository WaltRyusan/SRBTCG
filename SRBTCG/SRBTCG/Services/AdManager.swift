//
//  AdManager.swift
//  SRBTCG
//
//  広告管理（Google AdMob）
//

import SwiftUI
import Combine
import StoreKit
import GoogleMobileAds
import AppTrackingTransparency

/// 広告管理クラス
///
/// 表示するのはバナーと全画面広告の2種類。
/// お試し期間（trialCount 回）を過ぎてから、かつ広告除去を購入していない場合だけ出す。
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    // 広告ユニットID
    //
    // DEBUGビルドはGoogleのテストIDを使う。
    // 自分の本番IDに開発中の端末からアクセスすると無効なトラフィックとみなされ、
    // AdMobアカウントが停止される恐れがあるため。
    #if DEBUG
    private let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    // ⚠️ 提出前に AdMob 管理画面から取得した本番IDへ差し替える。
    //    Info.plist の GADApplicationIdentifier も併せて差し替えること。
    private let bannerAdUnitID = "ca-app-pub-XXXXX/XXXXX"
    private let interstitialAdUnitID = "ca-app-pub-XXXXX/XXXXX"
    #endif
    
    // 状態管理
    @Published var isBannerLoaded = false
    
    // 起動回数とレビュー催促の管理は AppLaunchManager が持つ。
    // 以前はここで「バチコン再生の完了回数」を数えていたが、
    // 連続で再生したいときに毎回割り込まれて使いづらかった。
    
    /// 初期化済みか
    ///
    /// init と SRBTCGApp の onAppear の両方から呼ばれていたため、
    /// 起動のたびに二重に走っていた。
    private var isInitialized = false

    /// 広告を出さない状態か（購入済み、またはお試し期間中）
    ///
    /// 購入状態の確認が非同期なので、判定結果をここに持って
    /// ビューからは同期的に見られるようにしている。
    @Published private(set) var isAdFree = true

    private var bannerView: BannerView?
    private var interstitialAd: InterstitialAd?

    private override init() {
        super.init()
        initialize()
    }

    /// 初期化（複数回呼ばれても一度しか実行しない）
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        requestTrackingThenStartSDK()
    }

    /// ATTの応答を待ってから広告SDKを開始する
    ///
    /// IDFAが使えるかどうかが確定する前にSDKを開始すると、
    /// 最初の広告リクエストがトラッキング不可の扱いで飛んでしまう。
    /// 起動と同時にダイアログを出すと画面の描画に重なるので1秒遅らせる。
    private func requestTrackingThenStartSDK() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                // 許可・拒否のどちらでもSDKは開始する。
                // 拒否された場合は非パーソナライズ広告に切り替わるだけ。
                MobileAds.shared.start { _ in
                    Task { @MainActor in
                        await self.refreshAdFreeState()
                        self.loadAdsIfAllowed()
                    }
                }
            }
        }
    }

    /// 広告を出さない状態か
    ///
    /// 購入状態の確認が非同期なので、判定結果をここに持って
    /// ビューからは同期的に見られるようにしている。
    @MainActor
    func refreshAdFreeState() async {
        isAdFree = !(await shouldShowAds())
    }

    /// 広告を出す状態のときだけ読み込む
    ///
    /// 表示側だけで抑止すると、広告を出さないのに広告リクエストとIDFAの送信は
    /// 続いてしまう。購入した人に対して筋が通らないのでリクエスト自体を送らない。
    @MainActor
    private func loadAdsIfAllowed() {
        guard !isAdFree else { return }
        loadBanner()
        loadInterstitial()
    }

    /// 購入が成立したときに呼ぶ。読み込み済みの広告を捨てる。
    @MainActor
    func discardLoadedAds() {
        bannerView?.removeFromSuperview()
        bannerView = nil
        interstitialAd = nil
        isAdFree = true
    }

    // MARK: - 読み込み

    @MainActor
    private func loadBanner() {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = bannerAdUnitID

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        banner.rootViewController = root

        bannerView = banner
        banner.load(Request())
    }

    @MainActor
    private func loadInterstitial() {
        InterstitialAd.load(with: interstitialAdUnitID, request: Request()) { [weak self] ad, error in
            guard error == nil else { return }
            Task { @MainActor in
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
            }
        }
    }
    
    // MARK: - 表示可否

    /// 広告を表示すべきか（お試し期間と課金状態を見る）
    func shouldShowAds() async -> Bool {
        // 新規ユーザーの保護期間中は広告なし
        if await AppLaunchManager.shared.isFreeAdsPeriod {
            return false
        }

        // 広告非表示購入済みなら広告なし
        return await !PurchaseManager.shared.hasAdFree()
    }
    
    // MARK: - Banner Ad

    /// 読み込み済みのバナー。SwiftUI側から包んで使う。
    @MainActor
    func currentBannerView() -> BannerView? { bannerView }

    // MARK: - Interstitial Ad

    /// 全画面広告を表示する
    ///
    /// 出す条件を満たさないときは何もしない。
    @MainActor
    func showInterstitialAd() async {
        guard await shouldShowAds() else { return }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController,
              let ad = interstitialAd else { return }

        ad.present(from: root)
        interstitialAd = nil  // 使い切ったので次を読み込む（delegateで再取得）
    }
    
    // リワード広告は実装しない。
    //
    // 以前は「録音を使うにはリワード広告を見る」という設計のコードがあったが、
    // AdMob はリワード広告をオプトイン（報酬と引き換えに見るかを選ばせる）で
    // 出すことを求めており、機能を使う条件にするのはポリシーに反する。
    // https://developers.google.com/admob/ios/rewarded
    //
    // 録音は使う人が限られるコア機能で、ここを制限すると
    // 熱心なユーザーほど離れてしまう。収益はバナーと起動時の全画面広告で取る。

    // MARK: - Event Handlers

    /// 起動時に全画面広告を出す（1日1回まで）
    ///
    /// 再生の前後では出さない。
    /// Waveを続けて回したいときに毎回割り込まれると使い物にならないため。
    @MainActor
    func onAppLaunch() async {
        guard AppLaunchManager.shared.shouldShowInterstitial else { return }
        // 起動直後は画面の描画と重なるので少し待つ
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await showInterstitialAd()
        AppLaunchManager.shared.recordInterstitialShown()
    }

}
// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    /// 閉じられたら次の全画面広告を用意しておく
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            guard !self.isAdFree else { return }
            self.loadInterstitial()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            guard !self.isAdFree else { return }
            self.loadInterstitial()
        }
    }
}

// MARK: - バナーを置くビュー

/// 画面下部などに差し込むバナー。
///
/// 購入済み・お試し期間中・未読み込みのときは何も描かないので、
/// 置いておくだけでよい。
struct AdBannerView: View {
    @StateObject private var adManager = AdManager.shared
    @State private var banner: BannerView?

    var body: some View {
        Group {
            if !adManager.isAdFree, banner != nil {
                BannerContainer(banner: banner)
                    .frame(height: 50)
            }
        }
        .task {
            await adManager.refreshAdFreeState()
            // 読み込みは初期化時に始まっている。取れていれば受け取る。
            banner = adManager.currentBannerView()
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    let banner: BannerView?

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        if let banner {
            banner.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                banner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
