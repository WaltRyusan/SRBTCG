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
    fileprivate let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    private let appOpenAdUnitID = "ca-app-pub-3940256099942544/5575463023"
    #else
    // ⚠️ 提出前に AdMob 管理画面から取得した本番IDへ差し替える。
    //    Info.plist の GADApplicationIdentifier も併せて差し替えること。
    fileprivate let bannerAdUnitID = "ca-app-pub-XXXXX/XXXXX"
    private let appOpenAdUnitID = "ca-app-pub-XXXXX/XXXXX"
    #endif
    
    // 状態管理
    
    // 起動回数とレビュー催促の管理は AppLaunchManager が持つ。
    // 以前はここで「バチコン再生の完了回数」を数えていたが、
    // 連続で再生したいときに毎回割り込まれて使いづらかった。
    
    /// 初期化済みか
    ///
    /// init と SRBTCGApp の onAppear の両方から呼ばれていたため、
    /// 起動のたびに二重に走っていた。
    private var isInitialized = false

    /// 買い切りで広告を消しているか
    ///
    /// 購入状態の確認が非同期なので、判定結果をここに持って
    /// ビューからは同期的に見られるようにしている。
    @Published private(set) var isAdsRemoved = true

    /// 画面をふさぐ広告を出さない状態か
    ///
    /// 購入済みか、新規ユーザーのお試し期間中。
    /// バナーはこの判定を使わない。場所を取るだけで操作を妨げないので
    /// 最初から出す。あとから急に現れるほうが「広告が増えた」と感じさせる。
    @Published private(set) var isInterstitialFree = true

    private var appOpenAd: AppOpenAd?
    /// 広告を読み込んだ時刻。アプリ起動広告は4時間で期限が切れる
    private var appOpenAdLoadTime: Date?
    private var isLoadingAppOpenAd = false

    /// 全画面広告を表示中か
    ///
    /// 起動時と復帰時の呼び出しが重なると、同じ日に2回出てしまうため。
    private var isShowingAppOpenAd = false
    /// 起動時の広告が閉じられるのを待つための継続
    private var appOpenAdDismissContinuation: CheckedContinuation<Void, Never>?
    /// バックグラウンドに入ったか。復帰時の広告は、ここから戻ってきたときだけ出す
    private var didEnterBackground = false

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
    /// 起動と同時にダイアログを出すと画面の描画に重なるので、まだ答えていない初回だけ1秒遅らせる。
    private func requestTrackingThenStartSDK() {
        // 答え済みならダイアログは出ないので待たない。
        // 起動時のアプリ起動広告は読み込みを最大3秒しか待たないため、1秒でも早く始めたい
        let delay: TimeInterval = ATTrackingManager.trackingAuthorizationStatus == .notDetermined ? 1.0 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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
        isAdsRemoved = await PurchaseManager.shared.hasAdFree()
        isInterstitialFree = !(await shouldShowAds())
    }

    /// 広告を出す状態のときだけ読み込む
    ///
    /// 表示側だけで抑止すると、広告を出さないのに広告リクエストとIDFAの送信は
    /// 続いてしまう。購入した人に対して筋が通らないのでリクエスト自体を送らない。
    @MainActor
    private func loadAdsIfAllowed() {
        // バナーは AdBannerView が置かれた画面ごとに読み込む。
        // 全画面広告はお試し期間が明けてから。
        guard !isInterstitialFree else { return }
        loadAppOpenAd()
    }

    /// 購入が成立したときに呼ぶ。読み込み済みの広告を捨てる。
    ///
    /// バナーは isAdsRemoved を見て各ビューが自分で消すので、ここでは触らない。
    @MainActor
    func discardLoadedAds() {
        appOpenAd = nil
        appOpenAdLoadTime = nil
        isAdsRemoved = true
        isInterstitialFree = true
    }

    // MARK: - 読み込み

    // 全画面広告は「アプリ起動」広告を使う。
    // インタースティシャル広告は画面の切れ目に出すもので、起動時や復帰時に出すのは
    // AdMob のポリシーで禁止されている。起動時・復帰時に出すための形式がアプリ起動広告。
    //
    // 判定まわりの名前（isInterstitialFree / shouldShowInterstitial など）は
    // 「全画面広告」の意味で残している。保存キーの値を変えると、既存ユーザーの
    // 「今日は表示済み」の記録が引き継がれないため。

    /// アプリ起動広告の有効期限（Google の指定で4時間）
    private static let appOpenAdLifetime: TimeInterval = 4 * 3600

    /// 読み込み済みで、期限が切れていない広告があるか
    private var isAppOpenAdAvailable: Bool {
        guard appOpenAd != nil, let loadTime = appOpenAdLoadTime else { return false }
        return Date().timeIntervalSince(loadTime) < Self.appOpenAdLifetime
    }

    @MainActor
    private func loadAppOpenAd() {
        guard !isLoadingAppOpenAd, !isAppOpenAdAvailable else { return }
        isLoadingAppOpenAd = true
        AppOpenAd.load(with: appOpenAdUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingAppOpenAd = false
                guard error == nil else { return }
                self.appOpenAd = ad
                self.appOpenAd?.fullScreenContentDelegate = self
                self.appOpenAdLoadTime = Date()
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
    
    // MARK: - App Open Ad

    /// いちばん手前に出ている画面（シートが開いていればシート）
    ///
    /// connectedScenes.first は並び順が保証されず、UIWindowScene とも限らない。
    /// バナー側（BannerRepresentable）と同じ取り方に揃える。
    @MainActor
    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// 全画面広告を表示する
    ///
    /// 出す条件を満たさないときは何もしない。
    /// - Returns: 実際に表示したか
    @MainActor
    @discardableResult
    private func presentAppOpenAd() async -> Bool {
        guard await shouldShowAds() else { return false }
        // 購入状態の確認で待っている間に、別の経路で出ていることがあるので、そのあとで見る
        guard !isShowingAppOpenAd else { return false }

        // 期限切れの広告は出さずに読み直す
        guard isAppOpenAdAvailable, let ad = appOpenAd,
              let root = Self.topViewController() else {
            if appOpenAd != nil, !isAppOpenAdAvailable {
                appOpenAd = nil
                appOpenAdLoadTime = nil
                loadAppOpenAd()
            }
            return false
        }

        isShowingAppOpenAd = true
        ad.present(from: root)
        return true
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

    /// 起動時の全画面広告の上限待ち時間
    ///
    /// これを過ぎたら広告は出さずに本編へ進む。待たせすぎると起動が遅いアプリになる。
    static let launchAdWaitLimit: TimeInterval = 3

    /// 起動時に読み込み画面を出して広告を待つか
    ///
    /// 起動の時点ですぐ分かる条件（お試し期間・今日表示済み・Debug）だけを見る。
    /// 購入状態は確認が非同期なので showAppOpenAdOnLaunch の中で見る。
    @MainActor
    var shouldWaitForLaunchAd: Bool {
        #if DEBUG
        // Debug では広告を読まないので待つ意味がない
        if PurchaseManager.unlockAllInDebug { return false }
        #endif
        return AppLaunchManager.shared.shouldShowInterstitial
    }

    /// 起動時に読み込み画面の裏で呼ぶ。広告が閉じられるまで戻らない（1日1回まで）
    ///
    /// Google のガイドでは、起動時のアプリ起動広告は読み込み画面の間に出し、
    /// 本編の画面に入ったあとには出さない。そのため呼び出し側は、
    /// この関数が戻るまで読み込み画面を出したままにする。
    /// 決められた時間内に広告が読み込めなければ、出さずに戻る。
    /// 読み込めなかった広告はそのまま残し、復帰時に使う。
    ///
    /// 再生の前後では出さない。
    /// Waveを続けて回したいときに毎回割り込まれると使い物にならないため。
    @MainActor
    func showAppOpenAdOnLaunch() async {
        guard AppLaunchManager.shared.shouldShowInterstitial,
              await shouldShowAds() else { return }

        let deadline = Date().addingTimeInterval(Self.launchAdWaitLimit)
        while !isAppOpenAdAvailable && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        // 待っている間に別の経路で出ていたら出さない
        guard AppLaunchManager.shared.shouldShowInterstitial else { return }

        // 記録は実際に表示できたときだけ行う。
        // 出せなかった回まで記録すると、その日の1回を出さないまま使い切ってしまう。
        guard await presentAppOpenAd() else { return }
        AppLaunchManager.shared.recordInterstitialShown()

        await withCheckedContinuation { continuation in
            // 待っている間に閉じられていれば、すぐに戻る
            if isShowingAppOpenAd {
                appOpenAdDismissContinuation = continuation
            } else {
                continuation.resume()
            }
        }
    }

    /// scenePhase が変わったときに呼ぶ。バックグラウンドから戻ってきたときだけ広告を出す
    ///
    /// 起動直後の .active では出さない。起動時の広告は showAppOpenAdOnLaunch が受け持つ。
    @MainActor
    func handleScenePhase(_ phase: ScenePhase) async {
        switch phase {
        case .background:
            didEnterBackground = true
        case .active where didEnterBackground:
            didEnterBackground = false
            await onAppResume()
        default:
            break
        }
    }

    /// 復帰時に全画面広告を出す（1日1回まで）
    ///
    /// 起動時と回数を共有する。何度開いても広告は1日1回で済む。
    /// 読み込み済みでなければ出さない。
    ///
    /// 記録は実際に表示できたときだけ行う。
    /// 出せなかった回まで記録すると、その日の1回を出さないまま使い切ってしまう。
    @MainActor
    func onAppResume() async {
        guard AppLaunchManager.shared.shouldShowInterstitial else { return }
        if await presentAppOpenAd() {
            AppLaunchManager.shared.recordInterstitialShown()
        }
    }

}
// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.finishAppOpenAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.finishAppOpenAd()
        }
    }

    /// 広告が閉じられた（または出せなかった）あとの片付け
    @MainActor
    private func finishAppOpenAd() {
        isShowingAppOpenAd = false
        appOpenAd = nil
        appOpenAdLoadTime = nil
        // 起動時の読み込み画面を閉じてよいと知らせる
        appOpenAdDismissContinuation?.resume()
        appOpenAdDismissContinuation = nil
        // 次の全画面広告を用意しておく
        guard !isInterstitialFree else { return }
        loadAppOpenAd()
    }
}

// MARK: - バナーを置くビュー

/// 画面下部などに差し込むバナー。
///
/// 購入済み・お試し期間中は何も描かないので、置いておくだけでよい。
///
/// バナーは画面ごとに作る。
/// 以前は AdManager が1つだけ持って全画面で使い回していたが、
/// UIView は親を1つしか持てないため、タブを移ると前の画面から剥がれていた。
/// さらに読み込み完了を知る手段が無く、`.task` が走る時点では
/// まだ読み込めていないので、結局どの画面にも出ていなかった。
struct AdBannerView: View {
    @StateObject private var adManager = AdManager.shared
    @State private var isLoaded = false

    var body: some View {
        Group {
            // 起動回数は見ない。バナーは最初から出す方針のため。
            if !adManager.isAdsRemoved {
                BannerRepresentable(adUnitID: adManager.bannerAdUnitID) {
                    isLoaded = true
                }
                .frame(height: BannerRepresentable.adSize.size.height)
                // 読み込めるまでは場所だけ取って中身を見せない。
                // 空の枠が一瞬見えるより、そのまま出てくる方が自然。
                .opacity(isLoaded ? 1 : 0)
            }
        }
        .task {
            await adManager.refreshAdFreeState()
        }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let onLoaded: () -> Void

    /// 画面幅に合わせたバナーの大きさ
    ///
    /// 固定の 320x50 だと画面幅に足りず、左右に下地の黒が出ていた。
    /// アダプティブバナーなら端末の幅いっぱいに広がる。
    static var adSize: AdSize {
        currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.backgroundColor = .clear
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoaded: onLoaded)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let onLoaded: () -> Void

        init(onLoaded: @escaping () -> Void) {
            self.onLoaded = onLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onLoaded()
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            kDebugErrorPrint(error, message: "バナーの読み込みに失敗")
        }
    }
}
